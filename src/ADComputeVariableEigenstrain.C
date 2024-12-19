#include "ADComputeVariableEigenstrain.h"

registerMooseObject("FuelRodsApp", ADComputeVariableEigenstrain);

InputParameters
ADComputeVariableEigenstrain::validParams()
{
  InputParameters params = ADComputeEigenstrainBase::validParams();
  params.addClassDescription("计算一个本征应变,该本征应变是由基础张量和在AD材料中定义的标量函数的函数");
  params.addRequiredParam<MaterialPropertyName>("prefactor", "预因子材料属性名称");
  params.addRequiredParam<std::vector<Real>>("eigen_base", "本征应变基础张量的分量");
  return params;
}

ADComputeVariableEigenstrain::ADComputeVariableEigenstrain(const InputParameters & parameters)
  : ADComputeEigenstrainBase(parameters),
    _prefactor(getADMaterialProperty<Real>("prefactor"))
{
  // 从输入参数获取本征应变基础张量的分量
  const std::vector<Real> & eigen_base = getParam<std::vector<Real>>("eigen_base");
  if (eigen_base.size() != 6)
    paramError("eigen_base", "本征应变基础张量必须有6个分量");

  // 填充本征应变基础张量
  _eigen_base_tensor.fillFromInputVector(eigen_base);
}

void
ADComputeVariableEigenstrain::computeQpEigenstrain()
{
  _eigenstrain[_qp] = _eigen_base_tensor * _prefactor[_qp];
}