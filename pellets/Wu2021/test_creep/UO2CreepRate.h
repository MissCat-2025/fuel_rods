// include/materials/UO2CreepRate.h
#pragma once
#include "ADMaterial.h"
#include "RankTwoTensor.h"
#include "RankTwoScalarTools.h"

class UO2CreepRate : public ADMaterial
{
public:
  static InputParameters validParams();
  UO2CreepRate(const InputParameters & parameters);

protected:
  virtual void computeQpProperties() override;
  // 输入变量
  const ADVariableValue & _temperature;
  const ADVariableValue & _oxygen_ratio;
  
  // 输入参数 - 这些是常量，使用Real
  const Real _fission_rate;
  const Real _theoretical_density;
  const Real _grain_size;
  const Real _gas_constant;
  
  // 应力相关
  const MaterialProperty<RankTwoTensor> & _stress_old;  // 旧应力不需要AD
  ADMaterialProperty<RankTwoTensor> & _stress_deviator;
  const ADVariableValue & _vonMisesStress;
  
  // 激活能 - Q1和Q2只依赖于oxygen_ratio，需要AD
  ADMaterialProperty<Real> & _Q1;
  ADMaterialProperty<Real> & _Q2;
  const Real _Q3;  // Q3是常量
  
  // 蠕变率
  ADMaterialProperty<RankTwoTensor> & _creep_rate;
};