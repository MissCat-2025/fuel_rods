// ADTotalPowerMaterial_NoBurnup.h
#pragma once

#include "ADMaterial.h"

class ADTotalPowerMaterial_NoBurnup : public ADMaterial
{
public:
  static InputParameters validParams();
  ADTotalPowerMaterial_NoBurnup(const InputParameters & parameters);

protected:
  virtual void computeQpProperties() override;

  /// 功率历史函数
  const Function & _power_history;

  /// 芯块半径
  const Real _pellet_radius;

  /// 功率分布参数
  const Real _p1;
  const Real _p2;
  const Real _p3;
  const Real _base;

  /// 总功率密度
  ADMaterialProperty<Real> & _total_power;

  /// 径向功率分布形状
  ADMaterialProperty<Real> & _radial_power_shape;

  /// 计算功率分布因子
  ADReal powerFactor(const Real & r_rel) const;
};