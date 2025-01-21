[Problem]
  kernel_coverage_check = false
  material_coverage_check = false
[]
#几何与网格参数
pellet_outer_radius = 4.1e-3#直径变半径，并且单位变mm
clad_inner_radius = 4.18e-3#直径变半径，并且单位变mm
clad_outer_radius = 4.78e-3#直径变半径，并且单位变mm
length = 0.1e-3 # 芯块长度17.78mm
n_elems_axial = 1 # 轴向网格数
n_elems_azimuthal = 100 # 周向网格数
n_elems_radial_clad = 4 # 包壳径向网格数
n_elems_radial_pellet = 20 # 芯块径向网格数

[Mesh]
  [pellet_clad_gap]
    type = ConcentricCircleMeshGenerator
    num_sectors = '${n_elems_azimuthal}'
    radii = '${pellet_outer_radius} ${clad_inner_radius} ${clad_outer_radius}'
    rings = '${n_elems_radial_pellet} 1 ${n_elems_radial_clad}'
    has_outer_square = false
    preserve_volumes = true
    smoothing_max_it = 10
  []
  [rename_pellet_outer_bdy]
    type = SideSetsBetweenSubdomainsGenerator
    input = pellet_clad_gap
    primary_block = 1
    paired_block = 2
    new_boundary = 'pellet_outer'
  []
  [rename_clad_inner_bdy]
    type = SideSetsBetweenSubdomainsGenerator
    input = rename_pellet_outer_bdy
    primary_block = 3
    paired_block = 2
    new_boundary = 'clad_inner'
  []
  [2d_mesh]
    type = BlockDeletionGenerator
    input = rename_clad_inner_bdy
    block = 2
  []
  [rename_outer]
    type = RenameBoundaryGenerator
    input = 2d_mesh
    old_boundary = 'outer'
    new_boundary = 'clad_outer'
  []
  [extrude]
    type = MeshExtruderGenerator
    input = rename_outer
    extrusion_vector = '0 0 ${length}'
    num_layers = '${n_elems_axial}'
    bottom_sideset = 'bottom'
    top_sideset = 'top'
  []
  [rename2]
    type = RenameBlockGenerator
    input = extrude
    old_block = '1 3'
    new_block = 'pellet clad'
  []
  [x_axis]
    type = ExtraNodesetGenerator
    input = rename2
    coord = '0 0 ${length}; 0 0 0;${clad_outer_radius} 0 0;-${clad_outer_radius} 0 0'
    new_boundary  = 'x_axis'
  []
  [y_axis]
    type = ExtraNodesetGenerator
    input = x_axis
    coord = '0 0 ${length}; 0 0 0;0 ${clad_outer_radius} 0;0 -${clad_outer_radius} 0'
    new_boundary  = 'y_axis'
  []
[]

[Variables]
  [d]
    block = pellet
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
    block = pellet
  []
  [source]
    type = ADPFFSource
    variable = d
    free_energy = psi
    block = pellet
  []
[]

[Materials]
  [fracture_properties]
    type = ADGenericConstantMaterial
    prop_names = 'l Gc E0'
    prop_values = '${l} ${Gc} ${E0}'
    block = pellet
  []
  [sigma0_mat]
    type = ADParsedMaterial
    property_name = sigma0
    coupled_variables = 'sigma0_field'
    expression = 'sigma0_field'
    block = pellet
  []
  #断裂力学-CZM模型
  # [degradation]
  #   type = RationalDegradationFunction
  #   property_name = g
  #   expression = (1-d)^p/((1-d)^p+(4*Gc*E0/sigma0^2/3.14/l)*d*(1+a2*d))
  #   phase_field = d
  #   material_property_names = 'Gc sigma0 l E0'
  #   parameter_names = 'p a2'
  #   parameter_values = '2 -0.5'
  #   block = pellet
  # []
  # [crack_geometric]
  #   type = CrackGeometricFunction
  #   property_name = alpha
  #   expression = '2*d-d*d'
  #   phase_field = d
  #   block = pellet
  # [] 
  [degradation]
    type = RationalDegradationFunction
    property_name = g
    expression = (1-d)^p/((1-d)^p+(1.5*E0*Gc/sigma0^2)/l*d*(1+a2*d))*(1-eta)+eta
    phase_field = d
    material_property_names = 'Gc sigma0 l E0'
    parameter_names = 'p a2 eta'
    parameter_values = '2 2 1e-6'
    block = pellet
  []
  [crack_geometric]
    type = CrackGeometricFunction
    property_name = alpha
    expression = '4*d'
    phase_field = d
    block = pellet
  []  
  [psi]
    type = ADDerivativeParsedMaterial
    property_name = psi
    expression = 'alpha*Gc/c0/l+g*psie_active'
    coupled_variables = 'd psie_active'
    material_property_names = 'alpha(d) g(d) Gc c0 l'
    block = pellet
  []
[]

[Executioner]
  type = Transient

  # solve_type = NEWTON
  solve_type = PJFNK
  # petsc_options_iname = '-pc_type -pc_factor_mat_solver_package -snes_type'
  # petsc_options_value = 'lu       superlu_dist                  vinewtonrsls'
  
    # -pc_type lu: 使用LU分解作为预处理器
  # -pc_factor_mat_solver_package superlu_dist: 使用分布式SuperLU作为矩阵求解器
  # petsc_options_iname = '-pc_type -pc_factor_mat_solver_package -snes_type'
  # petsc_options_value = 'lu       superlu_dist                 vinewtonrsls'
  petsc_options_iname = '-ksp_gmres_restart -pc_type -pc_hypre_type  -snes_type'
  petsc_options_value = '201                hypre    boomeramg  vinewtonrsls'  
  automatic_scaling = true # 启用自动缩放功能，有助于改善病态问题的收敛性
  compute_scaling_once = true  # 每个时间步都重新计算缩放
  nl_max_its = 20
  nl_rel_tol = 1e-6 # 非线性求解的相对容差
  # nl_abs_tol = 1e-7 # 非线性求解的绝对容差
  l_tol = 1e-6  # 线性求解的容差
  l_max_its = 50 # 线性求解的最大迭代次数
  accept_on_max_fixed_point_iteration = true # 达到最大迭代次数时接受解
  dtmin = 0.0001
  dt = 10000 # 时间步长3600s
  end_time = 3e5 # 总时间24h

  fixed_point_rel_tol =1e-4 # 固定点迭代的相对容差
  [TimeStepper]
    type = FunctionDT
    function = dt_limit_func
  []
[]
[Postprocessors]
  [d_average]
    type = ElementAverageValue
    variable = d
    # value_type = average
    execute_on = 'initial timestep_end'
    block = pellet
  []
  [d_increment]
    type = ChangeOverTimePostprocessor
    change_with_respect_to_initial = false
    postprocessor = d_average
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
    expression = 'if(t <40000,10000,
                       if(abs(d_increment) < 1e-3,5000, 
                         if(abs(d_increment) < 5e-3,4000, 
                           if(abs(d_increment) < 1e-2,3000, 
                             if(abs(d_increment) < 5e-2,2000, 
                               if(abs(d_increment) < 1e-1,100,10))))))'
    symbol_names = 'd_increment'
    symbol_values = 'd_increment'
  []
[]

[Outputs]
  print_linear_residuals = false
[]
