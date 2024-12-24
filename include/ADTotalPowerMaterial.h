#pragma once

#include "ADMaterial.h"
#include "Function.h"  // 添加这行，有调用[function]就得包含这个
/**
 * 计算总功率密度 = 基础功率 * 径向分布
 * total_power = power_history * (1 + p1*burnup/33 * exp(-p2*(R-r)^p3))
 */
class ADTotalPowerMaterial : public ADMaterial
{
public:
  static InputParameters validParams();
  ADTotalPowerMaterial(const InputParameters & parameters);

protected:
  virtual void computeQpProperties() override;

  /// 功率历史函数 (W/m³)
  const Function & _power_history;
  
  /// 燃耗变量
  const VariableValue & _burnup;  // 改为变量，避免循环调用
  
  /// 模型参数
  const Real & _p1;
  const Real & _p2;
  const Real & _p3;
  const Real & _pellet_radius;
  
  /// 声明总功率材料属性
  ADMaterialProperty<Real> & _total_power;
  
  /// 声明径向功率分布材料属性（可选，用于输出）
  ADMaterialProperty<Real> & _radial_power_shape;
};
