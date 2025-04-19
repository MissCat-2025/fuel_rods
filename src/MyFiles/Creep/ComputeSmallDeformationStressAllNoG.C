// //* This file is part of the RACCOON application
// //* being developed at Dolbow lab at Duke University
// //* http://dolbow.pratt.duke.edu

// #include "ComputeSmallDeformationStressAll.h"
// #include "MooseException.h"

// registerMooseObject("FuelRodsApp", ComputeSmallDeformationStressAll);

// InputParameters
// ComputeSmallDeformationStressAll::validParams()
// {
//   InputParameters params = Material::validParams();
//   params += BaseNameInterface::validParams();
//   params.addClassDescription("应力计算器，支持弹性、塑性和蠕变模型的组合，假设小变形。"
//                            "利用ADComputeMultipleInelasticStress逻辑处理非弹性行为。"
//                            "先处理蠕变后处理塑性。");

//   params.addRequiredParam<MaterialName>("elasticity_model", "弹性本构模型的名称");
//   params.addRequiredParam<std::vector<MaterialName>>(
//       "inelastic_models",
//       "用于计算应力和非弹性应变的材料对象。注意：先指定蠕变模型，再指定塑性模型。");
  
//   params.addParam<std::vector<Real>>("combined_inelastic_strain_weights",
//                                      "非弹性应变的加权和权重，默认全为1");
//   params.addParam<bool>("cycle_models", false, "在时间步N只使用第N%num_models个非弹性模型");
  
//   params.addParam<unsigned int>("max_iterations", 30, "应力迭代求解的最大迭代次数");
//   params.addParam<Real>("relative_tolerance", 1e-5, "应力迭代求解的相对收敛容差");
//   params.addParam<Real>("absolute_tolerance", 1e-5, "应力迭代求解的绝对收敛容差");
//   params.addParam<bool>(
//       "internal_solve_full_iteration_history",
//       false,
//       "设为true可输出应力更新迭代信息");

//   params.suppressParameter<bool>("use_displaced_mesh");
//   return params;
// }

// ComputeSmallDeformationStressAll::ComputeSmallDeformationStressAll(const InputParameters & parameters)
//   : Material(parameters),
//     BaseNameInterface(parameters),
//     _mechanical_strain(getADMaterialProperty<RankTwoTensor>(prependBaseName("mechanical_strain"))),
//     _mechanical_strain_old(getMaterialPropertyOld<RankTwoTensor>(prependBaseName("mechanical_strain"))),
//     _stress(declareADProperty<RankTwoTensor>(prependBaseName("stress"))),
//     _stress_old(getMaterialPropertyOld<RankTwoTensor>(prependBaseName("stress"))),
//     _elasticity_tensor(getADMaterialProperty<RankFourTensor>("elasticity_tensor")),
//     _inelastic_strain(declareADProperty<RankTwoTensor>(prependBaseName("combined_inelastic_strain"))),
//     _inelastic_strain_old(getMaterialPropertyOld<RankTwoTensor>(prependBaseName("combined_inelastic_strain"))),
//     _num_models(getParam<std::vector<MaterialName>>("inelastic_models").size()),
//     _inelastic_weights(isParamValid("combined_inelastic_strain_weights")
//                            ? getParam<std::vector<Real>>("combined_inelastic_strain_weights")
//                            : std::vector<Real>(_num_models, 1.0)),
//     _cycle_models(getParam<bool>("cycle_models")),
//     _material_timestep_limit(declareProperty<Real>(prependBaseName("material_timestep_limit"))),
//     _max_iterations(parameters.get<unsigned int>("max_iterations")),
//     _relative_tolerance(parameters.get<Real>("relative_tolerance")),
//     _absolute_tolerance(parameters.get<Real>("absolute_tolerance")),
//     _internal_solve_full_iteration_history(getParam<bool>("internal_solve_full_iteration_history"))
// {
//   if (getParam<bool>("use_displaced_mesh"))
//     mooseError("应力计算器需要在未变形网格上运行。");
    
//   if (_inelastic_weights.size() != _num_models)
//     paramError("combined_inelastic_strain_weights",
//                "必须包含与inelastic_models相同数量的条目 ",
//                _inelastic_weights.size(),
//                " vs. ",
//                _num_models);
// }

// void
// ComputeSmallDeformationStressAll::initialSetup()
// {
//   // 获取弹性模型（必须有）
//   _elasticity_model = dynamic_cast<SmallDeformationElasticityModel *>(&getMaterial("elasticity_model"));
//   if (!_elasticity_model)
//     paramError("elasticity_model",
//                "弹性模型 " + getParam<MaterialName>("elasticity_model") +
//                    " 与 ComputeSmallDeformationStressAll 不兼容");

//   // 获取非弹性模型列表
//   std::vector<MaterialName> models = getParam<std::vector<MaterialName>>("inelastic_models");
//   for (unsigned int i = 0; i < _num_models; ++i)
//   {
//     ADStressUpdateBase * model = dynamic_cast<ADStressUpdateBase *>(&getMaterialByName(models[i]));
//     if (model)
//       _inelastic_models.push_back(model);
//     else
//       paramError("inelastic_models",
//                  "模型 " + models[i] + " 与 ComputeSmallDeformationStressAll 不兼容");
//   }
// }

