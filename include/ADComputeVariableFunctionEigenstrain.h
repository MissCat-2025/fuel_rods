#pragma once

#include "ADComputeEigenstrainBase.h"

class ADComputeVariableFunctionEigenstrain : public ADComputeEigenstrainBase
{
public:
  static InputParameters validParams();
  ADComputeVariableFunctionEigenstrain(const InputParameters & parameters);

protected:
  virtual void computeQpEigenstrain() override;
  virtual void initQpStatefulProperties() override;  // 添加初始化函数

  /// AD版本的预因子材料属性（总应变）
  const ADMaterialProperty<Real> & _prefactor;
  
  /// 上一时间步的预因子值
  const MaterialProperty<Real> & _prefactor_old;
  /// 上一时间步的本征应变
  const MaterialProperty<RankTwoTensor> & _eigenstrain_old;
  /// 本征应变基础张量
  RankTwoTensor _eigen_base_tensor;
};