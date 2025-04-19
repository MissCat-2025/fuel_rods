# 陶瓷片热冲击实验 - 相场断裂部分
[Problem]
  kernel_coverage_check = false
  material_coverage_check = false
[]

[Mesh]
  [gmg]
    type = GeneratedMeshGenerator
    dim = 2
    nx = 250            # 25mm / 0.05mm = 500
    ny = 100            # 5mm / 0.05mm = 100
    xmax = 25e-3
    ymax = 10e-3
  []
[]

[Variables]
  [d]  # 相场变量
  []
[]

[AuxVariables]
  [psie_active]
    order = CONSTANT
    family = MONOMIAL
  []
[]
[Kernels]
  [pff_complementarity]
    type = ADPFFComplementarityKernel
    variable = d
    degradation_function = g
    strain_energy = psie_active
    fracture_toughness = Gc
    normalization_constant = c0
    regularization_length = l
    geometric_function = alpha
    rate_tolerance = 1e-9
  []
[]

[Materials]
  [fracture_properties]
    type = ADGenericConstantMaterial
    prop_names = 'Gc a1 l'
    prop_values = '${Gc} ${a1} ${l}'
  []
  
  [crack_geometric]
    type = CrackGeometricFunction
    property_name = alpha
    expression = '2*d-d*d'
    phase_field = d
  []
  
  [degradation]
    type = RationalDegradationFunction
    property_name = g
    expression = (1-d)^p/((1-d)^p+a1*d*(1+a2*d+a3*d^2))*(1-eta)+eta
    phase_field = d
    material_property_names = 'a1'
    parameter_names = 'p a2 a3 eta'
    parameter_values = '2 -0.5 0 1e-8'
  []
  [psie_active]
    type = ADParsedMaterial
    property_name = psie_active
    expression = 'psie_active'
    coupled_variables = 'psie_active'
  []
[]
[BCs]
  # 没有边界条件，这是相场变量的本质
[]

[Executioner]
  type = Transient
  
  solve_type = NEWTON
  petsc_options_iname = '-ksp_gmres_restart -pc_type -pc_hypre_type'
  petsc_options_value = '201                hypre    boomeramg'
  automatic_scaling = true
  
  nl_rel_tol = 1e-7
  nl_abs_tol = 1e-8
  
  dt = 0.2e-3
  end_time = 200e-3
[]

[Outputs]
  exodus = false
  print_linear_residuals = false
[]