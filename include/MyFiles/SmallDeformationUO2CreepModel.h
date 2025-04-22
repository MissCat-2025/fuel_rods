// //* This file is part of the RACCOON application
// //* being developed at Dolbow lab at Duke University
// //* http://dolbow.pratt.duke.edu

// #pragma once

// #include "SmallDeformationPlasticityModel.h"
// #include "PlasticHardeningModel.h"

// /**
//  * UO2材料的小变形蠕变模型
//  * 虽然继承自塑性模型，但实现的是UO2蠕变行为
//  * 使用径向返回算法求解蠕变增量
//  */
// class SmallDeformationUO2CreepModel : public SmallDeformationPlasticityModel
// {
// public:
//   static InputParameters validParams();

//   SmallDeformationUO2CreepModel(const InputParameters & parameters);

//   virtual void updateState(ADRankTwoTensor & stress, ADRankTwoTensor & elastic_strain) override;

// protected:
//   // 计算UO2蠕变率函数
//   ADReal computeCreepRate(const ADReal & effective_stress);
  
//   // 计算转变应力
//   ADReal computeTransitionStress() const;
  
//   // 实现径向返回所需的残差和导数函数
//   virtual ADReal computeResidual(const ADReal & effective_trial_stress,
//                                 const ADReal & delta_ep) override;
//   virtual ADReal computeDerivative(const ADReal & effective_trial_stress,
//                                   const ADReal & delta_ep) override;
//   virtual Real computeReferenceResidual(const ADReal & effective_trial_stress,
//                                        const ADReal & delta_ep) override;

//   // 蠕变模型参数
//   const ADVariableValue & _temperature; // 温度
//   const ADVariableValue & _oxygen_ratio; // 氧超量化学计量比
//   const Real _fission_rate; // 裂变率密度
//   const Real _theoretical_density; // 理论密度百分比
//   const Real _grain_size; // 晶粒尺寸(μm)
//   const Real _gas_constant; // 气体常数
//   const Real _Q3; // 辐照蠕变激活能
  
//   // 瞬态蠕变相关
//   const bool _consider_transient_creep; // 是否考虑瞬态蠕变
//   MaterialProperty<Real> & _max_stress_time; // 最大应力应用时间
//   const MaterialProperty<Real> & _max_stress_time_old;
//   ADMaterialProperty<Real> & _max_stress; // 历史最大应力，改为AD类型
//   const MaterialProperty<Real> & _max_stress_old;
  
//   // 时间步长，用于蠕变率计算
//   const Real & _dt;
// };