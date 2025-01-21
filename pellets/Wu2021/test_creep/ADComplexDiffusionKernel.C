#include "ADComplexDiffusionKernel.h"
//扩散率的数量级存在问题
registerMooseObject("FuelRodsApp", ADComplexDiffusionKernel);

InputParameters
ADComplexDiffusionKernel::validParams()
{
  InputParameters params = ADKernel::validParams();
  params.addRequiredCoupledVar("temperature", "Coupled temperature variable");
  params.addParam<Real>("R", 8.314, "Gas constant");
  return params;
}

ADComplexDiffusionKernel::ADComplexDiffusionKernel(const InputParameters & parameters)
  : ADKernel(parameters),
    _T(adCoupledValue("temperature")),
    _grad_T(adCoupledGradient("temperature")),
    _R(getParam<Real>("R"))
{
}

ADReal
ADComplexDiffusionKernel::computeQpResidual()
{
  // // 计算各个系数
  ADReal D = std::pow(10.0, (-9.386 - 4260/_T[_qp] + 0.0012*_T[_qp]*_u[_qp] + 0.00075*_T[_qp]*std::log10(1+2/_u[_qp])));
  ADReal F = (2.0 + _u[_qp])/(2.0 * (1.0 - 3.0*_u[_qp]) * (1.0 - 2.0*_u[_qp]));
  ADReal Q_star = -1380.8 - 134435.5*std::exp(-_u[_qp]/0.0261);
  ADReal temp_coef = _u[_qp] / F * Q_star / (_R * _T[_qp] * _T[_qp]);
  auto J = - D * (_grad_u[_qp] + temp_coef * _grad_T[_qp]);
    // 计算各个系数
  // ADReal D = std::exp(-9.386 - 4260/_T[_qp] + 0.0012*_T[_qp]*_u[_qp] + 0.00075*_T[_qp]*std::log(1+2/_u[_qp]));
  // ADReal F = (2.0 + _u[_qp])/(2.0 * (1.0 - 3.0*_u[_qp]) * (1.0 - 2.0*_u[_qp]));
  // ADReal Q_star = -1380.8 - 134435.5*std::exp(-_u[_qp]/0.0261);
  // ADReal temp_coef = _u[_qp] / F * Q_star / (_R * _T[_qp] * _T[_qp]);
  // auto J = - D * (_grad_u[_qp] + temp_coef * _grad_T[_qp]);

  // 在每次非线性迭代的第一个积分点就输出
  // if (_qp == 0)
  // {
  //   unsigned int nl_it = _fe_problem.getNonlinearSystemBase(0).getCurrentNonlinearIterationNumber();
  //   Moose::out << "\n=== 扩散参数 (时间步: " << _t_step 
  //             //  << ", 非线性迭代: " << nl_it << ") ===\n"
  //             //  << "温度 T = " << MetaPhysicL::raw_value(_T[_qp]) << " K\n"
  //             //  << "氧比率 x = " << MetaPhysicL::raw_value(_u[_qp]) << "\n"
  //              << "扩散系数 D = " << MetaPhysicL::raw_value(D) << " m²/s\n"
  //             //  << "几何因子 F = " << MetaPhysicL::raw_value(F) << "\n"
  //             //  << "热力学因子 Q* = " << MetaPhysicL::raw_value(Q_star) << " J/mol\n"
  //             //  << "温度系数 = " << MetaPhysicL::raw_value(temp_coef) << "\n"
  //              << "扩散通量 J = [" << MetaPhysicL::raw_value(J(0)) << ", " 
  //                                << MetaPhysicL::raw_value(J(1)) << ", " 
  //                                << MetaPhysicL::raw_value(J(2)) << "] mol/(m²·s)\n"
  //              << "=============================\n";
  // }
  
  return -(_grad_test[_i][_qp] * J);
}