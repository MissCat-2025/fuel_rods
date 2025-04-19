// src/materials/UO2CreepRate.C
#include "UO2CreepRate.h"

registerADMooseObject("FuelRodsApp", UO2CreepRate);

InputParameters
UO2CreepRate::validParams()
{
  InputParameters params = ADMaterial::validParams();
  params.addRequiredCoupledVar("temperature", "Temperature in Kelvin");
  params.addRequiredCoupledVar("oxygen_ratio", "Oxygen hyper-stoichiometry");
  params.addRequiredParam<Real>("fission_rate", "Fission rate density (fissions/m^3-s)");
  params.addParam<Real>("theoretical_density", 95.0, "Percent of theoretical density");
  params.addParam<Real>("grain_size", 10.0, "Grain size in micrometers");
  params.addParam<Real>("gas_constant", 8.314, "Universal gas constant (J/mol-K)");
  params.addRequiredCoupledVar("vonMisesStress", "The von Mises stress auxiliary variable");
  params.addParam<bool>("consider_transient_creep", false, "Whether to consider transient creep");
  // 是否考虑MATPRO Halden模型，第三项去除温度依赖：https://mooseframework.inl.gov/bison/source/materials/solid_mechanics/UO2CreepUpdate.html
  params.addParam<bool>("USE_MATPRO_Halden_model", true, "Whether to consider MATPRO Halden model,third term in Eq. (1) removing temperature dependency");
  params.addParam<bool>("USE_transition_stress", false, "Whether to consider transition stress");
  return params;
}

UO2CreepRate::UO2CreepRate(const InputParameters & parameters)
  : ADMaterial(parameters),
    _temperature(adCoupledValue("temperature")),
    _oxygen_ratio(adCoupledValue("oxygen_ratio")),
    _fission_rate(getParam<Real>("fission_rate")),
    _theoretical_density(getParam<Real>("theoretical_density")),
    _grain_size(getParam<Real>("grain_size")),
    _gas_constant(getParam<Real>("gas_constant")),
    _stress_old(getMaterialPropertyOld<RankTwoTensor>("stress")),
    _stress_deviator(declareADProperty<RankTwoTensor>("stress_deviator")),
    _vonMisesStress(adCoupledValue("vonMisesStress")),
    _Q1(declareADProperty<Real>("Q1")),
    _Q2(declareADProperty<Real>("Q2")),
    _Q3(21759.0),
    _creep_rate(declareADProperty<RankTwoTensor>("creep_rate")),
    _consider_transient_creep(getParam<bool>("consider_transient_creep")),
    _max_stress_time(declareProperty<Real>("max_stress_time")),
    _max_stress_time_old(getMaterialPropertyOld<Real>("max_stress_time")),
    _max_stress(declareProperty<Real>("max_stress")),
    _max_stress_old(getMaterialPropertyOld<Real>("max_stress")),
    _USE_MATPRO_Halden_model(getParam<bool>("USE_MATPRO_Halden_model")),
    _USE_transition_stress(getParam<bool>("USE_transition_stress"))
{
}

void
UO2CreepRate::initQpStatefulProperties()
{
  // 初始化最大应力和时间
  _max_stress[_qp] = 0.0;
  _max_stress_time[_qp] = 0.0;
}

