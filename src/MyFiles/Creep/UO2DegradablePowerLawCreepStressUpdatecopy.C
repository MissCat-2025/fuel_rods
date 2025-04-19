// //* This file is part of the RACCOON application
// //* being developed at Dolbow lab at Duke University
// //* http://dolbow.pratt.duke.edu

// #include "UO2DegradablePowerLawCreepStressUpdate.h"

// registerMooseObject("FuelRodsApp", UO2DegradablePowerLawCreepStressUpdate);

// InputParameters
// UO2DegradablePowerLawCreepStressUpdate::validParams()
// {
//   InputParameters params = ADRadialReturnCreepStressUpdateBase::validParams();
//   params.addClassDescription(
//       "UO2蠕变模型，考虑裂变、温度和相场断裂退化。使用复杂的蠕变率表达式。");

//   // 物理常数
//   params.addParam<Real>("gas_constant", 8.314, "气体常数 (J/mol-K)");
  
//   // 温度相关
//   params.addRequiredCoupledVar("temperature", "温度 (K)");
//   params.addRequiredCoupledVar("oxygen_ratio", "氧化学计量比");
  
//   // 裂变与材料特性参数
//   params.addRequiredParam<Real>("fission_rate", "裂变率密度 (fissions/m^3-s)");
//   params.addParam<Real>("theoretical_density", 95.0, "理论密度百分比");
//   params.addParam<Real>("grain_size", 10.0, "晶粒尺寸 (微米)");
  
//   // 模型系数
//   params.addParam<Real>("a1", 0.3919, "系数a1");
//   params.addParam<Real>("a2", 1.31e-19, "系数a2");
//   params.addParam<Real>("a3", 87.7, "系数a3");
//   params.addParam<Real>("a6", 90.5, "系数a6");
//   params.addParam<Real>("a7", 3.7226e-35, "系数a7");
//   params.addParam<Real>("a8", 2.0391e-25, "系数a8");
  
//   // 应力相关选项
//   params.addParam<bool>("use_transition_stress", false, "是否使用应力转变点");
  
//   // 相场断裂相关参数
//   params.addParam<MaterialPropertyName>("degradation_function", "g", "退化函数材料属性名");
//   params.addParam<bool>("use_stress_degradation", true, "是否对有效应力应用退化");

//   return params;
// }

// UO2DegradablePowerLawCreepStressUpdate::UO2DegradablePowerLawCreepStressUpdate(
//     const InputParameters & parameters)
//   : ADRadialReturnCreepStressUpdateBase(parameters),
//     _gas_constant(getParam<Real>("gas_constant")),
//     _temperature(adCoupledValue("temperature")),
//     _oxygen_ratio(adCoupledValue("oxygen_ratio")),
//     _fission_rate(getParam<Real>("fission_rate")),
//     _theoretical_density(getParam<Real>("theoretical_density")),
//     _grain_size(getParam<Real>("grain_size")),
//     _Q1(0.0),  // 将在computeStressInitialize中计算
//     _Q2(0.0),  // 将在computeStressInitialize中计算
//     _Q3(21759.0),
//     _a1(getParam<Real>("a1")),
//     _a2(getParam<Real>("a2")),
//     _a3(getParam<Real>("a3")),
//     _a6(getParam<Real>("a6")),
//     _a7(getParam<Real>("a7")),
//     _a8(getParam<Real>("a8")),
//     _exp_Q1(0.0),  // 将在computeStressInitialize中计算
//     _exp_Q2(0.0),  // 将在computeStressInitialize中计算
//     _exp_Q3(0.0),  // 将在computeStressInitialize中计算
//     _use_transition_stress(getParam<bool>("use_transition_stress")),
//     _sigma_trans(0.0),  // 将在computeStressInitialize中计算
//     _creep_strain(declareADProperty<RankTwoTensor>("creep_strain")),
//     _creep_strain_old(getMaterialPropertyOld<RankTwoTensor>("creep_strain")),
//     _g(getADMaterialProperty<Real>(getParam<MaterialPropertyName>("degradation_function"))),
//     _use_stress_degradation(getParam<bool>("use_stress_degradation")),
//     _density_term1(0.0),  // 将在computeStressInitialize中计算
//     _density_term2(0.0),  // 将在computeStressInitialize中计算
//     _fission_term(0.0)    // 将在computeStressInitialize中计算
// {
// }

// void
// UO2DegradablePowerLawCreepStressUpdate::computeStressInitialize(
//     const ADReal & effective_trial_stress, const ADRankFourTensor & elasticity_tensor)
// {
//   ADRadialReturnCreepStressUpdateBase::computeStressInitialize(effective_trial_stress, elasticity_tensor);

//   // 预计算常用值
//   const ADReal T = _temperature[_qp];
//   const ADReal RT = _gas_constant * T;
//   const ADReal inv_RT = 1.0 / RT;
  
//   // 使用氧化学计量比
//   const ADReal x = _oxygen_ratio[_qp];
//   const ADReal log_x = std::log10(x);
//   const ADReal exp_common = std::exp(-20.0 / log_x - 8.0);
//   const ADReal denom = 1.0 / (exp_common + 1.0);
  
//   // 计算激活能
//   _Q1 = 74829.0 * denom + 301762.0;
//   _Q2 = 83143.0 * denom + 469191.0;
  
//   // 预计算指数项
//   _exp_Q1 = std::exp(-_Q1 * inv_RT);
//   _exp_Q2 = std::exp(-_Q2 * inv_RT);
//   _exp_Q3 = std::exp(-_Q3 * inv_RT);
  
