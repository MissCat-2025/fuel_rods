//* This file is part of the RACCOON application
//* being developed at Dolbow lab at Duke University
//* http://dolbow.pratt.duke.edu

#include "SmallDeformationUO2CreepModel.h"

registerMooseObject("FuelRodsApp", SmallDeformationUO2CreepModel);

InputParameters
SmallDeformationUO2CreepModel::validParams()
{
  InputParameters params = SmallDeformationPlasticityModel::validParams();
  params.addClassDescription("Small deformation UO2 creep model with thermal and irradiation "
                             "creep mechanisms. Uses radial return algorithm. "
                             "Note: This model requires a hardening model to compute "
                             "plastic energy density for phase-field fracture.");
  
  params.addRequiredCoupledVar("temperature", "Temperature in Kelvin");
  params.addRequiredCoupledVar("oxygen_ratio", "Oxygen hyper-stoichiometry (x in UO_{2+x})");
  params.addParam<Real>("fission_rate", 1.2e19, "Fission rate density (fissions/m^3-s)");
  params.addParam<Real>("theoretical_density", 95.0, "Percent of theoretical density");
  params.addParam<Real>("grain_size", 10.0, "Grain size in micrometers");
  params.addParam<Real>("gas_constant", 8.314, "Universal gas constant (J/mol-K)");
  params.addParam<Real>("Q3", 21759.0, "Activation energy for irradiation creep (J/mol)");
  params.addParam<bool>("consider_transient_creep", false, "Whether to consider transient creep");
  
  return params;
}

SmallDeformationUO2CreepModel::SmallDeformationUO2CreepModel(const InputParameters & parameters)
  : SmallDeformationPlasticityModel(parameters),
    _temperature(adCoupledValue("temperature")),
    _oxygen_ratio(adCoupledValue("oxygen_ratio")),
    _fission_rate(getParam<Real>("fission_rate")),
    _theoretical_density(getParam<Real>("theoretical_density")),
    _grain_size(getParam<Real>("grain_size")),
    _gas_constant(getParam<Real>("gas_constant")),
    _Q3(getParam<Real>("Q3")),
    _consider_transient_creep(getParam<bool>("consider_transient_creep")),
    _max_stress_time(declareProperty<Real>("max_stress_time")),
    _max_stress_time_old(getMaterialPropertyOld<Real>("max_stress_time")),
    _max_stress(declareADProperty<Real>("max_stress")),
    _max_stress_old(getMaterialPropertyOld<Real>("max_stress")),
    _dt(_fe_problem.dt())
{
}

void
SmallDeformationUO2CreepModel::updateState(ADRankTwoTensor & stress, ADRankTwoTensor & elastic_strain)
{
  // 首先假设没有蠕变增量
  ADReal delta_ep = 0;
  elastic_strain -= _plastic_strain_old[_qp]; // 注意：这里仍用plastic_strain代表蠕变应变
  stress = _elasticity_model->computeStress(elastic_strain);

  // 计算流动方向，遵循Prandtl-Reuss流动规则
  ADRankTwoTensor stress_dev = stress.deviatoric();
  ADReal stress_dev_norm = stress_dev.doubleContraction(stress_dev);
  if (MooseUtils::absoluteFuzzyEqual(stress_dev_norm, 0))
    stress_dev_norm.value() = libMesh::TOLERANCE * libMesh::TOLERANCE;
  stress_dev_norm = std::sqrt(1.5 * stress_dev_norm);
  _Np[_qp] = 1.5 * stress_dev / stress_dev_norm;

  // 计算有效应力并更新最大应力历史（用于瞬态蠕变）
  if (_consider_transient_creep)
  {
    if (stress_dev_norm > _max_stress_old[_qp])
    {
      _max_stress[_qp] = raw_value(stress_dev_norm);
      _max_stress_time[_qp] = 0.0; // 重置时间
    }
    else
    {
      _max_stress[_qp] = _max_stress_old[_qp];
      _max_stress_time[_qp] = _max_stress_time_old[_qp] + _dt;
    }
  }

  // 径向返回
  // 对于蠕变，任何应力下都有流动，所以不需要check phi > 0
  
  // 先计算理论蠕变率，用于比较
  const ADReal theoretical_creep_rate = computeCreepRate(stress_dev_norm);
  const ADReal theoretical_creep_increment = theoretical_creep_rate * _dt;
  
  returnMappingSolve(stress_dev_norm, delta_ep, _console);
  
  // 在预处理期间，如果径向返回的结果太小但理论值显著，使用理论值的一部分
  if (std::abs(raw_value(delta_ep)) < 1e-10 && std::abs(raw_value(theoretical_creep_increment)) > 1e-10)
  {
    Real safety_factor = 1.0;
    delta_ep = safety_factor * theoretical_creep_increment;
  }
  
  _ep[_qp] = _ep_old[_qp] + delta_ep;
  _plastic_strain[_qp] = _plastic_strain_old[_qp] + delta_ep * _Np[_qp];

  // 更新应力
  elastic_strain -= delta_ep * _Np[_qp];
  stress = _elasticity_model->computeStress(elastic_strain);
  
  // 确保硬化模型计算塑性能量（用于相场断裂）
  ADReal plastic_energy = _hardening_model->plasticEnergy(_ep[_qp]);
}

