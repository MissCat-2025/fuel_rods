// SmallDeformationIsotropicElasticityThreshold.C 修正版
#include "SmallDeformationIsotropicElasticityThreshold.h"
#include "RaccoonUtils.h"

registerMooseObject("FuelRodsApp", SmallDeformationIsotropicElasticityThreshold);

InputParameters
SmallDeformationIsotropicElasticityThreshold::validParams()
{
  InputParameters params = SmallDeformationElasticityModel::validParams();
  params.addClassDescription("Isotropic elasticity with threshold energy option using E and nu as inputs.");
  
  params.addRequiredParam<MaterialPropertyName>("youngs_modulus", "Young's modulus E");
  params.addRequiredParam<MaterialPropertyName>("poissons_ratio", "Poisson's ratio nu");
  
  params.addRequiredCoupledVar("phase_field", "Name of the phase-field (damage) variable");
  params.addParam<MaterialPropertyName>(
      "strain_energy_density",
      "psie",
      "Name of the strain energy density computed by this material model");
  params.addParam<MaterialPropertyName>("degradation_function", "g", "The degradation function");
  
  MooseEnum decomp_options("NONE SPECTRAL VOLDEV", "NONE");
  params.addParam<MooseEnum>("decomposition", decomp_options, "The decomposition method");
  
  params.addParam<bool>("use_threshold", false, "Whether to use threshold energy");
  params.addParam<MaterialPropertyName>("tensile_strength", "sigma0", "Critical stress for threshold");
  
  return params;
}

SmallDeformationIsotropicElasticityThreshold::SmallDeformationIsotropicElasticityThreshold(
    const InputParameters & parameters)
  : SmallDeformationElasticityModel(parameters),
    DerivativeMaterialPropertyNameInterface(),
    _youngs_modulus(getADMaterialProperty<Real>(getParam<MaterialPropertyName>("youngs_modulus"))),
    _poissons_ratio(getADMaterialProperty<Real>(getParam<MaterialPropertyName>("poissons_ratio"))),
    
    _d_name(getVar("phase_field", 0)->name()),
    
    // 修复参数获取 - 使用正确的参数名
    _psie_name(getParam<MaterialPropertyName>("strain_energy_density")),
    _psie(declareADProperty<Real>(_psie_name)),
    _psie_active(declareADProperty<Real>(_psie_name + "_active")),
    _dpsie_dd(declareADProperty<Real>(derivativePropertyName(_psie_name, {_d_name}))),
    
    // 修复参数获取 - 使用正确的参数名
    _g_name(getParam<MaterialPropertyName>("degradation_function")),
    _g(getADMaterialProperty<Real>(_g_name)),
    _dg_dd(getADMaterialProperty<Real>(derivativePropertyName(_g_name, {_d_name}))),
    
    _use_threshold(getParam<bool>("use_threshold")),
    _sigma_c(_use_threshold ? getADMaterialProperty<Real>(getParam<MaterialPropertyName>("tensile_strength")) 
                            : declareADProperty<Real>("dummy_sigma_c")),
    
    _decomposition(getParam<MooseEnum>("decomposition").getEnum<Decomposition>())
{
}

ADReal
SmallDeformationIsotropicElasticityThreshold::applyThreshold(ADReal psie_active_raw)
{
  if (_use_threshold)
  {
    ADReal threshold = 0.5 * _sigma_c[_qp] * _sigma_c[_qp] / _youngs_modulus[_qp];
    return std::max(psie_active_raw, threshold);
  }
  else
  {
    return psie_active_raw;
  }
}

ADRankTwoTensor
SmallDeformationIsotropicElasticityThreshold::computeStress(const ADRankTwoTensor & strain)
{
  switch (_decomposition)
  {
    case Decomposition::none:
      return computeStressNoDecomposition(strain);
    case Decomposition::spectral:
      return computeStressSpectralDecomposition(strain);
    case Decomposition::voldev:
      return computeStressVolDevDecomposition(strain);
    default:
      mooseError("Unknown decomposition type in SmallDeformationIsotropicElasticityThreshold");
  }
  return ADRankTwoTensor(); // 不会执行到这里
}

