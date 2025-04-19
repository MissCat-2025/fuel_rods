#pragma once

#include "ADKernel.h"
#include "DerivativeMaterialPropertyNameInterface.h"

class ADPFFComplementarityKernel : public ADKernel,
                                   public DerivativeMaterialPropertyNameInterface
{
public:
  static InputParameters validParams();
  ADPFFComplementarityKernel(const InputParameters & parameters);

protected:
  virtual ADReal computeQpResidual() override;
  virtual void timestepSetup() override;

  // 存储上一时间步的相场值
  const VariableValue & _u_old;
  
  // 材料属性
  const MaterialPropertyName _g_name;
  const ADMaterialProperty<Real> & _dg_dd;
  const ADMaterialProperty<Real> & _Y_bar; // 有效应变能
  const ADMaterialProperty<Real> & _Gc;
  const ADMaterialProperty<Real> & _c0;
  const ADMaterialProperty<Real> & _l;
  
  // 几何函数及其导数
  const MaterialPropertyName _alpha_name;
  const ADMaterialProperty<Real> & _dalpha_dd;
  
  // 相场变化率和容差
  std::vector<Real> _phi_rate;
  Real _rate_tolerance;
  
  // 用于存储是否激活互补性条件
  std::vector<bool> _is_active;
};