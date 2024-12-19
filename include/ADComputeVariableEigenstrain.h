#pragma once

#include "ADComputeEigenstrainBase.h"

/**
 * ADComputeVariableEigenstrain 计算一个本征应变,该本征应变是由基础张量和标量函数(在AD材料中定义)的函数
 */
class ADComputeVariableEigenstrain : public ADComputeEigenstrainBase
{
public:
  static InputParameters validParams();

  ADComputeVariableEigenstrain(const InputParameters & parameters);

protected:
  virtual void computeQpEigenstrain() override;

  /// AD版本的预因子材料属性
  const ADMaterialProperty<Real> & _prefactor;
  
  /// 本征应变基础张量
  RankTwoTensor _eigen_base_tensor;
};