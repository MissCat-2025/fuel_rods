// //* This file is part of the RACCOON application
// //* being developed at Dolbow lab at Duke University
// //* http://dolbow.pratt.duke.edu

// #pragma once

// #include "Material.h"
// #include "BaseNameInterface.h"
// #include "SmallDeformationElasticityModel.h"
// #include "SmallDeformationPlasticityModel.h"
// #include "StressUpdateBase.h"
// #include "ADRankTwoTensorForward.h"
// #include "ADRankFourTensorForward.h"

// /**
//  * ComputeSmallDeformationStressAll计算应力，支持弹性、塑性和蠕变模型的组合。
//  * 通过集成ADComputeMultipleInelasticStress逻辑，支持多种非弹性行为。
//  * 假设小变形条件，先处理蠕变，后处理塑性。
//  */
// class ComputeSmallDeformationStressAll : public Material, public BaseNameInterface
// {
// public:
//   static InputParameters validParams();
//   ComputeSmallDeformationStressAll(const InputParameters & parameters);
  
// protected:
//   virtual void initialSetup() override;
//   virtual void initQpStatefulProperties() override;
//   virtual void computeQpProperties() override;

//   /// 用于非弹性行为的更新逻辑，类似于ADComputeMultipleInelasticStress::updateQpState
//   void updateQpState(ADRankTwoTensor & elastic_strain_increment,
//                     ADRankTwoTensor & combined_inelastic_strain_increment);
                    
//   /// 处理单个非弹性模型
//   void updateQpStateSingleModel(unsigned model_number,
//                                ADRankTwoTensor & elastic_strain_increment,
//                                ADRankTwoTensor & combined_inelastic_strain_increment);
                               
//   /// 计算一个特定非弹性模型的可接受状态
//   void computeAdmissibleState(unsigned model_number,
//                              ADRankTwoTensor & elastic_strain_increment,
//                              ADRankTwoTensor & inelastic_strain_increment);
                             
//   /// 将非AD类型转换为AD类型的辅助函数
//   ADRankTwoTensor convertToAD(const RankTwoTensor & tensor);

//   /// 机械应变
//   const ADMaterialProperty<RankTwoTensor> & _mechanical_strain;
  
//   /// 上一步的机械应变
//   const MaterialProperty<RankTwoTensor> & _mechanical_strain_old;
  
//   /// 应力
//   ADMaterialProperty<RankTwoTensor> & _stress;
  
//   /// 上一步的应力
//   const MaterialProperty<RankTwoTensor> & _stress_old;
  
//   /// 弹性张量
//   const ADMaterialProperty<RankFourTensor> & _elasticity_tensor;
  
//   /// 弹性模型
//   SmallDeformationElasticityModel * _elasticity_model;
  
//   /// 非弹性模型列表
//   std::vector<ADStressUpdateBase *> _inelastic_models;
  
//   /// 非弹性应变总和
//   ADMaterialProperty<RankTwoTensor> & _inelastic_strain;
  
//   /// 上一步的非弹性应变
//   const MaterialProperty<RankTwoTensor> & _inelastic_strain_old;
  
//   /// 非弹性模型数量
//   unsigned int _num_models;
  
//   /// 非弹性权重
//   std::vector<Real> _inelastic_weights;
  
//   /// 是否循环使用模型
//   bool _cycle_models;
  
//   /// 材料时间步长限制
//   MaterialProperty<Real> & _material_timestep_limit;
  
//   /// 迭代求解的最大迭代次数
//   const unsigned int _max_iterations;
  
//   /// 迭代求解的相对收敛容差
//   const Real _relative_tolerance;
  
//   /// 迭代求解的绝对收敛容差
//   const Real _absolute_tolerance;
  
//   /// 是否输出完整迭代历史
//   const bool _internal_solve_full_iteration_history;
// };