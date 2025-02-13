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
    _creep_rate(declareADProperty<RankTwoTensor>("creep_rate"))
{
}

void
UO2CreepRate::computeQpProperties()
{
  // 计算应力偏差张量 - 不需要AD，因为是从旧应力计算
  _stress_deviator[_qp] = _stress_old[_qp].deviatoric();

  // 计算激活能 - 需要AD因为依赖于oxygen_ratio
  _Q1[_qp] = 74829.0 / (std::exp(-20.0 / std::log10(_oxygen_ratio[_qp]) - 8.0) + 1.0) + 301762.0;
  _Q2[_qp] = 83143.0 / (std::exp(-20.0 / std::log10(_oxygen_ratio[_qp]) - 8.0) + 1.0) + 469191.0;
  
  // 计算RT - 需要AD因为温度是AD
  const ADReal RT = _gas_constant * _temperature[_qp];
  
  // 预计算一些常量项以提高效率
  const Real density_term1 = 1.0 / ((_theoretical_density - 87.7) * _grain_size * _grain_size);
  const Real density_term2 = 1.0 / (_theoretical_density - 90.5);
  const Real fission_term = 0.3919 + 1.31e-19 * _fission_rate;
  
  // 各分量蠕变率
  const ADReal creep_th1 = fission_term * density_term1 * 
                          _vonMisesStress[_qp] * std::exp(-_Q1[_qp] / RT);
                     
  const ADReal creep_th2 = 2.0391e-25 * density_term2 * 
                          std::pow(_vonMisesStress[_qp], 4.5) * 
                          std::exp(-_Q2[_qp] / RT);
                     
  const ADReal creep_ir = 3.7226e-35 * _fission_rate * 
                         _vonMisesStress[_qp] * 
                         std::exp(-_Q3 / RT);
  
  // 总标量蠕变率
  const ADReal scalar_rate = creep_th1 + creep_th2 + creep_ir;
  
  // 转换为张量形式
  if (_vonMisesStress[_qp] > 1e-10)
    _creep_rate[_qp] = 1.5 * (scalar_rate / _vonMisesStress[_qp]) * _stress_deviator[_qp];
  else
    _creep_rate[_qp].zero();

  // // 调试输出
  // if (_qp == 0 && _current_elem->id() % 1000 == 0)
  // {
  //   Moose::out << "Element " << _current_elem->id() << ":\n"
  //              << "vonMises stress: " << MetaPhysicL::raw_value(_vonMisesStress[_qp]) << "\n"
  //              << "scalar_rate: " << MetaPhysicL::raw_value(scalar_rate) << "\n"
  //              << "creep_rate: " << MetaPhysicL::raw_value(_creep_rate[_qp]) << std::endl;
  // }
}
