#pragma once

#include "ADMaterial.h"
#include "Function.h"
class ADBurnupMaterial : public ADMaterial
{
public:
  static InputParameters validParams();

  ADBurnupMaterial(const InputParameters & parameters);

protected:
  virtual void computeQpProperties() override;

  /// 功率密度函数 (W/m³)
  const Function & _power_density;
  
  /// 时间步长
  // const Real & _dt;  // 修改为系统参数
  
  /// 初始燃料密度 (kg/m³)
  const Real & _initial_density;
  
  /// 声明材料属性
  ADMaterialProperty<Real> & _burnup;
  const MaterialProperty<Real> & _burnup_old;
};