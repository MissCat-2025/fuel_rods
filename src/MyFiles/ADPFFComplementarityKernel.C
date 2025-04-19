#include "ADPFFComplementarityKernel.h"

registerMooseObject("FuelRodsApp", ADPFFComplementarityKernel);

InputParameters
ADPFFComplementarityKernel::validParams()
{
  InputParameters params = ADKernel::validParams();
  params.addClassDescription("互补性约束相场断裂模型: -g'(ϕ)Y̅ + G_c/c_0[1/l α'(ϕ) - 2l Δϕ] ≥ 0, ϕ̇ ≥ 0,特别注意一下它的弱形式，即全部同号");
  
  params.addParam<MaterialPropertyName>("degradation_function", "g", "退化函数g(d)的名称");
  params.addParam<MaterialPropertyName>("strain_energy", "Y_bar", "有效应变能密度");
  params.addParam<MaterialPropertyName>("fracture_toughness", "Gc", "断裂韧性");
  params.addParam<MaterialPropertyName>("normalization_constant", "c0", "归一化常数");
  params.addParam<MaterialPropertyName>("regularization_length", "l", "正则化长度");
  params.addParam<MaterialPropertyName>("geometric_function", "alpha", "几何函数α(d)的名称");
  params.addParam<Real>("rate_tolerance", 1e-8, "判断相场变化率为零的容差");
  
  return params;
}

ADPFFComplementarityKernel::ADPFFComplementarityKernel(const InputParameters & parameters)
  : ADKernel(parameters),
    DerivativeMaterialPropertyNameInterface(),
    _u_old(_var.slnOld()),
    _g_name(getParam<MaterialPropertyName>("degradation_function")),
    _dg_dd(getADMaterialProperty<Real>(derivativePropertyNameFirst(_g_name, _var.name()))),
    _Y_bar(getADMaterialProperty<Real>(getParam<MaterialPropertyName>("strain_energy"))),
    _Gc(getADMaterialProperty<Real>(getParam<MaterialPropertyName>("fracture_toughness"))),
    _c0(getADMaterialProperty<Real>(getParam<MaterialPropertyName>("normalization_constant"))),
    _l(getADMaterialProperty<Real>(getParam<MaterialPropertyName>("regularization_length"))),
    _alpha_name(getParam<MaterialPropertyName>("geometric_function")),
    _dalpha_dd(getADMaterialProperty<Real>(derivativePropertyNameFirst(_alpha_name, _var.name()))),
    _rate_tolerance(getParam<Real>("rate_tolerance"))
{
  _phi_rate.resize(_fe_problem.getMaxQps(), 0.0);
  _is_active.resize(_fe_problem.getMaxQps(), true);
}

void
ADPFFComplementarityKernel::timestepSetup()
{
  // 在每个时间步开始时重置状态
  _phi_rate.assign(_phi_rate.size(), 0.0);
  _is_active.assign(_is_active.size(), true);
  
  // 使用Moose::out替代_console
  Moose::out << "时间步设置 - 当前步: " << _t_step << ", 时间: " << _t << ", dt: " << _dt << std::endl;
}

