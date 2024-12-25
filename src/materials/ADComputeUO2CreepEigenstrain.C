// src/materials/ADComputeUO2CreepEigenstrain.C
#include "ADComputeUO2CreepEigenstrain.h"

registerADMooseObject("FuelRodsApp", ADComputeUO2CreepEigenstrain);

InputParameters
ADComputeUO2CreepEigenstrain::validParams()
{
  InputParameters params = ADComputeEigenstrainBase::validParams();
  params.addClassDescription("计算UO2的蠕变特征应变");
  return params;
}

ADComputeUO2CreepEigenstrain::ADComputeUO2CreepEigenstrain(const InputParameters & parameters)
  : ADComputeEigenstrainBase(parameters),
    _creep_rate(getADMaterialProperty<RankTwoTensor>("creep_rate")),
    _creep_strain(declareADProperty<RankTwoTensor>(_base_name + "creep_strain")),
    _creep_strain_old(getMaterialPropertyOld<RankTwoTensor>(_base_name + "creep_strain"))
{
}

void
ADComputeUO2CreepEigenstrain::computeQpEigenstrain()
{
  // 更新累积蠕变应变
  _creep_strain[_qp] = _creep_strain_old[_qp] + _creep_rate[_qp] * _dt;
  
  // 设置特征应变
  _eigenstrain[_qp] = _creep_strain[_qp];
}