//   // 计算转变应力
//   _sigma_trans = 1.6547e7 * std::pow(_grain_size, 0.5714);
  
//   // 预计算密度和晶粒尺寸相关项
//   _density_term1 = 1.0 / ((_theoretical_density - _a3) * _grain_size * _grain_size);
//   _density_term2 = 1.0 / (_theoretical_density - _a6);
  
//   // 预计算裂变率项
//   _fission_term = _a1 + _a2 * _fission_rate;
// }

// ADReal
// UO2DegradablePowerLawCreepStressUpdate::computeResidual(
//     const ADReal & effective_trial_stress, const ADReal & scalar)
// {
//   // 计算有效应力，考虑退化函数
//   ADReal stress;
//   if (_use_stress_degradation)
//     stress = _g[_qp] * (effective_trial_stress - _three_shear_modulus * scalar);
//   else
//     stress = effective_trial_stress - _three_shear_modulus * scalar;
  
//   // 计算各分量蠕变率
//   ADReal creep_th1 = 0.0;
//   ADReal creep_th2 = 0.0;
  
//   // 根据是否使用转变应力来计算热蠕变
//   if (_use_transition_stress)
//   {
//     // 使用转变应力
//     if (stress < _sigma_trans)
//     {
//       // 低应力区域：使用线性项，忽略幂律项
//       creep_th1 = _fission_term * _density_term1 * stress * _exp_Q1;
//       creep_th2 = 0.0;
//     }
//     else
//     {
//       // 高应力区域：线性项使用转变应力，幂律项使用实际应力
//       creep_th1 = _fission_term * _density_term1 * _sigma_trans * _exp_Q1;
//       creep_th2 = _a8 * _density_term2 * std::pow(stress, 4.5) * _exp_Q2;
//     }
//   }
//   else
//   {
//     // 不使用转变应力 - 同时应用两项
//     creep_th1 = _fission_term * _density_term1 * stress * _exp_Q1;
//     creep_th2 = _a8 * _density_term2 * std::pow(stress, 4.5) * _exp_Q2;
//   }
  
//   // 辐照蠕变
//   ADReal creep_ir = _a7 * _fission_rate * stress * _exp_Q3;
  
//   // 计算总蠕变率（考虑退化函数影响）
//   ADReal scalar_rate = (creep_th1 + creep_th2 + creep_ir) * _g[_qp];
  
//   // 计算残差
//   return scalar_rate * _dt - scalar;
// }

// ADReal
// UO2DegradablePowerLawCreepStressUpdate::computeDerivative(
//     const ADReal & effective_trial_stress, const ADReal & scalar)
// {
//   // 计算有效应力，考虑退化函数
//   ADReal stress;
//   if (_use_stress_degradation)
//     stress = _g[_qp] * (effective_trial_stress - _three_shear_modulus * scalar);
//   else
//     stress = effective_trial_stress - _three_shear_modulus * scalar;
  
//   // 计算应力对scalar的导数
//   ADReal d_stress_d_scalar;
//   if (_use_stress_degradation)
//     d_stress_d_scalar = -_g[_qp] * _three_shear_modulus;
//   else
//     d_stress_d_scalar = -_three_shear_modulus;
  
//   // 计算各项蠕变率对应力的导数
//   ADReal d_creep_th1_d_stress = 0.0;
//   ADReal d_creep_th2_d_stress = 0.0;
  
//   // 根据是否使用转变应力计算导数
//   if (_use_transition_stress)
//   {
//     if (stress < _sigma_trans)
//     {
//       // 低应力区域：只有线性项有导数
//       d_creep_th1_d_stress = _fission_term * _density_term1 * _exp_Q1;
//     }
//     else
//     {
//       // 高应力区域：线性项无应力依赖（因为使用转变应力），幂律项有导数
//       d_creep_th2_d_stress = 4.5 * _a8 * _density_term2 * std::pow(stress, 3.5) * _exp_Q2;
//     }
//   }
//   else
//   {
//     // 不使用转变应力：两项都有导数
//     d_creep_th1_d_stress = _fission_term * _density_term1 * _exp_Q1;
//     d_creep_th2_d_stress = 4.5 * _a8 * _density_term2 * std::pow(stress, 3.5) * _exp_Q2;
//   }
  
//   // 辐照蠕变导数
//   ADReal d_creep_ir_d_stress = _a7 * _fission_rate * _exp_Q3;
  
//   // 应用链式法则计算蠕变率对scalar的导数（考虑退化函数影响）
//   ADReal d_scalar_rate_d_scalar = (d_creep_th1_d_stress + d_creep_th2_d_stress + d_creep_ir_d_stress) 
//                                 * d_stress_d_scalar * _g[_qp];
  
//   // 残差导数
//   return d_scalar_rate_d_scalar * _dt - 1.0;
// }

// void
// UO2DegradablePowerLawCreepStressUpdate::computeStressFinalize(
//     const ADRankTwoTensor & plastic_strain_increment)
// {
//   // 更新蠕变应变
//   _creep_strain[_qp] = _creep_strain_old[_qp] + plastic_strain_increment;
// }

// Real
// UO2DegradablePowerLawCreepStressUpdate::computeStrainEnergyRateDensity(
//     const ADMaterialProperty<RankTwoTensor> & stress,
//     const ADMaterialProperty<RankTwoTensor> & strain_rate)
// {
//   // 简化的应变能率密度计算
//   return MetaPhysicL::raw_value(stress[_qp].doubleContraction(strain_rate[_qp]));
// }