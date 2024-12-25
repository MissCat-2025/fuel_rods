#include "ADComputeVariableFunctionEigenstrain.h"

registerMooseObject("FuelRodsApp", ADComputeVariableFunctionEigenstrain);

InputParameters
ADComputeVariableFunctionEigenstrain::validParams()
{
  InputParameters params = ADComputeEigenstrainBase::validParams();
  params.addClassDescription("计算一个本征应变,该本征应变是由基础张量和总应变函数的增量决定");
  params.addRequiredParam<MaterialPropertyName>("prefactor", "总应变函数（预因子）材料属性名称");
  params.addRequiredParam<std::vector<Real>>("eigen_base", "本征应变基础张量的分量");
  return params;
}

ADComputeVariableFunctionEigenstrain::ADComputeVariableFunctionEigenstrain(const InputParameters & parameters)
  : ADComputeEigenstrainBase(parameters),
    _prefactor(getADMaterialProperty<Real>("prefactor")),
    _prefactor_old(getMaterialPropertyOld<Real>("prefactor")),
        // 使用eigenstrain_name来获取上一时间步的本征应变
    _eigenstrain_old(getMaterialPropertyOld<RankTwoTensor>(_eigenstrain_name))
{
  const std::vector<Real> & eigen_base = getParam<std::vector<Real>>("eigen_base");
  if (eigen_base.size() != 6)
    paramError("eigen_base", "本征应变基础张量必须有6个分量");

  _eigen_base_tensor.fillFromInputVector(eigen_base);
}

void
ADComputeVariableFunctionEigenstrain::initQpStatefulProperties()
{
  // 初始化本征应变为零
  _eigenstrain[_qp].zero();
}

void
ADComputeVariableFunctionEigenstrain::computeQpEigenstrain()
{
  // 计算应变增量
  const ADReal strain_increment = _prefactor[_qp] - _prefactor_old[_qp];
  
  // 累加应变增量
  _eigenstrain[_qp] = _eigenstrain_old[_qp] + _eigen_base_tensor * strain_increment;
}