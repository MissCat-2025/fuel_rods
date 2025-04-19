// //* This file is part of the RACCOON application
// //* being developed at Dolbow lab at Duke University
// //* http://dolbow.pratt.duke.edu

// #include "SmallDeformationUO2CreepModel.h"

// registerMooseObject("FuelRodsApp", SmallDeformationUO2CreepModel);

// InputParameters
// SmallDeformationUO2CreepModel::validParams()
// {
//   InputParameters params = SmallDeformationJ2Plasticity::validParams();
//   params.addClassDescription("UO2材料的小变形蠕变模型，结合了两种热蠕变机制和一种辐照蠕变机制");
  
//   params.addRequiredCoupledVar("temperature", "温度变量");
//   params.addRequiredCoupledVar("x", "氧超量化学计量");
//   params.addParam<Real>("D",98.0, "理论密度百分比");
//   params.addParam<Real>("Gr",10.0, "晶粒尺寸(μm)");
//   params.addParam<Real>("f", 1.2e19, "裂变率密度(fissions-m^-3-s^-1)");

//   params.addParam<Real>("R", 8.314, "通用气体常数(J/mol-K)");
//   params.addParam<Real>("Q3", 21759.0, "辐照蠕变激活能(J/mol)");
//   params.addParam<Real>("n_power", 4.5, "应力指数(热蠕变机制2使用)");
  
//   return params;
// }

// SmallDeformationUO2CreepModel::SmallDeformationUO2CreepModel(const InputParameters & parameters)
//   : SmallDeformationJ2Plasticity(parameters),
//     _dt(_fe_problem.dt()),
//     _temperature(adCoupledValue("temperature")),
//     _x(adCoupledValue("x")),
//     _D(getParam<Real>("D")),
//     _Gr(getParam<Real>("Gr")),
//     _f(getParam<Real>("f")),
//     _R(getParam<Real>("R")),
//     _Q3(getParam<Real>("Q3")),
//     _n_power(getParam<Real>("n_power"))
// {
// }

// ADReal
// SmallDeformationUO2CreepModel::computeCreepRate(const ADReal & effective_stress)
// {
//   // 第一种热蠕变机制 - 低应力扩散蠕变
//   ADReal th1_coef = (0.3919 + 1.31e-19 * _f) / ((_D - 87.7) * _Gr * _Gr);
//   ADReal Q1 = 74829.0 / (std::exp(-20.0 / std::log(_x[_qp]) - 8.0) + 1.0) + 301762.0;
//   ADReal creep_th1 = th1_coef * effective_stress * std::exp(-Q1 / (_R * _temperature[_qp]));
  
//   // 第二种热蠕变机制 - 高应力位错蠕变
//   ADReal th2_coef = 2.0391e-25 / (_D - 90.5);
//   ADReal Q2 = 83143.0 / (std::exp(-20.0 / std::log(_x[_qp]) - 8.0) + 1.0) + 469191.0;
//   ADReal creep_th2 = th2_coef * std::pow(effective_stress, _n_power) * 
//                      std::exp(-Q2 / (_R * _temperature[_qp]));
  
//   // 辐照蠕变机制
//   ADReal ir_coef = 3.7226e-35 * _f;
//   ADReal creep_ir = ir_coef * effective_stress * std::exp(-_Q3 / (_R * _temperature[_qp]));
  
//   // 总蠕变率
//   ADReal total_rate = creep_th1 + creep_th2 + creep_ir;
  
//   // 只输出一个简单的总结信息
//   _console << "\n★ 蠕变率: " << total_rate 
//            << " (T=" << _temperature[_qp] 
//            << ", x=" << _x[_qp] 
//            << ", σ=" << effective_stress << ")" << std::endl;
  
//   return total_rate;
// }

// ADReal
// SmallDeformationUO2CreepModel::computeResidual(const ADReal & effective_trial_stress,
//                                                const ADReal & delta_ep)
// {
//   const ADReal stress_delta = effective_trial_stress - 
//                             _elasticity_model->computeStress(delta_ep * _Np[_qp])
//                             .doubleContraction(_Np[_qp]);
  
//   // 计算蠕变率
//   const ADReal creep_rate = computeCreepRate(stress_delta);
  
//   ADReal residual = creep_rate * _dt - delta_ep;
  
//   _console << "\n◆ 残差: " << residual 
//            << " (σ_trial=" << effective_trial_stress
//            << ", Δεp=" << delta_ep << ")" << std::endl;
  
//   return residual;
// }

// ADReal
// SmallDeformationUO2CreepModel::computeDerivative(const ADReal & effective_trial_stress,
//                                                  const ADReal & delta_ep)
// {
//   // 这个函数实现较为复杂，需要对复合蠕变率对有效应力的导数进行计算
//   // 简化处理：使用数值微分
  
//   const ADReal stress_delta = effective_trial_stress - 
//                             _elasticity_model->computeStress(delta_ep * _Np[_qp])
//                             .doubleContraction(_Np[_qp]);
  
//   const ADReal dstress_delta_ddelta_ep = -_elasticity_model->computeStress(_Np[_qp])
//                                           .doubleContraction(_Np[_qp]);
  
//   // 微小扰动
//   const Real h = 1e-8;
//   const ADReal stress_plus = stress_delta + h;
  
//   // 计算导数
//   const ADReal creep_rate = computeCreepRate(stress_delta);
//   const ADReal creep_rate_plus = computeCreepRate(stress_plus);
//   const ADReal dcreep_rate_dstress = (creep_rate_plus - creep_rate) / h;
  
//   ADReal derivative = dcreep_rate_dstress * dstress_delta_ddelta_ep * _dt - 1;
  
//   _console << "\n■ 导数: " << derivative << std::endl;
  
//   return derivative;
// }