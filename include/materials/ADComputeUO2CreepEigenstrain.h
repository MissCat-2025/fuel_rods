// include/materials/ADComputeUO2CreepEigenstrain.h
#pragma once
#include "ADComputeEigenstrainBase.h"

class ADComputeUO2CreepEigenstrain : public ADComputeEigenstrainBase
{
public:
  static InputParameters validParams();
  ADComputeUO2CreepEigenstrain(const InputParameters & parameters);

protected:
  virtual void computeQpEigenstrain() override;

  /// 从UO2CreepRate获取蠕变率
  const ADMaterialProperty<RankTwoTensor> & _creep_rate;

  /// 累积的蠕变特征应变
  ADMaterialProperty<RankTwoTensor> & _creep_strain;
  const MaterialProperty<RankTwoTensor> & _creep_strain_old;
};