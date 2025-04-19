// include/materials/ADComputeUO2CreepEigenstrain.h
#pragma once
#include "ADComputeEigenstrainBase.h"

class ADComputeUO2CreepEigenstrain : public ADComputeEigenstrainBase
{
public:
  static InputParameters validParams();
  ADComputeUO2CreepEigenstrain(const InputParameters & parameters);

protected:
  virtual void initQpStatefulProperties() override;
  virtual void computeQpEigenstrain() override;

  /// 从UO2CreepRate获取蠕变率
  const ADMaterialProperty<RankTwoTensor> & _creep_rate;

  /// 累积的蠕变特征应变 - 旧值不需要AD
  ADMaterialProperty<RankTwoTensor> & _creep_strain;
  const MaterialProperty<RankTwoTensor> & _creep_strain_old;

  // 添加psip_active和相关材料属性
  ADMaterialProperty<Real> & _psip_active;
// ADComputeUO2CreepEigenstrain.h
  const ADMaterialProperty<RankTwoTensor> & _stress_deviator;
};