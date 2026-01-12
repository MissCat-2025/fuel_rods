# conda activate moose && dos2unix PlaneStressCeramic_physics.i && mpirun -n 8 /home/yp/projects/fuel_rods/fuel_rods-opt -i PlaneStressCeramic_physics.i
#Physics写法
[GlobalParams]
  displacements = 'disp_x disp_y'
  out_of_plane_strain = strain_zz
[]

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
  [strain_zz]
  []
[]

[Physics]
  [SolidMechanics]
    [QuasiStatic]
      [plane_stress]
        planar_formulation = WEAK_PLANE_STRESS
        strain = SMALL
        eigenstrain_names = eigenstrain
        use_automatic_differentiation = true
      []
    []
  []
[]
[AuxVariables]
  [MaxPrincipal]
    order = CONSTANT
    family = MONOMIAL
  []
[]
[AuxKernels]
  [MaxPrincipalStress]
    type = ADRankTwoScalarAux
    variable = MaxPrincipal
    rank_two_tensor = stress
    scalar_type = MaxPrincipal
    execute_on = 'TIMESTEP_END'
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
  [symm_x]
    type = ADDirichletBC
    variable = disp_x
    boundary = center_point
    value = 0
  []
  [symm_y]
    type = ADDirichletBC
    variable = disp_y
    boundary = center_point
    value = 0
  []
  [left_temp]
    type = ADDirichletBC
    variable = temp
    boundary = left
    value = 293.15
  []
  [right_temp]
    type = ADDirichletBC
    variable = temp
    boundary = right
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
    type = ADComputeIsotropicElasticityTensor
    poissons_ratio = ${nu_ceramic}
    youngs_modulus = ${E_ceramic}
  []

  [eigenstrain]
    type = ADComputeThermalExpansionEigenstrain
    eigenstrain_name = eigenstrain
    stress_free_temperature = 293.15
    thermal_expansion_coeff = ${alpha_ceramic}
    temperature = temp
  []
  [stress]
    type = ADComputeLinearElasticStress
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
    file_base = 'PlaneStressCeramic_physics_post'
  []
[]
