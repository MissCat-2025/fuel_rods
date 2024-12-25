// ADTotalPowerMaterial.C
#include "ADTotalPowerMaterial.h"

registerMooseObject("FuelRodsApp", ADTotalPowerMaterial);

InputParameters
ADTotalPowerMaterial::validParams()
{
  InputParameters params = ADMaterial::validParams();
  params.addRequiredParam<FunctionName>("power_history", "功率历史函数");
  params.addRequiredCoupledVar("burnup", "燃耗变量");
  params.addRequiredParam<Real>("pellet_radius", "燃料芯块半径 (m)");
  return params;
}

ADTotalPowerMaterial::ADTotalPowerMaterial(const InputParameters & parameters)
  : ADMaterial(parameters),
    _power_history(getFunctionByName("power_history")),
    _burnup(coupledValue("burnup")),
    _pellet_radius(getParam<Real>("pellet_radius")),
    _total_power(declareADProperty<Real>("total_power")),
    _radial_power_shape(declareADProperty<Real>("radial_power_shape"))
{
}

Real
ADTotalPowerMaterial::powerFactor1(const Real & r) const
{
  const Real p1 = 1.103856;
  const Real p2 = 1000.0;
  const Real p3 = 0.902720;
  
  return 0.827717 * (1.0 + p1 * std::exp(-p2 * std::pow(_pellet_radius - r, p3)));
}
Real
ADTotalPowerMaterial::powerFactor2(const Real & r) const
{
  return 1.000063 * (0.967758 + 2.671605 * r + 3131.781970 * r * r);
}

void
ADTotalPowerMaterial::computeQpProperties()
{
  // 计算径向位置
  const Point & p = _q_point[_qp];
  Real r = std::sqrt(p(0) * p(0) + p(1) * p(1));
  
  Real burnup_n = _burnup[_qp] * 9.6*100;
  // 根据燃耗计算径向功率分布
  if (burnup_n <= 33.0)
  {
    _radial_power_shape[_qp] = powerFactor1(r) * burnup_n / 33.0 + 
                               powerFactor2(r) * (1.0 - burnup_n / 33.0);
  }
  else
  {
    _radial_power_shape[_qp] = powerFactor1(r);
  }
  
  // 计算当前时刻的基础功率密度 (W/m³)
  Point curr_point(_q_point[_qp]);
  const Real power_base = _power_history.value(_t, curr_point);
  
  // 计算总功率密度
  _total_power[_qp] = power_base * _radial_power_shape[_qp];
}