#include "SmallDeformationHBasedElasticity.h"
#include "RankTwoScalarTools.h"
#include "RaccoonUtils.h"

registerMooseObject("FuelRodsApp", SmallDeformationHBasedElasticity);

InputParameters
SmallDeformationHBasedElasticity::validParams()
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

SmallDeformationHBasedElasticity::SmallDeformationHBasedElasticity(const InputParameters & parameters)
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

ADRankTwoTensor
SmallDeformationHBasedElasticity::computeStress(const ADRankTwoTensor & strain)
{
  const ADReal K = _E0[_qp] / (3.0 * (1.0 - 2.0 * _nu[_qp]));
  const ADReal G = _E0[_qp] / (2.0 * (1.0 + _nu[_qp]));

  const ADRankTwoTensor I2(ADRankTwoTensor::initIdentity);
  ADRankTwoTensor stress_intact = K * strain.trace() * I2 + 2 * G * strain.deviatoric();
  ADRankTwoTensor stress = _g[_qp] * stress_intact;

  // 使用 symmetricEigenvalues 获取特征值，避免与 Point 不兼容问题
  std::vector<ADReal> eigenvals(LIBMESH_DIM);
  stress_intact.symmetricEigenvalues(eigenvals);

  // 找出最大特征值
  ADReal sigma_bar_eq = eigenvals[0];
  for (unsigned int i = 1; i < LIBMESH_DIM; i++)
    if (eigenvals[i] > sigma_bar_eq)
      sigma_bar_eq = eigenvals[i];
      
  // 应用 Macaulay 括号（只取正部分）
  sigma_bar_eq = RaccoonUtils::Macaulay(sigma_bar_eq);

  const ADReal Y0 = 0.5 * _ft[_qp] * _ft[_qp] / _E0[_qp];
  const ADReal Y_bar = 0.5 * sigma_bar_eq * sigma_bar_eq / _E0[_qp];
  _H[_qp] = std::max(Y0, std::max(_H_old[_qp], Y_bar));

  _psie_active[_qp] = _H[_qp];
  _psie[_qp] = _g[_qp] * _psie_active[_qp];
  _dpsie_dd[_qp] = _dg_dd[_qp] * _psie_active[_qp];

  return stress;
}