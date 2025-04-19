// // src/materials/ADComputeUO2CreepEigenstrain.C
// #include "ADComputeUO2CreepEigenstrain.h"

// registerADMooseObject("FuelRodsApp", ADComputeUO2CreepEigenstrain);

// InputParameters
// ADComputeUO2CreepEigenstrain::validParams()
// {
//   InputParameters params = ADComputeEigenstrainBase::validParams();
//     // 添加这一行来声明vonMisesStress参数
//   params.addClassDescription("计算UO2的蠕变特征应变");
//   return params;
// }

// ADComputeUO2CreepEigenstrain::ADComputeUO2CreepEigenstrain(const InputParameters & parameters)
//   : ADComputeEigenstrainBase(parameters),
//     _creep_rate(getADMaterialProperty<RankTwoTensor>("creep_rate")),
//     _creep_strain(declareADProperty<RankTwoTensor>(_base_name + "creep_strain")),
//     _creep_strain_old(getMaterialPropertyOld<RankTwoTensor>(_base_name + "creep_strain")),
//     _psip_active(declareADProperty<Real>("psip_active")),
//     _stress_deviator(getADMaterialProperty<RankTwoTensor>("stress_deviator"))
// {
// }

// void
// ADComputeUO2CreepEigenstrain::initQpStatefulProperties()
// {
//   _creep_strain[_qp].zero();
//   _eigenstrain[_qp].zero();
// }

// void
// ADComputeUO2CreepEigenstrain::computeQpEigenstrain()
// {
//   // 更新累积蠕变应变
//   _creep_strain[_qp] = _creep_strain_old[_qp] + _creep_rate[_qp] * _dt;
  
//   // 设置特征应变
//   _eigenstrain[_qp] = _creep_strain[_qp];
  
//   // 计算塑性功率 = 偏应力张量:蠕变率张量
//   _psip_active[_qp] = _creep_strain[_qp].doubleContraction(_stress_deviator[_qp]);
// }