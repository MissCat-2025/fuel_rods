// include/materials/UO2CreepRate.h
#pragma once
#include "ADMaterial.h"
#include "RankTwoTensor.h"

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
  
  // 输入参数
  const Real _fission_rate;
  const Real _theoretical_density;
  const Real _grain_size;
  const Real _gas_constant;
  
  // 材料属性
  const MaterialProperty<RankTwoTensor> & _stress_old;  // 使用AD版本的旧应力
  ADMaterialProperty<RankTwoTensor> & _stress_deviator;
  ADMaterialProperty<Real> & _effective_stress;
  
  // 激活能
  ADMaterialProperty<Real> & _Q1;
  ADMaterialProperty<Real> & _Q2;
  const Real _Q3;
  
  // 蠕变率
  ADMaterialProperty<RankTwoTensor> & _creep_rate;
};