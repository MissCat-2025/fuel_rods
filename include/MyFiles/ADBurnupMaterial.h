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
  // 添加这个函数来初始化状态变量
  virtual void initQpStatefulProperties() override;
  /// 总功率材料属性
  const ADMaterialProperty<Real> & _total_power;
  
  /// 时间步长
  // const Real & _dt;  // 修改为系统参数
  
  /// 初始燃料密度 (kg/m³)
  const Real & _initial_density;
  
  /// 声明材料属性
  ADMaterialProperty<Real> & _burnup;
  const MaterialProperty<Real> & _burnup_old;
};