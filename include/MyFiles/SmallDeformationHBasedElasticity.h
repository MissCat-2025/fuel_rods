#pragma once
#include "SmallDeformationElasticityModel.h"
#include "DerivativeMaterialPropertyNameInterface.h"

class SmallDeformationHBasedElasticity : public SmallDeformationElasticityModel,
                                          public DerivativeMaterialPropertyNameInterface
{
public:
  static InputParameters validParams();
  SmallDeformationHBasedElasticity(const InputParameters & parameters);

  virtual ADRankTwoTensor computeStress(const ADRankTwoTensor & strain) override;

protected:
  // 严格按照参考代码顺序声明成员变量
  const ADMaterialProperty<Real> & _E0;  // 对应参考代码的_K
  const ADMaterialProperty<Real> & _nu;    // 对应参考代码的_G
  const ADMaterialProperty<Real> & _ft;
  const ADMaterialProperty<Real> & _Gf;
  const VariableName _d_name;             // 与参考代码完全一致
  const MaterialPropertyName _psie_name; // 应变能密度声明在前
  ADMaterialProperty<Real> & _psie;
  ADMaterialProperty<Real> & _psie_active;
  ADMaterialProperty<Real> & _dpsie_dd;
  const MaterialPropertyName _g_name;     // 降解函数声明在后
  const ADMaterialProperty<Real> & _g;
  const ADMaterialProperty<Real> & _dg_dd;
  ADMaterialProperty<Real> & _H;         // 历史变量声明在最后
  const MaterialProperty<Real> & _H_old;
};