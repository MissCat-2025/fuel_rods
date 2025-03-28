[Problem]
    kernel_coverage_check = false
    material_coverage_check = false
  []
  # 双冷却环形燃料几何参数 (单位：mm)(无内外包壳)
pellet_inner_diameter = 10.291         # 芯块内直径mm
pellet_outer_diameter = 14.627         # 芯块外直径mm
length = 6e-5                    # 轴向长度(m)
# 网格控制参数n_azimuthal = 512时网格尺寸为6.8e-5m
n_radial_pellet = 32          # 燃料径向单元数
n_azimuthal = 512           # 周向基础单元数
growth_factor = 1.0        # 径向增长因子
n_axial = 1                # 轴向单元数
# 计算半径参数 (转换为米)
pellet_inner_radius = '${fparse pellet_inner_diameter/2*1e-3}'
pellet_outer_radius = '${fparse pellet_outer_diameter/2*1e-3}'
#自适应法线公差
normal_tol = '${fparse 3.14*pellet_inner_diameter/n_azimuthal*1e-3/10}'
[Mesh]
  [pellet1]
    type = AnnularMeshGenerator
    nr = ${n_radial_pellet}
    nt = ${n_azimuthal}
    rmin = ${pellet_inner_radius}
    rmax = ${pellet_outer_radius}
    growth_r = ${growth_factor}
    boundary_id_offset = 10
    boundary_name_prefix = 'pellet'
  []
  [pellet]
    type = SubdomainIDGenerator
    input = pellet1
    subdomain_id = 1
  []
  [rename1]
    type = RenameBoundaryGenerator
    input = pellet
    old_boundary = 'pellet_rmin pellet_rmax'
    new_boundary = 'pellet_inner pellet_outer'
  []
  [extrude]
    type = MeshExtruderGenerator
    input = rename1
    extrusion_vector = '0 0 ${length}'
    num_layers = '${n_axial}'
    bottom_sideset = 'bottom'
    top_sideset = 'top'
  []
  [rename2]
    type = RenameBlockGenerator
    input = extrude
    old_block = '1'
    new_block = 'pellet'
  []
  # 创建x轴切割边界面 (y=0线)
  [x_axis_cut]
    type = SideSetsBetweenSubdomainsGenerator
    input = rename2
    new_boundary = 'x_axis'
    primary_block = 'pellet'
    paired_block = 'pellet'
    normal = '0 1 0'  # 法线方向为Y轴
    normal_tol = '${normal_tol}'
  []
  # 创建x轴切割边界面 (y=0线)
  [y_axis_cut]
    type = SideSetsBetweenSubdomainsGenerator
    input = x_axis_cut
    new_boundary = 'y_axis'
    primary_block = 'pellet'
    paired_block = 'pellet'
    normal = '1 0 0'  # 法线方向为X轴
    normal_tol = '${normal_tol}'
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
      expression = 'd'
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
    accept_on_max_fixed_point_iteration = true # 达到最大迭代次数时接受解
    automatic_scaling = true # 启用自动缩放功能，有助于改善病态问题的收敛性
    compute_scaling_once = true  # 每个时间步都重新计算缩放
    nl_max_its = 30
    nl_rel_tol = 1e-5 # 非线性求解的相对容差
    nl_abs_tol = 1e-8 # 非线性求解的绝对容差
    l_tol = 1e-6  # 线性求解的容差
    l_abs_tol = 1e-9 # 线性求解的绝对容差
    l_max_its = 150 # 线性求解的最大迭代次数
    dtmin = 1
    end_time = 1000000
    
    [TimeStepper]
      type = FunctionDT
      function = dt_limit_func
    []
  []
  [Postprocessors]
    [d_average]
      type = ElementAverageValue
      variable = d
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
      expression = 'if(t < 0.2, 0.1,
                     if(t < 864000,
                        if(abs(d_increment) < 1e-3, 100000,
                           if(abs(d_increment) < 5e-3, 50000,
                              if(abs(d_increment) < 1e-2, 20000,
                                 if(abs(d_increment) < 5e-2, 10000,
                                    if(abs(d_increment) < 1e-1, 5000, 1000)))))
                        ,
                        if(abs(d_increment) < 1e-3, 25000,
                           if(abs(d_increment) < 5e-3, 10000,
                              if(abs(d_increment) < 1e-2, 5000,
                                 if(abs(d_increment) < 5e-2, 2500,
                                    if(abs(d_increment) < 1e-1, 1000, 500)))))
                     ))'
      symbol_names = 'd_increment'
      symbol_values = 'd_increment'
    []
  []
  
  [Outputs]
    print_linear_residuals = false
  []
  