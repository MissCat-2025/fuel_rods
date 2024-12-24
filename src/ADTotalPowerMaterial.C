#include "ADTotalPowerMaterial.h"

registerMooseObject("FuelRodsApp", ADTotalPowerMaterial);

InputParameters
ADTotalPowerMaterial::validParams()
{
  InputParameters params = ADMaterial::validParams();
  params.addRequiredParam<FunctionName>("power_history", "功率历史函数");
  params.addRequiredCoupledVar("burnup", "燃耗变量");  // 改为耦合变量
  params.addParam<Real>("p1", 1.2, "径向分布参数p1");
  params.addParam<Real>("p2", 500.0, "径向分布参数p2");
  params.addParam<Real>("p3", 0.75, "径向分布参数p3");
  params.addRequiredParam<Real>("pellet_radius", "燃料芯块半径 (m)");
  return params;
}

ADTotalPowerMaterial::ADTotalPowerMaterial(const InputParameters & parameters)
  : ADMaterial(parameters),
    _power_history(getFunctionByName("power_history")),
    _burnup(coupledValue("burnup")),  // 使用coupledValue获取变量值
    _p1(getParam<Real>("p1")),
    _p2(getParam<Real>("p2")),
    _p3(getParam<Real>("p3")),
    _pellet_radius(getParam<Real>("pellet_radius")),
    _total_power(declareADProperty<Real>("total_power")),
    _radial_power_shape(declareADProperty<Real>("radial_power_shape"))
{
}

void
ADTotalPowerMaterial::computeQpProperties()
{
  // 计算径向位置
  const Point & p = _q_point[_qp];
  Real r = std::sqrt(p(0) * p(0) + p(1) * p(1));
  
  // 计算径向功率分布因子
  _radial_power_shape[_qp] = 1.0 + (_p1 * _burnup[_qp] / 33.0) * 
                             std::exp(-_p2 * std::pow(_pellet_radius - r, _p3));
  
  // 计算当前时刻的基础功率密度 (W/m³)
  const Real power_base = _power_history.value(_t, _q_point[_qp]);
  
  // 计算总功率密度
  _total_power[_qp] = power_base * _radial_power_shape[_qp];
}