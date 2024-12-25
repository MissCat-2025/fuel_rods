#pragma once

#include "ADMaterial.h"
#include "RankTwoTensor.h"

/**
 * 该类实现了基于FCREEP模型的UO2蠕变率计算
 * 参考NUREG/CR-6150-Rev. 2, Vol. 4
 */
class UO2CreepRate2 : public ADMaterial
{
public:
  static InputParameters validParams();
  UO2CreepRate2(const InputParameters & parameters);

protected:
  virtual void computeQpProperties() override;

  /// 温度
  const ADVariableValue & _temperature;
  
  /// 氧金属比
  const ADVariableValue & _oxygen_ratio;
  
  /// 裂变率
  const Real _fission_rate;
  
  /// 理论密度百分比
  const Real _theoretical_density;
  
  /// 晶粒尺寸(μm)
  const Real _grain_size;

  /// 自施加最大应力以来的时间 (s)。
  const Real _time_since_max_stress;
  /// 气体常数
  const Real _gas_constant;
  
  /// 旧应力
  const MaterialProperty<RankTwoTensor> & _stress_old;
  
  /// 应力偏差张量
  ADMaterialProperty<RankTwoTensor> & _stress_deviator;
  
  /// von Mises有效应力
  ADMaterialProperty<Real> & _effective_stress;
  
  /// 激活能
  ADMaterialProperty<Real> & _Q1;
  ADMaterialProperty<Real> & _Q2;
  const Real _Q3;
  
  /// 蠕变率 (用于特征应变计算)
  ADMaterialProperty<RankTwoTensor> & _creep_rate;
}; 