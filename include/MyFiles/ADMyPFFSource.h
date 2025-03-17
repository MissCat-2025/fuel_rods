//* This file is part of the RACCOON application
//* being developed at Dolbow lab at Duke University
//* http://dolbow.pratt.duke.edu

#pragma once

#include "ADKernelValue.h"
#include "DerivativeMaterialPropertyNameInterface.h"

/**
 * 相场断裂演化方程的源项，基于变分原理实现
 * 演化方程的弱形式：
 * \f[
 *   \mathcal{R}(d) = -\frac{G_f}{\mathcal{N}\frac{\partial\alpha}{\partial d}/l} 
 *   - \frac{\partial\psi_e}{\partial d}
 * \f]
 * 其中：
 * - \f$d\f$ 为相场变量（损伤场）
 * - \f$G_f\f$ 为断裂能
 * - \f$\mathcal{N}\f$ 为归一化常数
 * - \f$\alpha\f$ 为正则化函数
 * - \f$l\f$ 为特征长度
 * - \f$\psi_e\f$ 为弹性应变能密度
 */
class ADMyPFFSource : public ADKernelValue, public DerivativeMaterialPropertyNameInterface
{
public:
  static InputParameters validParams();
  ADMyPFFSource(const InputParameters & parameters);

protected:
  virtual ADReal precomputeQpResidual() override;

private:
  /// 材料属性名称
  const MaterialPropertyName _alpha_name;
  /// 正则化函数对相场的导数
  const ADMaterialProperty<Real> & _dalpha_dd;
  
  /// 弹性应变能密度对相场的导数（裂纹驱动力）
  const ADMaterialProperty<Real> & _crack_driving_force;
  
  /// 断裂能
  const ADMaterialProperty<Real> & _Gf;
  
  /// 特征长度
  const ADMaterialProperty<Real> & _l;
  
  /// 归一化常数
  const ADMaterialProperty<Real> & _normalization_constant;
  

};
