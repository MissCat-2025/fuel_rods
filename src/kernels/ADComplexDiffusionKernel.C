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
ADComplexDiffusionKernel::computeD() const
{
  // 保护浓度和温度，确保都为正且不太小
  ADReal u = std::max(std::abs(_u[_qp]), 1e-6);
  ADReal T = std::max(std::abs(_T[_qp]), 1e-6);
  
  // 扩散系数必须为正值
  return std::pow(10.0, (-9.386 - 4260/T + 0.0012*T*u 
         + 0.00075*T*std::log10(1+2/u)));
}

ADReal
ADComplexDiffusionKernel::computeF() const
{
  // F 函数在物理上有定义域限制：u < 1/3
  ADReal u = std::min(std::abs(_u[_qp]), 0.32);  // 略小于1/3
  
  // 保护分母
  ADReal denom1 = std::max(1.0 - 3.0*u, 1e-8);
  ADReal denom2 = std::max(1.0 - 2.0*u, 1e-8);
  
  // F 应该为正值
  return std::max((2.0 + u)/(2.0 * denom1 * denom2), 1e-8);
}

ADReal
ADComplexDiffusionKernel::computeQStar() const
{
  // 计算热传输系数
  
  return -1380.8 - 134435.5*std::exp(-_u[_qp]/0.0261);
}

ADReal
ADComplexDiffusionKernel::computeQpResidual()
{
  // 计算各个系数
  ADReal D = computeD();  // 已确保为正
  ADReal F = computeF();  // 已确保为正
  ADReal Q_star = computeQStar();
  
  // 温度必须为正
  ADReal T = std::max(std::abs(_T[_qp]), 1e-8);
  
  // 计算温度系数
  ADReal temp_coef = _u[_qp] / F * Q_star / (_R * T * T);
  
  // 计算通量
  auto J = -D * (_grad_u[_qp] + temp_coef * _grad_T[_qp]);
  
  return -(_grad_test[_i][_qp] * J);
}