//* This file is part of the RACCOON application
//* being developed at Dolbow lab at Duke University
//* http://dolbow.pratt.duke.edu

#include "DegradablePowerLawCreepStressUpdate.h"

registerMooseObject("FuelRodsApp", DegradablePowerLawCreepStressUpdate);

InputParameters
DegradablePowerLawCreepStressUpdate::validParams()
{
  InputParameters params = ADPowerLawCreepStressUpdate::validParams();
  params.addClassDescription(
      "蠕变模型，考虑相场断裂中的退化函数影响。");

  params.addParam<MaterialPropertyName>("degradation_function", "g", 
      "退化函数材料属性名");
  params.addParam<bool>("use_stress_degradation", true, 
      "是否对有效应力应用退化");

  return params;
}

DegradablePowerLawCreepStressUpdate::DegradablePowerLawCreepStressUpdate(
    const InputParameters & parameters)
  : ADPowerLawCreepStressUpdate(parameters),
    _g(getADMaterialProperty<Real>("degradation_function")),
    _use_stress_degradation(getParam<bool>("use_stress_degradation"))
{
}

ADReal
DegradablePowerLawCreepStressUpdate::computeResidual(const ADReal & effective_trial_stress,
                                               const ADReal & scalar)
{
  // 计算有效应力增量
  ADReal stress_delta;
  if (_use_stress_degradation)
    // 应用退化到应力
    stress_delta = _g[_qp] * (effective_trial_stress - _three_shear_modulus * scalar);
  else
    // 不对应力退化
    stress_delta = effective_trial_stress - _three_shear_modulus * scalar;
  
  // 计算蠕变速率，总是应用退化函数
  const ADReal creep_rate =
      _coefficient * std::pow(stress_delta, _n_exponent) * 
      _exponential * _exp_time * _g[_qp];
  
  // 残差计算
  return creep_rate * _dt - scalar;
}

ADReal
DegradablePowerLawCreepStressUpdate::computeDerivative(const ADReal & effective_trial_stress,
                                                 const ADReal & scalar)
{
  // 计算有效应力增量
  ADReal stress_delta;
  if (_use_stress_degradation)
    stress_delta = _g[_qp] * (effective_trial_stress - _three_shear_modulus * scalar);
  else
    stress_delta = effective_trial_stress - _three_shear_modulus * scalar;
  
  // 计算导数
  const ADReal creep_rate_derivative =
      -_coefficient * _three_shear_modulus * _n_exponent *
      std::pow(stress_delta, _n_exponent - 1.0) * 
      _exponential * _exp_time * _g[_qp] * 
      (_use_stress_degradation ? _g[_qp] : 1.0);
  
  return creep_rate_derivative * _dt - 1.0;
}

Real
DegradablePowerLawCreepStressUpdate::computeStrainEnergyRateDensity(
    const ADMaterialProperty<RankTwoTensor> & stress,
    const ADMaterialProperty<RankTwoTensor> & strain_rate)
{
  if (_n_exponent <= 1)
    return 0.0;

  Real creep_factor = _n_exponent / (_n_exponent + 1);
  
  // 应变能率也考虑退化影响
  return MetaPhysicL::raw_value(creep_factor * stress[_qp].doubleContraction(strain_rate[_qp]));
}