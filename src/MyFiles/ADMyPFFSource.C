//* This file is part of the RACCOON application
//* being developed at Dolbow lab at Duke University
//* http://dolbow.pratt.duke.edu

#include "ADMyPFFSource.h"

registerMooseObject("FuelRodsApp", ADMyPFFSource);

InputParameters
ADMyPFFSource::validParams()
{
  InputParameters params = ADKernelValue::validParams();
  params.addClassDescription("相场断裂演化方程的源项，实现基于变分方法的断裂演化。"
                           "该内核计算：\\f$ -\\frac{G_f}{\\mathcal{N}\\frac{\\partial\\alpha}{\\partial d}/l} "
                           "- \\frac{\\partial\\psi_e}{\\partial d} \\f$");
  
  // 相场断裂的关键参数
  params.addRequiredParam<MaterialPropertyName>("fracture_energy",
                                              "断裂能 \\f$G_f\\f$");
  params.addRequiredParam<MaterialPropertyName>("crack_geometric",
                                              "特征长度 \\f$l\\f$");
  params.addRequiredParam<MaterialPropertyName>("CrackDrivingForce",
                                              "裂纹驱动力 \\f$\\frac{\\partial\\psi_e}{\\partial d}\\f$");
  // 自动对接参数（设置默认名称）
  params.addParam<MaterialPropertyName>("normalization_constant",
                                      "归一化常数 \\f$\\mathcal{N}\\f$");

  
  return params;
}

ADMyPFFSource::ADMyPFFSource(const InputParameters & parameters)
  : ADKernelValue(parameters),
    DerivativeMaterialPropertyNameInterface(),
    // 首先初始化材料属性名称
    _alpha_name("alpha"),
    // 然后按照头文件中声明的顺序初始化其他成员
    _dalpha_dd(getADMaterialProperty<Real>(derivativePropertyNameFirst(_alpha_name,  _var.name()))),
    _crack_driving_force(getADMaterialProperty<Real>("CrackDrivingForce")),
    _Gf(getADMaterialProperty<Real>("fracture_energy")),
    _l(getADMaterialProperty<Real>("crack_geometric")), // 修正参数名称
    _normalization_constant(getADMaterialProperty<Real>("normalization_constant"))
{
}

ADReal
ADMyPFFSource::precomputeQpResidual()
{
  // 计算几何项（分母）
  const ADReal geometric_term = _normalization_constant[_qp]  * _l[_qp];
  
  // 计算断裂项（第一项）
  const ADReal fracture_term = -_Gf[_qp] * _dalpha_dd[_qp] / geometric_term;
  
  // 裂纹驱动力项（第二项）
  const ADReal driving_force = _crack_driving_force[_qp];
  
  // 总残差
  const ADReal residual = fracture_term + driving_force;

  // 调试输出（仅在第一个积分点）
  // if (_qp == 0)
  // {
  //   sleep(0.5);
  //   Moose::out << "\n[相场断裂演化] "
  //              << "时间步=" << _t_step 
  //              << ", 特征长度=" << MetaPhysicL::raw_value(_dalpha_dd[_qp])
  //              << "\n  几何项=" << MetaPhysicL::raw_value(geometric_term)
  //              << "\n  几何驱动力=" << MetaPhysicL::raw_value(fracture_term)
  //              << "\n  裂纹有效驱动力=" << MetaPhysicL::raw_value(driving_force)
  //              << "\n  总残差=" << MetaPhysicL::raw_value(residual)
  //              << "\n================================" << std::endl;
  // }

  return residual;
}
