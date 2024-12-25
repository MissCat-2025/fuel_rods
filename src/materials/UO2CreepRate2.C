#include "UO2CreepRate2.h"

registerADMooseObject("FuelRodsApp", UO2CreepRate2);

InputParameters
UO2CreepRate2::validParams()
{
  InputParameters params = ADMaterial::validParams();
  params.addRequiredCoupledVar("temperature", "Temperature in Kelvin");
  params.addRequiredCoupledVar("oxygen_ratio", "O/M ratio");
  params.addRequiredParam<Real>("fission_rate", "Fission rate density (fissions/m^2-s)");
  params.addParam<Real>("theoretical_density", 95.0, "Percent of theoretical density");
  params.addParam<Real>("grain_size", 10.0, "Grain size in micrometers");
  params.addParam<Real>("time_since_max_stress", 1.0e7, "Time since maximum stress (s)");
  params.addParam<Real>("gas_constant", 8.314, "Universal gas constant (J/mol-K)");
  return params;
}

UO2CreepRate2::UO2CreepRate2(const InputParameters & parameters)
  : ADMaterial(parameters),
    _temperature(adCoupledValue("temperature")),
    _oxygen_ratio(adCoupledValue("oxygen_ratio")),
    _fission_rate(getParam<Real>("fission_rate")),
    _theoretical_density(getParam<Real>("theoretical_density")),
    _grain_size(getParam<Real>("grain_size")),
    _time_since_max_stress(getParam<Real>("time_since_max_stress")),
    _gas_constant(getParam<Real>("gas_constant")),
    _stress_old(getMaterialPropertyOld<RankTwoTensor>("stress")),
    _stress_deviator(declareADProperty<RankTwoTensor>("stress_deviator")),
    _effective_stress(declareADProperty<Real>("effective_stress")),
    _Q1(declareADProperty<Real>("Q1")),
    _Q2(declareADProperty<Real>("Q2")),
    _Q3(2.6167e3),
    _creep_rate(declareADProperty<RankTwoTensor>("creep_rate"))
{
}

void
UO2CreepRate2::computeQpProperties()
{
  // 计算应力偏差张量
  _stress_deviator[_qp] = _stress_old[_qp].deviatoric();
  
  // 计算von Mises有效应力
  _effective_stress[_qp] = std::sqrt(1.5 * _stress_deviator[_qp].doubleContraction(_stress_deviator[_qp]));

  // 数值保护
  const Real min_stress = 1e-8;
  const Real min_x = 1e-8;
  const Real cal_to_J = 4.184;
//   ADReal effective_stress = std::max(_effective_stress[_qp], min_stress);
  ADReal x = std::max(_oxygen_ratio[_qp], min_x);
  _Q1[_qp] = (17884.8 / (std::exp(-20.0/std::log10(x-2.0) - 8.0) + 1.0) + 72124.23) * cal_to_J;
  _Q2[_qp] = (19872.0 / (std::exp(-20.0/std::log10(x-2.0) - 8.0) + 1.0) + 111543.5) * cal_to_J;

  // FCREEP模型常数
  const double A1 = 0.3919;
  const double A2 = 1.31e-19;
  const double A3 = -87.7;
  const double A4 = 2.0391e-25;
  const double A6 = -90.5;
  const double A7 = 3.72264e-35;
  const double A8 = 0.0;
  
  // 计算蠕变率
  ADReal T = _temperature[_qp];
  ADReal RT = _gas_constant * T;
  
// 各分量蠕变率
// 计算转变应力
//当施加应力(a)小于转变应力(art)时，在方程(2-63)或(2-64)的第一项中使用施加应力。对于大于 at 的应力，两个方程的第一项使用过渡应力，第二项使用外部应力。
  const Real transition_stress=1.6547e7 / std::pow(_grain_size, 0.5714);

  ADReal creep_th1;
  ADReal creep_th2;

  if (_effective_stress[_qp] < transition_stress)
  {
    creep_th1 = ((A1 + A2*_fission_rate) * _effective_stress[_qp] * std::exp(-_Q1[_qp]/RT)) / 
                        ((_theoretical_density - 87.7) * _grain_size * _grain_size);
                        
    creep_th2 = ((A4 + A8*_fission_rate) * std::pow(_effective_stress[_qp], 4.5) * std::exp(-_Q2[_qp]/RT)) / 
                        (_theoretical_density - 90.5);
  }
  else
  {
    creep_th1 = ((A1 + A2*_fission_rate) * transition_stress * std::exp(-_Q1[_qp]/RT)) / 
                        ((_theoretical_density - 87.7) * _grain_size * _grain_size);
                        
    creep_th2 = ((A4 + A8*_fission_rate) * std::pow(_effective_stress[_qp], 4.5) * std::exp(-_Q2[_qp]/RT)) / 
                        (_theoretical_density - 90.5);
  }
                    
  ADReal creep_ir = A7 * _effective_stress[_qp] * _fission_rate * std::exp(-_Q3/RT);
  
  // 计算总标量蠕变率
  ADReal scalar_rate = creep_th1 + creep_th2 + creep_ir;
  
  //当燃料首次经历应力时（通常是在初始辐照期间），或者当施加比任何其他时间步长更高的应力时，应变率与时间相关，并使用以下方程计算

  ADReal scalar_rate2 = scalar_rate * (2.5 * std::exp(-1.4e-6*_time_since_max_stress) + 1.0);

  // 转换为张量形式
// 这个转换是基于 J2 塑性理论。让我解释一下这个公式：
// 1. 首先，我们有标量蠕变率 scalar_rate，它代表等效蠕变率 (equivalent creep rate)
// 我们需要将这个标量转换为张量形式，因为实际的蠕变是一个张量量
// 根据 J2 塑性理论，蠕变应变率张量与应力偏差张量成正比：
// ε̇ᶜʳᵉᵉᵖ = (3/2) * (ε̇ᵉᑫ/σᵉᶠᶠ) * s
// 其中：
// ε̇ᶜʳᵉᵉᵖ 是蠕变率张量
// ε̇ᵉᑫ 是等效蠕变率（我们的scalar_rate）
// σᵉᶠᶠ 是有效应力
// s 是应力偏差张量
  _creep_rate[_qp] = 1.5 * (scalar_rate2 / _effective_stress[_qp]) * _stress_deviator[_qp];
  // _creep_rate[_qp] = scalar_rate2;
} 
