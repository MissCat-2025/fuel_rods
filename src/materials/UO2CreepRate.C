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
    _effective_stress(declareADProperty<Real>("effective_stress")),
    _Q1(declareADProperty<Real>("Q1")),
    _Q2(declareADProperty<Real>("Q2")),
    _Q3(21759.0),
    _creep_rate(declareADProperty<RankTwoTensor>("creep_rate"))
{
}

void
UO2CreepRate::computeQpProperties()
{
  // 计算应力偏差张量
  _stress_deviator[_qp] = _stress_old[_qp].deviatoric();
  
  // 计算von Mises有效应力
  _effective_stress[_qp] = std::sqrt(1.5 * _stress_deviator[_qp].doubleContraction(_stress_deviator[_qp]));

  // 保护浓度和温度，确保都为正且不太小
  ADReal x = std::max(std::abs(_oxygen_ratio[_qp]), 1e-6);
             
  ADReal RT = _gas_constant * _temperature[_qp];

  // 计算激活能时添加保护
  ADReal exp_term = std::exp(-20.0 / std::log10(x) - 8.0);
  _Q1[_qp] = 74829.0 / (exp_term + 1.0) + 301762.0;
  _Q2[_qp] = 83143.0 / (exp_term + 1.0) + 469191.0;

  // 各分量蠕变率计算添加保护
  ADReal density_factor1 = std::max(_theoretical_density - 87.7, 0.1);
  ADReal density_factor2 = std::max(_theoretical_density - 90.5, 0.1);
  ADReal grain_size_factor = std::max(_grain_size * _grain_size, 0.1);

  // 计算各个蠕变分量
  ADReal creep_th1 = (0.3919 + 1.31e-19 * _fission_rate) / 
                     (density_factor1 * grain_size_factor) * 
                     _effective_stress[_qp] * std::exp(-_Q1[_qp] / RT);
                     
  ADReal creep_th2 = 2.0391e-25 / density_factor2 * 
                     std::pow(_effective_stress[_qp], 4.5) * 
                     std::exp(-_Q2[_qp] / RT);
                     
  ADReal creep_ir = 3.7226e-35 * _fission_rate * 
                    _effective_stress[_qp] * std::exp(-_Q3 / RT);

  // 总标量蠕变率
  ADReal scalar_rate = creep_th1 + creep_th2 + creep_ir;
  
  // 转换为张量形式
  _creep_rate[_qp] = 1.5 * (scalar_rate / _effective_stress[_qp]) * _stress_deviator[_qp];
}