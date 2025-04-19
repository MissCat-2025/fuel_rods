[Problem]
  kernel_coverage_check = false
  material_coverage_check = false
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
  initial_steps = 3
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
  [d]
    block = glass
  []
[]

[AuxVariables]
  [bounds_dummy]
    block = glass
  []
  [psie_active]
    order = CONSTANT
    family = MONOMIAL
    block = glass
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

[Kernels]
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

[Materials]
  [fracture_properties]
    type = ADGenericConstantMaterial
    prop_names = 'Gc a1 l'
    prop_values = '${Gc} ${a1} ${l}'
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
    parameter_names = 'p a2 a3 eta '
    parameter_values = '2 -0.5 0 1e-6'
    block = glass
  []
  [psi]
    type = ADDerivativeParsedMaterial
    property_name = psi
    expression = 'alpha*Gc/c0/l+g*psie_active'
    coupled_variables = 'd psie_active'
    material_property_names = 'alpha(d) g(d) Gc c0 l'
    derivative_order = 1
    output_properties = 'psi psie_active'
    outputs = exodus
    block = glass
  []
[]

[Executioner]
  type = Transient

  solve_type = NEWTON
  petsc_options_iname = '-ksp_gmres_restart -pc_type -pc_hypre_type   -snes_type'
  petsc_options_value = '201                hypre    boomeramg vinewtonrsls'  
  # petsc_options_iname = '-ksp_gmres_restart -pc_type -pc_hypre_type'
  # petsc_options_value = '201                hypre    boomeramg'  
  automatic_scaling = true

  nl_rel_tol = 1e-7
  nl_abs_tol = 1e-8
  dt = 2
  end_time = 400
[]

[Outputs]
  # exodus = true
  print_linear_residuals = false
[]
