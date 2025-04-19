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
  virtual void initQpStatefulProperties() override;
  
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
  
  // 瞬态蠕变相关属性
  const bool _consider_transient_creep; // 是否考虑瞬态蠕变
  MaterialProperty<Real> & _max_stress_time; // 最大应力应用时间
  const MaterialProperty<Real> & _max_stress_time_old;
  MaterialProperty<Real> & _max_stress; // 历史最大应力
  const MaterialProperty<Real> & _max_stress_old;

  const bool _USE_MATPRO_Halden_model; // 是否考虑瞬态蠕变
  const bool _USE_transition_stress; // 是否考虑瞬态蠕变
};