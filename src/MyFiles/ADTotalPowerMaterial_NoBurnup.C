// ADTotalPowerMaterial_NoBurnup.C
#include "ADTotalPowerMaterial_NoBurnup.h"
#include "Function.h"  // 或者 #include "FunctionInterface.h"
registerMooseObject("FuelRodsApp", ADTotalPowerMaterial_NoBurnup);

InputParameters
ADTotalPowerMaterial_NoBurnup::validParams()
{
  InputParameters params = ADMaterial::validParams();
  params.addRequiredParam<FunctionName>("power_history", "功率历史函数");
  params.addRequiredParam<Real>("pellet_radius", "燃料芯块半径 (m)");
  params.addParam<Real>("p1", 1.372656, "指数函数参数p1");
  params.addParam<Real>("p2", 8.0, "指数函数参数p2");
  params.addParam<Real>("p3", 0.586372, "指数函数参数p3");
  params.addParam<Real>("base", 0.922920, "基准功率值");
  return params;
}

ADTotalPowerMaterial_NoBurnup::ADTotalPowerMaterial_NoBurnup(const InputParameters & parameters)
  : ADMaterial(parameters),
    _power_history(getFunctionByName("power_history")),
    _pellet_radius(getParam<Real>("pellet_radius")),
    _p1(getParam<Real>("p1")),
    _p2(getParam<Real>("p2")),
    _p3(getParam<Real>("p3")),
    _base(getParam<Real>("base")),
    _total_power(declareADProperty<Real>("total_power")),
    _radial_power_shape(declareADProperty<Real>("radial_power_shape"))
{
}

ADReal
ADTotalPowerMaterial_NoBurnup::powerFactor(const Real & r_rel) const
{
  const Real R0 = 1.0;
  
  // 径向功率分布形状（直接使用高燃耗分布形式）
  return _base + _p1 * std::exp(-_p2 * std::pow(R0 - r_rel, _p3));
}

void
ADTotalPowerMaterial_NoBurnup::computeQpProperties()
{
  // 计算相对半径
  const Point & p = _q_point[_qp];
  Real r = std::sqrt(p(0) * p(0) + p(1) * p(1));
  Real r_rel = r / _pellet_radius;
  
  // 计算功率分布形状
  _radial_power_shape[_qp] = powerFactor(r_rel);
  
  // 计算当前时刻的基础功率密度 (W/m³)
  Point curr_point(_q_point[_qp]);
  const Real power_base = _power_history.value(_t, curr_point);
  
  // 计算总功率密度
  _total_power[_qp] = power_base * _radial_power_shape[_qp];
}