void
UO2CreepRate::computeQpProperties()
{
  // 预计算常用值
  const ADReal T = _temperature[_qp];
  const ADReal x = _oxygen_ratio[_qp];
  const ADReal RT = _gas_constant * T;
  const ADReal inv_RT = 1.0 / RT;
  
  // 计算偏应力张量
  _stress_deviator[_qp] = _stress_old[_qp].deviatoric();
  
  // 计算有效应力
  const ADReal stress = _vonMisesStress[_qp];
  
  // 更新最大应力历史和时间（用于瞬态蠕变）
  if (_consider_transient_creep)
  {
    const Real dt = _fe_problem.dt(); // 获取时间步长
    
    if (raw_value(stress) > _max_stress_old[_qp])
    {
      _max_stress[_qp] = raw_value(stress);
      _max_stress_time[_qp] = 0.0; // 重置时间
    }
    else
    {
      _max_stress[_qp] = _max_stress_old[_qp];
      _max_stress_time[_qp] = _max_stress_time_old[_qp] + dt;
    }
  }
  
  // 预计算氧化学计量比相关项
  const ADReal log_x = std::log10(x); // 使用log10，与BISON文档一致
  const ADReal exp_common = std::exp(-20.0 / log_x - 8.0);
  const ADReal denom = 1.0 / (exp_common + 1.0);
  
  // 计算激活能
  _Q1[_qp] = 74829.0 * denom + 301762.0;
  _Q2[_qp] = 83143.0 * denom + 469191.0;
  
  // 预计算密度和晶粒尺寸相关项
  const Real density_term1 = 1.0 / ((_theoretical_density - 87.7) * _grain_size * _grain_size);
  const Real density_term2 = 1.0 / (_theoretical_density - 90.5);
  
  // 预计算裂变率项
  const Real fission_term = 0.3919 + 1.31e-19 * _fission_rate;
  
  // 预计算指数项
  const ADReal exp_Q1 = std::exp(-_Q1[_qp] * inv_RT);
  const ADReal exp_Q2 = std::exp(-_Q2[_qp] * inv_RT);
  const ADReal exp_Q3 = std::exp(-_Q3 * inv_RT);
  
  // 计算转变应力
  const ADReal sigma_trans = 1.6547e7 * std::pow(_grain_size, 0.5714);
  
  // 计算各分量蠕变率
  ADReal creep_th1 = 0.0;
  ADReal creep_th2 = 0.0;
  
  // 根据是否使用转变应力来计算热蠕变
  if (_USE_transition_stress)
  {
    // 使用转变应力 - MATPRO原始模型
    if (stress < sigma_trans)
    {
      // 低应力区域：使用线性项，忽略幂律项
      creep_th1 = fission_term * density_term1 * stress * exp_Q1;
      creep_th2 = 0.0;
    }
    else
    {
      // 高应力区域：线性项使用转变应力，幂律项使用实际应力
      creep_th1 = fission_term * density_term1 * sigma_trans * exp_Q1;
      creep_th2 = 2.0391e-25 * density_term2 * std::pow(stress, 4.5) * exp_Q2;
    }
  }
  else
  {
    // 不使用转变应力(BISON默认方式) - 同时应用两项
    creep_th1 = fission_term * density_term1 * stress * exp_Q1;
    creep_th2 = 2.0391e-25 * density_term2 * std::pow(stress, 4.5) * exp_Q2;
  }
  
  // 辐照蠕变 - 根据是否使用MATPRO-Halden模型
  ADReal creep_ir;
  if (_USE_MATPRO_Halden_model)
  {
    // 使用Halden关联式 - 不依赖温度
    creep_ir = 7.78e-37 * _fission_rate * stress;
  }
  else
  {
    // 使用原始MATPRO公式 - 含温度依赖性
    creep_ir = 3.7226e-35 * _fission_rate * stress * exp_Q3;
  }
  
  // 计算总标量蠕变率
  ADReal scalar_rate = creep_th1 + creep_th2 + creep_ir;
  
  // 应用瞬态蠕变效应
  if (_consider_transient_creep)
  {
    // 基于公式(2-65)应用瞬态蠕变系数
    const Real transient_factor = 2.5 * std::exp(-1.40e-6 * _max_stress_time[_qp]) + 1.0;
    scalar_rate *= transient_factor;
  }
  
  // 使用标量蠕变率和流动方向计算蠕变率张量
  if (stress > 1e-10)
  {
    // 计算标准化的流动方向
    ADRankTwoTensor flow_direction = 1.5 * _stress_deviator[_qp] / stress;
    
    // 使用流动方向和标量蠕变率
    _creep_rate[_qp] = scalar_rate * flow_direction;
  }
  else
    _creep_rate[_qp].zero();
}