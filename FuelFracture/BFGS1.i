E_glass = 6.4e4
nu_glass = 0.2
K_glass = '${fparse E_glass/3/(1-2*nu_glass)}'
G_glass = '${fparse E_glass/2/(1+nu_glass)}'
alpha_glass = 3.25e-6

E_steel = 1.93e5
nu_steel = 0.29
K_steel = '${fparse E_steel/3/(1-2*nu_steel)}'
G_steel = '${fparse E_steel/2/(1+nu_steel)}'
alpha_steel = 1.73e-5

Gc = 0.4
ft = 80.0
l = 1
a1 = '${fparse 4*E_steel*Gc/ft/ft/3.14159/l}'

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
  max_h_level = 2
  [Markers]
    [marker]
      type = BoxMarker
      bottom_left = '27 7 0'
      top_right = '60 28 0'
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
  [d]
  []
[]
[Bounds]
  [irreversibility]
    type = VariableOldValueBounds
    variable = bounds_dummy
    bounded_variable = d
    bound_type = lower
    block = glass
  []
  [upper]
    type = ConstantBounds
    variable = bounds_dummy
    bounded_variable = d
    bound_type = upper
    bound_value = 1
    block = glass
  []
[]
[AuxVariables]
  [T]
    initial_condition = 1000
  []
  [psie_active]
    order = CONSTANT
    family = MONOMIAL
    block = glass
  []
  [bounds_dummy]
    block = glass
  []
[]





[AuxKernels]
  [cooling]
    type = FunctionAux
    variable = T
    function = '1000-t'
  []
  [psie_active]
    type = ADMaterialRealAux
    variable = psie_active
    property = psie_active
    block = glass
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
  [diff]
    type = ADPFFDiffusion
    variable = d
    fracture_toughness = Gc
    regularization_length = l
    normalization_constant = c0
    block = glass
  []
  [source]
    type = ADPFFSource
    variable = d
    free_energy = psi
    block = glass
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
    prop_names = 'K G l a1 Gc'
    prop_values = '${K_glass} ${G_glass} ${l} ${a1} ${Gc}'
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
    expression = (1-d)^p/((1-d)^p+a1*d*(1+a2*d+a3*d^2))*(1-eta)+eta
    phase_field = d
    material_property_names = 'a1'
    parameter_names = 'p a2 a3 eta'
    parameter_values = '2 -0.5 0 1e-6'
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
    type = SmallDeformationIsotropicElasticity
    bulk_modulus = K
    shear_modulus = G
    phase_field = d
    degradation_function = g
    decomposition = SPECTRAL
    block = glass
  []
  [stress_glass]
    type = ComputeSmallDeformationStress
    elasticity_model = elasticity_glass
    block = glass
  []
  [psi]
    type = ADDerivativeParsedMaterial
    property_name = psi
    expression = 'alpha*Gc/c0/l+psie'
    coupled_variables = d
    material_property_names = 'alpha(d) g(d) Gc c0 l psie(d)'
    derivative_order = 1
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

  solve_type = NEWTON
  petsc_options_iname = '-snes_type
                        -pc_type -pc_hypre_type 
                        -npc_snes_type -npc_snes_qn_type '
  petsc_options_value = 'vinewtonrsls
                        hypre boomeramg 
                        qn lbfgs '
  automatic_scaling = true
  nl_rel_tol = 1e-6
  nl_abs_tol = 1e-8
  dt = 1
  end_time = 200
  fixed_point_max_its = 15
  accept_on_max_fixed_point_iteration = true
[]

[Outputs]
  exodus = true
  # print_linear_residuals = false
[]
