#pragma once

#include "ADKernel.h"

/**
 * 该类实现了复杂的氧扩散方程
 */
class ADComplexDiffusionKernel : public ADKernel
{
public:
  static InputParameters validParams();

  ADComplexDiffusionKernel(const InputParameters & parameters);

protected:
  virtual ADReal computeQpResidual() override;

  /// 计算扩散系数D
  ADReal computeD() const;
  
  /// 计算热力学因子F
  ADReal computeF() const;
  
  /// 计算热传输系数Q_star
  ADReal computeQStar() const;

  /// 温度
  const ADVariableValue & _T;
  
  /// 温度梯度
  const ADVariableGradient & _grad_T;
  
  /// 气体常数
  const Real _R;
};