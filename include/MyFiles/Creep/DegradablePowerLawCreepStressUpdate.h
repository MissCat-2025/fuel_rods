// //* This file is part of the RACCOON application
// //* being developed at Dolbow lab at Duke University
// //* http://dolbow.pratt.duke.edu

// #pragma once

// #include "ADPowerLawCreepStressUpdate.h"

// /**
//  * 这个类扩展了PowerLawCreepStressUpdate，将相场退化函数整合到蠕变计算中
//  */
// class DegradablePowerLawCreepStressUpdate : public ADPowerLawCreepStressUpdate
// {
// public:
//   static InputParameters validParams();

//   DegradablePowerLawCreepStressUpdate(const InputParameters & parameters);

//   virtual Real computeStrainEnergyRateDensity(
//       const ADMaterialProperty<RankTwoTensor> & stress,
//       const ADMaterialProperty<RankTwoTensor> & strain_rate) override;

// protected:
//   virtual ADReal computeResidual(const ADReal & effective_trial_stress,
//                                const ADReal & scalar) override;

//   virtual ADReal computeDerivative(const ADReal & effective_trial_stress,
//                                  const ADReal & scalar) override;

//   /// 退化函数材料属性
//   const ADMaterialProperty<Real> & _g;
  
//   /// 是否对应力应用退化
//   const bool _use_stress_degradation;
// };