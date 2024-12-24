#include "ADBurnupMaterial.h"
#include "Function.h"
registerMooseObject("FuelRodsApp", ADBurnupMaterial);

InputParameters
ADBurnupMaterial::validParams()
{
  InputParameters params = ADMaterial::validParams();
  params.addRequiredParam<MaterialPropertyName>("total_power", "总功率材料属性名");
  params.addParam<Real>("initial_density", 10412.0, "初始燃料密度 (kg/m³)");
  params.addClassDescription("计算局部燃耗的AD材料");
  return params;
}

ADBurnupMaterial::ADBurnupMaterial(const InputParameters & parameters)
  : ADMaterial(parameters),
    _total_power(getADMaterialProperty<Real>("total_power")),
    _initial_density(getParam<Real>("initial_density")),
    _burnup(declareADProperty<Real>("burnup")),
    _burnup_old(getMaterialPropertyOld<Real>("burnup"))
{
}

//getMaterialPropertyOld所以需要初始化
void
ADBurnupMaterial::initQpStatefulProperties()
{
  // 初始化燃耗为0
  _burnup[_qp] = 1e-10;
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
  
  const Real _dt = _fe_problem.dt();
  // 更新总燃耗
  _burnup[_qp] = _burnup_old[_qp] + _total_power[_qp] / alpha * _dt / N_f0;
}