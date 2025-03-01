E_glass = 6.4e4
nu_glass = 0.2
alpha_glass = 3.25e-6

E_steel = 1.93e5
nu_steel = 0.29
K_steel = '${fparse E_steel/3/(1-2*nu_steel)}'
G_steel = '${fparse E_steel/2/(1+nu_steel)}'
alpha_steel = 1.73e-5

Gc = 0.4
ft = 80.0
l = 0.5
a1 = '${fparse 4*E_steel*Gc/ft/ft/3.14159/l}'


[MultiApps]
  [fracture]
    type = TransientMultiApp
    input_files = fracture2.i
    cli_args = 'Gc=${Gc};a1=${a1};l=${l}'
    execute_on = 'TIMESTEP_END'
  []
[]

[Transfers]
  [from_d]
    type = MultiAppGeneralFieldShapeEvaluationTransfer
    from_multi_app = 'fracture'
    variable = d
    source_variable = d
  []
  [to_dpsie_dd]
    type = MultiAppGeneralFieldShapeEvaluationTransfer
    to_multi_app = 'fracture'
    variable = dpsie_dd
    source_variable = dpsie/dd
  []
[]

[GlobalParams]
  displacements = 'disp_x disp_y'
[]

[Mesh]
  [fmg]
    type = FileMeshGenerator
    file = 'plate.msh'
  []
[]

[Adaptivity]
  marker = marker
  initial_marker = marker
  initial_steps = 2
  stop_time = 0
  max_h_level = 3
  [Markers]
    [marker]
      type = BoxMarker
      bottom_left = '27 7 0'
      top_right = '70 28 0'
      inside = REFINE
      outside = DO_NOTHING
    []
  []
[]

[Variables]
  [disp_x]
  []
  [disp_y]
  []
[]

[AuxVariables]
  [d]
  []
  [T]
    initial_condition = 1000
  []
[]

[AuxKernels]
  [cooling]
    type = FunctionAux
    variable = T
    function = '1000-t'
  []
[]

[Kernels]
  [solid_x]
    type = ADStressDivergenceTensors
    variable = disp_x
    component = 0
  []
  [solid_y]
    type = ADStressDivergenceTensors
    variable = disp_y
    component = 1
  []
[]

[BCs]
  [xdisp]
    type = DirichletBC
    variable = 'disp_x'
    boundary = 'left'
    value = 0
  []
  [yfix]
    type = DirichletBC
    variable = 'disp_y'
    boundary = 'left right'
    value = 0
  []
[]

[Materials]
  # Glass
  [bulk_properties_glass]
    type = ADGenericConstantMaterial
    prop_names = 'E nu l a1 ft Gc'
    prop_values = '${E_glass} ${nu_glass} ${l} ${a1} ${ft} ${Gc}'
    block = glass
  []
  [crack_geometric]
    type = CrackGeometricFunction
    property_name = alpha
    expression = '2*d-d*d'
    phase_field = d
    block = glass
  []
  [degradation]
    type = RationalDegradationFunction
    property_name = g
    expression = (1-d)^p/((1-d)^p+a1*d*(1+a2*d+a3*d^2))
    phase_field = d
    material_property_names = 'a1'
    parameter_names = 'p a2 a3'
    parameter_values = '2 -0.5 0'
    output_properties = 'g'
    outputs = exodus
    block = glass
  []
  [eigenstrain_glass]
    type = ADComputeThermalExpansionEigenstrain
    eigenstrain_name = thermal_eigenstrain
    stress_free_temperature = 1000
    thermal_expansion_coeff = ${alpha_glass}
    temperature = T
    block = glass
  []
  [strain_glass]
    type = ADComputeSmallStrain
    eigenstrain_names = thermal_eigenstrain
    block = glass
  []
  [elasticity_glass]
    type = SmallDeformationHBasedElasticity
    youngs_modulus = E
    poissons_ratio = nu
    tensile_strength = ft
    fracture_energy = Gc
    phase_field = d
    degradation_function = g
    output_properties = 'dpsie/dd psie_active'
    outputs = exodus
    block = glass

  []
  [stress_glass]
    type = ComputeSmallDeformationStress
    elasticity_model = elasticity_glass
    output_properties = 'stress'
    outputs = exodus
    block = glass
  []

  # Steel
  [eigenstrain_steel]
    type = ADComputeThermalExpansionEigenstrain
    eigenstrain_name = thermal_eigenstrain
    stress_free_temperature = 1000
    thermal_expansion_coeff = ${alpha_steel}
    temperature = T
    block = steel
  []
  [strain_steel]
    type = ADComputeSmallStrain
    eigenstrain_names = thermal_eigenstrain
    block = steel
  []
  [elasticity_steel]
    type = ADComputeIsotropicElasticityTensor
    shear_modulus = ${G_steel}
    bulk_modulus = ${K_steel}
  []
  [stress_steel]
    type = ADComputeLinearElasticStress
    block = steel
  []
[]

[Executioner]
  type = Transient

  # solve_type = NEWTON
  # petsc_options_iname = '-pc_type -pc_factor_mat_solver_package'
  # petsc_options_value = 'lu       superlu_dist                 '
  solve_type = 'PJFNK' #求解器，PJFNK是预处理雅可比自由牛顿-克雷洛夫方法
  petsc_options_iname = '-ksp_gmres_restart -pc_type -pc_hypre_type'
  petsc_options_value = '201                hypre    boomeramg'  
  automatic_scaling = true

  nl_rel_tol = 1e-7
  nl_abs_tol = 1e-8

  dt = 10
  end_time = 1000

  fixed_point_algorithm = picard
  fixed_point_max_its = 5
  fixed_point_rel_tol = 1e-5
  fixed_point_abs_tol = 1e-6
  accept_on_max_fixed_point_iteration = true
[]

[Outputs]
  exodus = true
  print_linear_residuals = false
[]