ADReal
ADPFFComplementarityKernel::computeQpResidual()
{
  // 只在每个元素的第一个积分点输出，防止输出过多
  // if ((_t_step == 1 || _t_step == 2) && _qp == 0) 
  // {
  //   for (unsigned int i = 0; i < 1; i++)
  //   {
  //     // 基本信息
  //     Moose::out << "\n============ 调试信息 ============\n";
  //     Moose::out << "时间步: " << _t_step << ", 时间: " << _t << ", 元素ID: " << _current_elem->id()
  //            << ", 积分点: " << _qp << std::endl;
    
  //   // 相场变量状态
  //   Moose::out << "φ(当前) = " << MetaPhysicL::raw_value(_u[_qp])
  //            << ", φ(上一步) = " << _u_old[_qp]
  //            << ", 变化量: " << MetaPhysicL::raw_value(_u[_qp] - _u_old[_qp])
  //            << ", dt = " << _dt << std::endl;
    
  //   // 能量和驱动力项
  //   Moose::out << "应变能 Y_bar = " << MetaPhysicL::raw_value(_Y_bar[_qp])
  //            << ", 退化函数导数 dg/dd = " << MetaPhysicL::raw_value(_dg_dd[_qp]) << std::endl;
    
  //   // 断裂参数
  //   Moose::out << "断裂韧性 Gc = " << MetaPhysicL::raw_value(_Gc[_qp])
  //            << ", 正则化长度 l = " << MetaPhysicL::raw_value(_l[_qp])
  //            << ", 归一化常数 c0 = " << MetaPhysicL::raw_value(_c0[_qp]) << std::endl;
    
  //   // 几何函数导数
  //   Moose::out << "几何函数导数 dα/dd = " << MetaPhysicL::raw_value(_dalpha_dd[_qp]) << std::endl;
  //   }
  // }
//特别注意弱形式下，3个项都是同号的
  // 计算Laplacian项
  ADReal laplacian_term = 2.0 * _l[_qp] * _Gc[_qp] / _c0[_qp] * _grad_test[_i][_qp] * _grad_u[_qp];
  
  // 计算几何函数导数项
  ADReal geo_term = _Gc[_qp] / _l[_qp]  / _c0[_qp] * _dalpha_dd[_qp] * _test[_i][_qp];
  
  // 计算退化函数导数与能量项
  ADReal degradation_term = _dg_dd[_qp] * _Y_bar[_qp] * _test[_i][_qp];
  
  // 构建完整的互补性约束
  ADReal residual = degradation_term + geo_term + laplacian_term;
  
  // 计算相场变化率
  Real phi_rate = MetaPhysicL::raw_value(_u[_qp] - _u_old[_qp]) / _dt;
  _phi_rate[_qp] = phi_rate;
    // 提取残差的原始值（不含导数信息）
  Real raw_residual = MetaPhysicL::raw_value(residual);
  // 详细输出各项计算结果 - 同样只在特定积分点输出
  // if ((_t_step == 1 || _t_step == 2) && _qp == 0)
  // {
  //   for (unsigned int i = 0; i < 1; i++)
  //   {
  //     Moose::out << "-----计算项-----\n";
  //     Moose::out << "Laplacian项 = " << MetaPhysicL::raw_value(laplacian_term) << std::endl;
  //     Moose::out << "几何函数项 = " << MetaPhysicL::raw_value(geo_term) << std::endl;
  //   Moose::out << "退化能量项 = " << MetaPhysicL::raw_value(degradation_term) << std::endl;
  //     Moose::out << "总残差 = " << MetaPhysicL::raw_value(residual) << std::endl;
  //   Moose::out << "相场变化率 = " << phi_rate << std::endl;
  //     Moose::out << "容差值 = " << _rate_tolerance << std::endl;
  //     Moose::out << "是否激活 = " << (_is_active[_qp] ? "是" : "否") << std::endl;
  //     Moose::out << "============================\n";
  //   }
  // }
  
  // 基于互补性条件的因果逻辑实现
  // 情况1：相场不变（φ̇ ≈ 0）
if (std::abs(phi_rate) < _rate_tolerance)
  {
    // 驱动力不足，保持φ不变
    if (raw_residual > 0.0)
    {
      _is_active[_qp] = false;
      return 0.0;
    }
    // 驱动力充足，允许φ变化
    else
    {
      _is_active[_qp] = true;
      return residual;
    }
  }
  // 情况2：相场正在演化（φ̇ > 0）
  else
  {
    _is_active[_qp] = true;
    
    // 当相场变化时，要确保残差约等于0
    // 如果残差明显小于0，添加校正项推向0
    if (raw_residual < -_rate_tolerance)
    {
      // 添加校正项使残差接近0
      return residual + std::abs(raw_residual) * _test[_i][_qp];
    }
    
    return residual;
  }
  
  // 否则返回正常的残差项
  return residual;
}