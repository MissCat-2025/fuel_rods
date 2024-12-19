#include "ADBurnupMaterial.h"
#include "Function.h"
registerMooseObject("FuelRodsApp", ADBurnupMaterial);

InputParameters
ADBurnupMaterial::validParams()
{
  InputParameters params = ADMaterial::validParams();
  params.addRequiredParam<FunctionName>("power_density", "功率密度 (W/m³)");  // 改为FunctionName类型
  params.addParam<Real>("initial_density", 10412.0, "初始燃料密度 (kg/m³)");
  params.addClassDescription("计算局部燃耗的AD材料");
  return params;
}

ADBurnupMaterial::ADBurnupMaterial(const InputParameters & parameters)
  : ADMaterial(parameters),
    _power_density(getFunctionByName(getParam<FunctionName>("power_density"))),
    // _dt(getParam<Real>("_dt")),  // 使用系统参数_dt
    _initial_density(getParam<Real>("initial_density")),
    _burnup(declareADProperty<Real>("burnup")),
    _burnup_old(getMaterialPropertyOld<Real>("burnup"))
{
}

void
ADBurnupMaterial::computeQpProperties()
{
  // 常数定义
  const Real N_av = 6.022e23;    // 阿伏伽德罗常数
  const Real M_w = 270.0;        // UO2分子量 (g/mol)
  const Real alpha = 3.2845e-11; // 每次裂变释放的能量 (J/fission)
  // const Real conversion = 9.6e5; // 转换系数 (MWd/tU per fission/atom)
  
  // 计算初始重金属原子密度 (atoms/m³)
  const Real N_f0 = _initial_density * N_av / M_w * 1000.0;
  
  // 获取当前时间点的功率密度
  const Real current_power = _power_density.value(_t, _q_point[_qp]);
  
  // 计算裂变率 (fissions/m³/s)
  const ADReal fission_rate = current_power / alpha;

  const Real _dt = _fe_problem.dt();
  // 计算当前时间步的燃耗增量
  const ADReal burnup_increment = fission_rate * _dt / N_f0;  // 直接使用_dt
  
  // 更新总燃耗
  _burnup[_qp] = _burnup_old[_qp] + burnup_increment;
}