// void
// ComputeSmallDeformationStressAll::initQpStatefulProperties()
// {
//   _stress[_qp].zero();
//   _inelastic_strain[_qp].zero();
// }

// ADRankTwoTensor
// ComputeSmallDeformationStressAll::convertToAD(const RankTwoTensor & tensor)
// {
//   ADRankTwoTensor result;
//   for (unsigned int i = 0; i < 3; ++i)
//     for (unsigned int j = 0; j < 3; ++j)
//       result(i, j) = tensor(i, j);
//   return result;
// }

// void
// ComputeSmallDeformationStressAll::computeQpProperties()
// {
//   // 设置_qp
//   _elasticity_model->setQp(_qp);
  
//   if (_num_models == 0)
//   {
//     // 没有非弹性模型，直接计算弹性应力
//     ADRankTwoTensor elastic_strain = _mechanical_strain[_qp];
//     _elasticity_model->updateState(elastic_strain, _stress[_qp]);
//   }
//   else 
//   {
//     // 有非弹性模型，需要更新状态
//     ADRankTwoTensor elastic_strain_increment;
//     ADRankTwoTensor combined_inelastic_strain_increment;
    
//     if (_num_models == 1 || _cycle_models)
//       updateQpStateSingleModel((_t_step - 1) % _num_models, 
//                                elastic_strain_increment,
//                                combined_inelastic_strain_increment);
//     else
//       updateQpState(elastic_strain_increment, combined_inelastic_strain_increment);
      
//     // 更新弹性应变和非弹性应变
//     ADRankTwoTensor elastic_strain = _mechanical_strain[_qp] - _inelastic_strain_old[_qp] + elastic_strain_increment;
//     _inelastic_strain[_qp] = _inelastic_strain_old[_qp] + combined_inelastic_strain_increment;
    
//     // 最终更新应力
//     _elasticity_model->updateState(elastic_strain, _stress[_qp]);
//   }
// }

// void 
// ComputeSmallDeformationStressAll::updateQpState(
//     ADRankTwoTensor & elastic_strain_increment,
//     ADRankTwoTensor & combined_inelastic_strain_increment)
// {
//   if (_internal_solve_full_iteration_history == true)
//   {
//     _console << std::endl
//              << "iteration output for ComputeSmallDeformationStressAll solve:"
//              << " time=" << _t << " int_pt=" << _qp << std::endl;
//   }
  
//   Real l2norm_delta_stress;
//   Real first_l2norm_delta_stress = 1.0;
//   unsigned int counter = 0;
  
//   std::vector<ADRankTwoTensor> inelastic_strain_increment;
//   inelastic_strain_increment.resize(_num_models);
  
//   for (unsigned i_rmm = 0; i_rmm < _inelastic_models.size(); ++i_rmm)
//     inelastic_strain_increment[i_rmm].zero();
    
//   ADRankTwoTensor stress_max, stress_min;
  
//   // 初始机械应变增量
//   elastic_strain_increment = _mechanical_strain[_qp] - _inelastic_strain_old[_qp] - 
//                              (_mechanical_strain_old[_qp] - _inelastic_strain_old[_qp]);
  
//   // 当前应力状态
//   _elasticity_model->updateState(_mechanical_strain[_qp] - _inelastic_strain_old[_qp], _stress[_qp]);
//   ADRankTwoTensor current_stress = _stress[_qp];
  
//   do
//   {
//     for (unsigned i_rmm = 0; i_rmm < _num_models; ++i_rmm)
//     {
//       _inelastic_models[i_rmm]->setQp(_qp);
      
//       // 初始假设应变完全是弹性的
//       elastic_strain_increment = _mechanical_strain[_qp] - _inelastic_strain_old[_qp] - 
//                                  (_mechanical_strain_old[_qp] - _inelastic_strain_old[_qp]);
                                 
//       // 减去已经计算的其他非弹性应变增量
//       for (unsigned j_rmm = 0; j_rmm < _num_models; ++j_rmm)
//         if (i_rmm != j_rmm)
//           elastic_strain_increment -= inelastic_strain_increment[j_rmm];
          
//       // 计算试验应力
//       _elasticity_model->updateState(_mechanical_strain_old[_qp] - _inelastic_strain_old[_qp] + elastic_strain_increment, 
//                                     _stress[_qp]);
                                    
//       // 计算可接受状态
//       computeAdmissibleState(i_rmm, elastic_strain_increment, inelastic_strain_increment[i_rmm]);
      
//       if (i_rmm == 0)
//       {
//         stress_max = _stress[_qp];
//         stress_min = _stress[_qp];
//       }
//       else
//       {
//         for (unsigned int i = 0; i < 3; ++i)
//           for (unsigned int j = 0; j < 3; ++j)
//             if (_stress[_qp](i, j) > stress_max(i, j))
//               stress_max(i, j) = _stress[_qp](i, j);
//             else if (stress_min(i, j) > _stress[_qp](i, j))
//               stress_min(i, j) = _stress[_qp](i, j);
//       }
//     }
    
