// SmallDeformationIsotropicElasticityThreshold.h
#pragma once

#include "SmallDeformationElasticityModel.h"
#include "DerivativeMaterialPropertyNameInterface.h"

/**
 * 各向同性弹性材料，可选阈值能量，直接使用杨氏模量和泊松比作为输入参数
 */
class SmallDeformationIsotropicElasticityThreshold : public SmallDeformationElasticityModel,
                                                    public DerivativeMaterialPropertyNameInterface
{
public:
  static InputParameters validParams();
  SmallDeformationIsotropicElasticityThreshold(const InputParameters & parameters);
  
  virtual ADRankTwoTensor computeStress(const ADRankTwoTensor & strain) override;

protected:
  // 弹性参数
  const ADMaterialProperty<Real> & _youngs_modulus;
  const ADMaterialProperty<Real> & _poissons_ratio;
  
  // 相场变量名
  const VariableName _d_name;
  
  // 能量密度及其导数
  const MaterialPropertyName _psie_name;
  ADMaterialProperty<Real> & _psie;
  ADMaterialProperty<Real> & _psie_active;
  ADMaterialProperty<Real> & _dpsie_dd;
  
  // 退化函数及其导数
  const MaterialPropertyName _g_name;
  const ADMaterialProperty<Real> & _g;
  const ADMaterialProperty<Real> & _dg_dd;
  
  // 阈值参数
  const bool _use_threshold;
  const ADMaterialProperty<Real> & _sigma_c;
  
  // 分解方法
  enum class Decomposition { none, spectral, voldev };
  const Decomposition _decomposition;
  
  // 计算方法
  ADRankTwoTensor computeStressNoDecomposition(const ADRankTwoTensor & strain);
  ADRankTwoTensor computeStressSpectralDecomposition(const ADRankTwoTensor & strain);
  ADRankTwoTensor computeStressVolDevDecomposition(const ADRankTwoTensor & strain);
  
  // 应用阈值
  ADReal applyThreshold(ADReal psie_active_raw);
};