ADRankTwoTensor
SmallDeformationIsotropicElasticityThreshold::computeStressNoDecomposition(const ADRankTwoTensor & strain)
{
  // 计算拉梅常数
  const ADReal nu = _poissons_ratio[_qp];
  const ADReal E = _youngs_modulus[_qp];
  const ADReal K = E  / (3.0 *  (1.0 - 2.0 * nu));
  const ADReal G = E / (2.0 * (1.0 + nu));
  
  const ADRankTwoTensor I2(ADRankTwoTensor::initIdentity);
  ADRankTwoTensor stress_intact = K * strain.trace() * I2 + 2.0 * G * strain.deviatoric();
  ADRankTwoTensor stress = _g[_qp] * stress_intact;

  _psie_active[_qp] = 0.5 * stress_intact.doubleContraction(strain);
  
  // 应用阈值
  _psie_active[_qp] = applyThreshold(_psie_active[_qp]);
  
  _psie[_qp] = _g[_qp] * _psie_active[_qp];
  _dpsie_dd[_qp] = _dg_dd[_qp] * _psie_active[_qp];

  return stress;
}

ADRankTwoTensor
SmallDeformationIsotropicElasticityThreshold::computeStressSpectralDecomposition(const ADRankTwoTensor & strain)
{
  // 计算拉梅常数
  const ADReal nu = _poissons_ratio[_qp];
  const ADReal E = _youngs_modulus[_qp];
  const ADReal K = E  / (3.0 *  (1.0 - 2.0 * nu));
  const ADReal G = E / (2.0 * (1.0 + nu));
  const ADReal lambda = K - 2 * G / LIBMESH_DIM;
  
  const ADRankTwoTensor I2(ADRankTwoTensor::initIdentity);
  ADReal strain_tr = strain.trace();
  ADReal strain_tr_pos = RaccoonUtils::Macaulay(strain_tr);

  // 谱分解
  ADRankTwoTensor strain_pos = RaccoonUtils::spectralDecomposition(strain);

  // 应力计算
  ADRankTwoTensor stress_intact = K * strain.trace() * I2 + 2.0 * G * strain.deviatoric();
  ADRankTwoTensor stress_pos = lambda * strain_tr_pos * I2 + 2.0 * G * strain_pos;
  ADRankTwoTensor stress_neg = stress_intact - stress_pos;
  ADRankTwoTensor stress = _g[_qp] * stress_pos + stress_neg;

  // 能量密度计算
  ADReal psie_intact = 0.5 * lambda * strain_tr * strain_tr + G * strain.doubleContraction(strain);
  ADReal psie_active_raw = 0.5 * lambda * strain_tr_pos * strain_tr_pos +
                          G * strain_pos.doubleContraction(strain_pos);
  
  // 应用阈值
  _psie_active[_qp] = applyThreshold(psie_active_raw);
  
  ADReal psie_inactive = psie_intact - psie_active_raw;
  _psie[_qp] = _g[_qp] * _psie_active[_qp] + psie_inactive;
  _dpsie_dd[_qp] = _dg_dd[_qp] * _psie_active[_qp];

  return stress;
}

ADRankTwoTensor
SmallDeformationIsotropicElasticityThreshold::computeStressVolDevDecomposition(const ADRankTwoTensor & strain)
{
  // 计算拉梅常数
  const ADReal nu = _poissons_ratio[_qp];
  const ADReal E = _youngs_modulus[_qp];
  const ADReal G = E / (2.0 * (1.0 + nu));
  const ADReal K = E / (3.0 * (1.0 - 2.0 * nu));
  
  const ADRankTwoTensor I2(ADRankTwoTensor::initIdentity);

  // 体积-偏差分解
  ADReal strain_tr = strain.trace();
  ADReal strain_tr_pos = RaccoonUtils::Macaulay(strain_tr);
  ADReal strain_tr_neg = strain_tr - strain_tr_pos;
  ADRankTwoTensor strain_dev = strain.deviatoric();

  // 应力计算
  ADRankTwoTensor stress_intact = K * strain.trace() * I2 + 2.0 * G * strain.deviatoric();
  ADRankTwoTensor stress_neg = K * strain_tr_neg * I2;
  ADRankTwoTensor stress_pos = stress_intact - stress_neg;
  ADRankTwoTensor stress = _g[_qp] * stress_pos + stress_neg;

  // 能量密度计算
  ADReal psie_intact = 0.5 * K * strain_tr * strain_tr + G * strain_dev.doubleContraction(strain_dev);
  ADReal psie_inactive = 0.5 * K * strain_tr_neg * strain_tr_neg;
  ADReal psie_active_raw = psie_intact - psie_inactive;
  
  // 应用阈值
  _psie_active[_qp] = applyThreshold(psie_active_raw);
  
  _psie[_qp] = _g[_qp] * _psie_active[_qp] + psie_inactive;
  _dpsie_dd[_qp] = _dg_dd[_qp] * _psie_active[_qp];

  return stress;
}