//     // 检查应力收敛性
//     l2norm_delta_stress = MetaPhysicL::raw_value((stress_max - stress_min).L2norm());
//     if (counter == 0 && l2norm_delta_stress > 0.0)
//       first_l2norm_delta_stress = l2norm_delta_stress;
      
//     if (_internal_solve_full_iteration_history == true)
//     {
//       _console << "stress iteration number = " << counter << "\n"
//                << " relative l2 norm delta stress = "
//                << (0 == first_l2norm_delta_stress ? 0
//                                                   : l2norm_delta_stress / first_l2norm_delta_stress)
//                << "\n"
//                << " stress convergence relative tolerance = " << _relative_tolerance << "\n"
//                << " absolute l2 norm delta stress = " << l2norm_delta_stress << "\n"
//                << " stress convergence absolute tolerance = " << _absolute_tolerance << std::endl;
//     }
    
//     ++counter;
    
//   } while (counter < _max_iterations && l2norm_delta_stress > _absolute_tolerance &&
//            (l2norm_delta_stress / first_l2norm_delta_stress) > _relative_tolerance &&
//            _num_models != 1);
           
//   if (counter == _max_iterations && l2norm_delta_stress > _absolute_tolerance &&
//       (l2norm_delta_stress / first_l2norm_delta_stress) > _relative_tolerance)
//     mooseException("在 ", _name, ": 应力迭代达到最大次数但未收敛!");
    
//   combined_inelastic_strain_increment.zero();
//   for (unsigned i_rmm = 0; i_rmm < _num_models; ++i_rmm)
//     combined_inelastic_strain_increment += _inelastic_weights[i_rmm] * inelastic_strain_increment[i_rmm];
    
//   _material_timestep_limit[_qp] = 0.0;
//   for (unsigned i_rmm = 0; i_rmm < _num_models; ++i_rmm)
//     _material_timestep_limit[_qp] += 1.0 / _inelastic_models[i_rmm]->computeTimeStepLimit();
    
//   if (MooseUtils::absoluteFuzzyEqual(_material_timestep_limit[_qp], 0.0))
//     _material_timestep_limit[_qp] = std::numeric_limits<Real>::max();
//   else
//     _material_timestep_limit[_qp] = 1.0 / _material_timestep_limit[_qp];
// }

// void
// ComputeSmallDeformationStressAll::updateQpStateSingleModel(
//     unsigned model_number,
//     ADRankTwoTensor & elastic_strain_increment,
//     ADRankTwoTensor & combined_inelastic_strain_increment)
// {
//   for (auto model : _inelastic_models)
//     model->setQp(_qp);
    
//   // 初始机械应变增量
//   elastic_strain_increment = _mechanical_strain[_qp] - _inelastic_strain_old[_qp] - 
//                             (_mechanical_strain_old[_qp] - _inelastic_strain_old[_qp]);
  
//   // 计算试验应力
//   _elasticity_model->updateState(_mechanical_strain_old[_qp] - _inelastic_strain_old[_qp] + elastic_strain_increment, 
//                                 _stress[_qp]);
  
//   // 计算可接受状态
//   computeAdmissibleState(model_number, elastic_strain_increment, combined_inelastic_strain_increment);
  
//   _material_timestep_limit[_qp] = _inelastic_models[0]->computeTimeStepLimit();
  
//   // 传播内部变量到当前时间步
//   for (unsigned i_rmm = 0; i_rmm < _num_models; ++i_rmm)
//     if (i_rmm != model_number)
//       _inelastic_models[i_rmm]->propagateQpStatefulProperties();
// }

// void
// ComputeSmallDeformationStressAll::computeAdmissibleState(
//     unsigned model_number,
//     ADRankTwoTensor & elastic_strain_increment,
//     ADRankTwoTensor & inelastic_strain_increment)
// {
//   // 更新材料属性
//   _inelastic_models[model_number]->resetIncrementalMaterialProperties();
  
//   // 调用非弹性模型更新状态
//   if (_inelastic_models[model_number]->substeppingCapabilityEnabled())
//   {
//     _inelastic_models[model_number]->updateStateSubstep(elastic_strain_increment,
//                                                       inelastic_strain_increment,
//                                                       ADRankTwoTensor::Identity(), // 小变形假设下为单位张量
//                                                       _stress[_qp],
//                                                       _stress_old[_qp],  // 直接使用非AD类型
//                                                       _elasticity_tensor[_qp],
//                                                       _mechanical_strain_old[_qp] - _inelastic_strain_old[_qp]);
//   }
//   else
//   {
//     _inelastic_models[model_number]->updateState(elastic_strain_increment,
//                                                inelastic_strain_increment,
//                                                ADRankTwoTensor::Identity(), // 小变形假设下为单位张量
//                                                _stress[_qp],
//                                                _stress_old[_qp],  // 直接使用非AD类型
//                                                _elasticity_tensor[_qp],
//                                                _mechanical_strain_old[_qp] - _inelastic_strain_old[_qp]);
//   }
// }