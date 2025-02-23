[Problem]
  kernel_coverage_check = false
  material_coverage_check = false
[]

[Mesh]
  [fmg]
    type = FileMeshGenerator
    file = granite0.0014.e
    []
[]

[Variables]
  [d]
  []
[]

[AuxVariables]
  [bounds_dummy]
  []
  [psie_active]
    order = CONSTANT
    family = MONOMIAL
  []
  [T]
    order = CONSTANT
    family = MONOMIAL
  []
  [sigma0_field]
    family = MONOMIAL
    order = CONSTANT
  []
[]

[Bounds]
  [irreversibility]
    type = VariableOldValueBounds
    variable = bounds_dummy
    bounded_variable = d
    bound_type = lower
  []
  [upper]
    type = ConstantBounds
    variable = bounds_dummy
    bounded_variable = d
    bound_type = upper
    bound_value = 1
  []
[]

[BCs]
[]
[Kernels]
  [diff]
    type = ADPFFDiffusion
    variable = d
    fracture_toughness = Gc
    regularization_length = l
    normalization_constant = c0
  []
  [source]
    type = ADPFFSource
    variable = d
    free_energy = psi
  []
[]

[Materials]
  [fracture_properties]
    type = ADGenericConstantMaterial
    prop_names = 'l Gc E0'
    prop_values = '${l} ${Gc} ${E0}'
  []
  [sigma0_mat]
    type = ADParsedMaterial
    property_name = sigma0
    coupled_variables = 'sigma0_field'
    expression = 'sigma0_field'
  []
  [degradation]
    type = RationalDegradationFunction
    property_name = g
    expression = (1-d)^p/((1-d)^p+(1.5*E0*Gc/sigma0^2)/l*d*(1+a2*d))*(1-eta)+eta
    phase_field = d
    material_property_names = 'Gc sigma0 l E0'
    parameter_names = 'p a2 eta'
    parameter_values = '2 2 1e-6'
  []
  [crack_geometric]
    type = CrackGeometricFunction
    property_name = alpha
    expression = '4*d'
    phase_field = d
  []
  # [degradation]
  #   type = RationalDegradationFunction
  #   property_name = g
  #   expression = (1-d)^p/((1-d)^p+(2*E0*Gc/sigma0^2)*(xi/c0/l)*d*(1+a2*d+a3*d^2))*(1-eta)+eta
  #   phase_field = d
  #   material_property_names = 'Gc sigma0 xi c0 l E0'
  #   parameter_names = 'p a2 a3 eta '
  #   parameter_values = '2 -0.5 0 1e-6'
  # []
  # [crack_geometric]
  #   type = CrackGeometricFunction
  #   property_name = alpha
  #   expression = '2*d-d*d'
  #   phase_field = d
  # []
  [psi]
    type = ADDerivativeParsedMaterial
    property_name = psi
    expression = 'alpha*Gc/c0/l+g*psie_active'
    coupled_variables = 'd psie_active'
    material_property_names = 'alpha(d) g(d) Gc c0 l'
    # outputs = exodus
  []
[]

[Executioner]
  type = Transient

  # solve_type = NEWTON
  solve_type = PJFNK
  petsc_options_iname = '-pc_type -pc_factor_mat_solver_package -snes_type'
  petsc_options_value = 'lu       superlu_dist                  vinewtonrsls'
    # -pc_type lu: 使用LU分解作为预处理器
  # -pc_factor_mat_solver_package superlu_dist: 使用分布式SuperLU作为矩阵求解器

  automatic_scaling = true # 启用自动缩放功能，有助于改善病态问题的收敛性
  compute_scaling_once = true  # 每个时间步都重新计算缩放

  nl_max_its = 20
  nl_rel_tol = 1e-7 # 非线性求解的相对容差
  nl_abs_tol = 5e-8 # 非线性求解的绝对容差
  l_tol = 1e-7  # 线性求解的容差
  l_max_its = 20 # 线性求解的最大迭代次数

  end_time = 5000 # 模拟的结束时间

  fixed_point_max_its =8 # 最大固定点迭代次数
  accept_on_max_fixed_point_iteration = true # 达到最大迭代次数时接受解
  fixed_point_rel_tol = 1e-5 # 固定点迭代的相对容差
  fixed_point_abs_tol = 5e-6 # 固定点迭代的绝对容差

  [TimeStepper]
    type = FunctionDT
    function = dt_limit_func
  []
[]

[Postprocessors]
  [d_max]
    type = ElementExtremeValue
    variable = d
    value_type = max
    execute_on = 'initial timestep_end'
  []
  [d_increment]
    type = ChangeOverTimePostprocessor
    change_with_respect_to_initial = false
    postprocessor = d_max
    execute_on = 'initial timestep_end'
  []
  [dt_limit]
    type = FunctionValuePostprocessor
    function = dt_limit_func
    execute_on = 'TIMESTEP_BEGIN'
  []
[]


[Functions]
  [dt_limit_func]
    type = ParsedFunction
    expression = 'if(abs(d_increment) < 5e-4, 50, 
                       if(abs(d_increment) < 1e-3,10, 
                         if(abs(d_increment) < 5e-3, 1, 
                           if(abs(d_increment) < 1e-2, 0.1, 
                             if(abs(d_increment) < 5e-2, 0.01, 
                               if(abs(d_increment) < 1e-1, 0.001, 0.0001))))))'
    symbol_names = 'd_increment'
    symbol_values = 'd_increment'
  []
[]
[Outputs]
  print_linear_residuals = false
  checkpoint = false
  
[]
