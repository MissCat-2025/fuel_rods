#include "SmallDeformationHBasedElasticityCopy.h"
#include "RankTwoScalarTools.h"
#include "RaccoonUtils.h"

registerMooseObject("FuelRodsApp", SmallDeformationHBasedElasticityCopy);

InputParameters
SmallDeformationHBasedElasticityCopy::validParams()
{
  InputParameters params = SmallDeformationElasticityModel::validParams();
  params.addClassDescription("H-based elasticity model with integrated history variable tracking");

  params.addRequiredParam<MaterialPropertyName>("youngs_modulus", "Young's modulus $E_0$");
  params.addRequiredParam<MaterialPropertyName>("poissons_ratio", "Poisson's ratio $\\nu$");
  params.addRequiredParam<MaterialPropertyName>("tensile_strength", "Tensile strength $f_t$");
  params.addRequiredParam<MaterialPropertyName>("fracture_energy", "Fracture energy $G_f$");
  params.addRequiredCoupledVar("phase_field", "Name of the phase-field (damage) variable");
  params.addParam<MaterialPropertyName>(
      "strain_energy_density",
      "psie",
      "Name of the strain energy density computed by this material model");
  params.addParam<MaterialPropertyName>("degradation_function", "g", "The degradation function");

  return params;
}

SmallDeformationHBasedElasticityCopy::SmallDeformationHBasedElasticityCopy(const InputParameters & parameters)
  : SmallDeformationElasticityModel(parameters),
    DerivativeMaterialPropertyNameInterface(),
    _E0(getADMaterialProperty<Real>("youngs_modulus")),
    _nu(getADMaterialProperty<Real>("poissons_ratio")),
    _ft(getADMaterialProperty<Real>("tensile_strength")),
    _Gf(getADMaterialProperty<Real>("fracture_energy")),
    _d_name(getVar("phase_field", 0)->name()),
    _psie_name(prependBaseName("strain_energy_density", true)),
    _psie(declareADProperty<Real>(_psie_name)),
    _psie_active(declareADProperty<Real>(_psie_name + "_active")),
    _dpsie_dd(declareADProperty<Real>(derivativePropertyName(_psie_name,{_d_name}))),
    _g_name(prependBaseName("degradation_function", true)),
    _g(getADMaterialProperty<Real>(_g_name)),
    _dg_dd(getADMaterialProperty<Real>(derivativePropertyName(_g_name, {_d_name}))),
    _H(declareADProperty<Real>("history_variable_H")),
    _H_old(getMaterialPropertyOld<Real>("history_variable_H"))
{
}

void
SmallDeformationHBasedElasticityCopy::initialSetup()
{
  if (!isParamValid("youngs_modulus"))
    mooseError("Young's modulus must be provided");
}

// 新函数：计算张量的最大主值以及对应的方向
static ADReal myMaxPrincipal(const ADRankTwoTensor & tensor, libMesh::Point & direction)
{
  // 假定三维空间 LIBMESH_DIM == 3
  std::vector<ADReal> eigenvals(LIBMESH_DIM);
  ADRankTwoTensor eigvecs;
  // 计算对称张量的特征值和特征向量
  tensor.symmetricEigenvaluesEigenvectors(eigenvals, eigvecs);
  
  // 找出最大特征值和对应的索引
  unsigned int max_idx = 0;
  for (unsigned int i = 1; i < LIBMESH_DIM; i++)
  {
    if (eigenvals[i] > eigenvals[max_idx])
      max_idx = i;
  }
  ADReal max_val = eigenvals[max_idx];

  // 将计算得到的特征向量赋值到 direction 中
  // 使用.value()提取ADReal的数值部分
  for (unsigned int i = 0; i < LIBMESH_DIM; i++)
  {
    direction(i) = MetaPhysicL::raw_value(eigvecs.column(max_idx)(i));
  }
  // 如果是低维问题，确保未使用的维度设为0
  for (unsigned int i = LIBMESH_DIM; i < 3; i++)
  {
    direction(i) = 0.0;
  }

  return max_val;
}

ADRankTwoTensor
SmallDeformationHBasedElasticityCopy::computeStress(const ADRankTwoTensor & strain)
{
  const ADReal K = _E0[_qp] / (3.0 * (1.0 - 2.0 * _nu[_qp]));
  const ADReal G = _E0[_qp] / (2.0 * (1.0 + _nu[_qp]));

  const ADRankTwoTensor I2(ADRankTwoTensor::initIdentity);
  ADRankTwoTensor stress_intact = K * strain.trace() * I2 + 2 * G * strain.deviatoric();
  ADRankTwoTensor stress = _g[_qp] * stress_intact;

  // 使用自定义函数计算最大主应力及其方向
  libMesh::Point principal_direction; // 计算后得到的特征向量
  ADReal sigma_bar_eq = myMaxPrincipal(stress_intact, principal_direction);
  sigma_bar_eq = RaccoonUtils::Macaulay(sigma_bar_eq);

  const ADReal Y0 = 0.5 * _ft[_qp] * _ft[_qp] / _E0[_qp];
  const ADReal Y_bar = 0.5 * sigma_bar_eq * sigma_bar_eq / _E0[_qp];
  _H[_qp] = std::max(Y0, std::max(_H_old[_qp], Y_bar));

  _psie_active[_qp] = _H[_qp];
  _psie[_qp] = _g[_qp] * _psie_active[_qp];
  _dpsie_dd[_qp] = _dg_dd[_qp] * _psie_active[_qp];
  // 当_qp为0时，输出_dpsie_dd[_qp]
  // if (_qp == 0)
  // {
  //   Moose::out << "\n=== 损伤演化导数: "
  //              << "\n_dpsie_dd: " << MetaPhysicL::raw_value(_dpsie_dd[_qp]) << "\n"
  //              << "\n_dg_dd: " << MetaPhysicL::raw_value(_dg_dd[_qp]) << "\n"
  //              << "\n================================";
  // }

  return stress;
}