ADReal
SmallDeformationUO2CreepModel::computeTransitionStress() const
{
  // 转变应力计算
  return 1.6547e7 / std::pow(_grain_size, 0.5714);
}

ADReal
SmallDeformationUO2CreepModel::computeCreepRate(const ADReal & effective_stress)
{
  // 预计算常用值
  const ADReal T = _temperature[_qp];
  const ADReal x = _oxygen_ratio[_qp];
  const ADReal RT = _gas_constant * T;
  const ADReal inv_RT = 1.0 / RT;
  
  // 计算转变应力
  const ADReal sigma_trans = computeTransitionStress();
  
  // 计算活化能
  ADReal log_x = std::log(x);
  ADReal exp_common = std::exp(-20.0 / log_x - 8.0);
  ADReal denom = 1.0 / (exp_common + 1.0);
  ADReal Q1 = 74829.0 * denom + 301762.0;
  ADReal Q2 = 83143.0 * denom + 469191.0;
  
  // 预计算密度和晶粒尺寸相关项
  const Real density_term1 = 1.0 / ((_theoretical_density - 87.7) * _grain_size * _grain_size);
  const Real density_term2 = 1.0 / (_theoretical_density - 90.5);
  
  // 预计算裂变率项
  const Real fission_term = 0.3919 + 1.31e-19 * _fission_rate;
  
  // 预计算指数项
  const ADReal exp_Q1 = std::exp(-Q1 * inv_RT);
  const ADReal exp_Q2 = std::exp(-Q2 * inv_RT);
  const ADReal exp_Q3 = std::exp(-_Q3 * inv_RT);
  
  // 计算各分量蠕变率
  // 低应力扩散蠕变
  ADReal creep_th1;
  if (effective_stress < sigma_trans)
    creep_th1 = fission_term * density_term1 * effective_stress * exp_Q1;
  else
    creep_th1 = fission_term * density_term1 * sigma_trans * exp_Q1;
  
  // 高应力位错蠕变
  const ADReal stress_power = std::pow(effective_stress, 4.5);
  const ADReal creep_th2 = 2.0391e-25 * density_term2 * stress_power * exp_Q2;
  
  // 辐照蠕变
  const ADReal creep_ir = 3.7226e-35 * _fission_rate * effective_stress * exp_Q3;
  
  // 计算总标量蠕变率
  ADReal scalar_rate = creep_th1 + creep_th2 + creep_ir;
  
  // 考虑瞬态蠕变
  if (_consider_transient_creep)
  {
    const Real transient_factor = 
        2.5 * std::exp(-1.40e-6 * _max_stress_time[_qp]) + 1.0;
    scalar_rate *= transient_factor;
  }
  
  return scalar_rate;
}

Real
SmallDeformationUO2CreepModel::computeReferenceResidual(const ADReal & effective_trial_stress,
                                                        const ADReal & delta_ep)
{
  return raw_value(
      effective_trial_stress -
      _elasticity_model->computeStress(delta_ep * _Np[_qp]).doubleContraction(_Np[_qp]));
}

ADReal
SmallDeformationUO2CreepModel::computeResidual(const ADReal & effective_trial_stress,
                                               const ADReal & delta_ep)
{
  // 试验应力减去弹性响应
  const ADReal effective_stress = effective_trial_stress - 
                                 _elasticity_model->computeStress(delta_ep * _Np[_qp])
                                 .doubleContraction(_Np[_qp]);
  
  // 计算蠕变率
  const ADReal creep_rate = computeCreepRate(effective_stress);
  
  // 放大系数，让残差方程计算中的值不会太小
  const Real scale_factor = 1e5;
  // 残差方程：creep_rate * dt - delta_ep = 0
  const ADReal residual = (creep_rate * _dt - delta_ep) * scale_factor;
  
  return residual;
}

ADReal
SmallDeformationUO2CreepModel::computeDerivative(const ADReal & effective_trial_stress,
                                                 const ADReal & delta_ep)
{
  // 计算有效应力
  const ADReal effective_stress = effective_trial_stress - 
                                 _elasticity_model->computeStress(delta_ep * _Np[_qp])
                                 .doubleContraction(_Np[_qp]);
  
  // 计算应力对塑性增量的导数
  const ADReal dstress_ddelta_ep = 
      -_elasticity_model->computeStress(_Np[_qp]).doubleContraction(_Np[_qp]);
  
  // 数值方法计算蠕变率对应力的导数
  const Real h = std::max(1e-10, 1e-6 * std::abs(raw_value(effective_stress)));
  const ADReal creep_rate = computeCreepRate(effective_stress);
  const ADReal creep_rate_plus = computeCreepRate(effective_stress + h);
  const ADReal dcreep_rate_dstress = (creep_rate_plus - creep_rate) / h;
  
  // 与residual保持相同的缩放因子
  const Real scale_factor = 1e5;
  
  // 链式法则
  return (dcreep_rate_dstress * dstress_ddelta_ep * _dt - 1.0) * scale_factor;
}
