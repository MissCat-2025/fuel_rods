# 陶瓷片热冲击实验 - 热弹性模拟（Physics 平面应变写法）
# 用法示例：
#   conda activate moose
# conda activate moose &&dos2unix GPlaneStrainPressure.i&& mpirun -n 8 /home/yp/projects/fuel_rods/fuel_rods-opt -i GPlaneStrainPressure.i

[GlobalParams]
  displacements = 'disp_x disp_y'
[]

# 陶瓷材料参数
E_ceramic = 370e9
nu_ceramic = 0.3
alpha_ceramic = 7.5e-6
k_ceramic = 310
cp_ceramic = 8800
rho_ceramic = 3980

[Mesh]
  [gmg]
    type = GeneratedMeshGenerator
    dim = 2
    nx = 50
    ny = 10
    xmax = 25e-3
    ymax = 5e-3
  []
      [center_point]
    type = ExtraNodesetGenerator
    input = gmg
    coord = '0 0 0'
    new_boundary  = 'center_point'
  []
[]

[Variables]
  [disp_x]
  []
  [disp_y]
  []
  [temp]
    initial_condition = 293.15
  []
  [scalar_strain_zz]
    family = SCALAR
    order = FIRST
  []
[]

[AuxVariables]
  [MaxPrincipal]
    order = CONSTANT
    family = MONOMIAL
  []
[]
[Physics/SolidMechanics/QuasiStatic]
  [all]
    strain = SMALL
    scalar_out_of_plane_strain = scalar_strain_zz
    # use_displaced_mesh = true
    eigenstrain_names = 'thermal_eigenstrain'
    planar_formulation = GENERALIZED_PLANE_STRAIN
    # use_automatic_differentiation = false
    temperature = temp
    out_of_plane_pressure_function = traction_function
    pressure_factor = 1e6
  []
[]

[Kernels]
  [heat_conduction]
    type = ADHeatConduction
    variable = temp
  []
  [heat_dt]
    type = ADHeatConductionTimeDerivative
    variable = temp
  []
[]

[BCs]
  # 力学边界条件
  [symm_x]
    type = DirichletBC
    variable = disp_x
    boundary = center_point
    value = 0
  []
  [symm_y]
    type = DirichletBC
    variable = disp_y
    boundary = center_point
    value = 0
  []

  # 热边界条件
  [left_temp]
    type = ADDirichletBC
    variable = temp
    boundary = 'left'
    value = 293.15
  []
  [right_temp]
    type = ADDirichletBC
    variable = temp
    boundary = 'right'
    value = 1293.15
  []
[]

[Materials]
  [thermal]
    type = ADGenericConstantMaterial
    prop_names = 'thermal_conductivity specific_heat density'
    prop_values = '${k_ceramic} ${cp_ceramic} ${rho_ceramic}'
  []

  [elastic_tensor]
    type = ComputeIsotropicElasticityTensor
    poissons_ratio = ${nu_ceramic}
    youngs_modulus = ${E_ceramic}
  []

  [eigenstrain]
    type = ComputeThermalExpansionEigenstrain
    eigenstrain_name = thermal_eigenstrain
    stress_free_temperature = 293.15
    thermal_expansion_coeff = ${alpha_ceramic}
    temperature = temp
  []
  # [./strain]
  #   type = ComputePlaneSmallStrain
  #   displacements = 'disp_x disp_y'
  #   scalar_out_of_plane_strain = scalar_strain_zz
  # [../]
  [stress]
    type = ComputeLinearElasticStress
  []
[]

[AuxKernels]
  [MaxPrincipalStress]
    type = RankTwoScalarAux
    variable = MaxPrincipal
    rank_two_tensor = stress
    scalar_type = MaxPrincipal
    execute_on = 'TIMESTEP_END'
  []
[]
[Postprocessors]
  [avg_temp]
    type = ElementAverageValue
    variable = temp
  []
  [max_MaxPrincipal]
    type = ElementExtremeValue
    variable = MaxPrincipal
    value_type = max
  []
[]
[Functions]
  [./traction_function]
    type = PiecewiseLinear
    x = '0  1'
    y = '1  1'
  [../]
[]
[Executioner]
  type = Transient

  solve_type = PJFNK
  line_search = BT

# controls for linear iterations
  l_max_its = 300
  l_tol = 1e-10

# controls for nonlinear iterations
  nl_max_its = 20
  nl_rel_tol = 1e-10
  nl_abs_tol = 1e-9

# time control
  start_time = 0.0
  dt = 0.1
  end_time = 1
[]

[Outputs]
  exodus = true
  print_linear_residuals = false
    [csv]
    type = CSV
    file_base = 'GPlaneStrainPressure'
  []
[]
