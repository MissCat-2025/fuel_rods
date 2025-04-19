[Problem]
    kernel_coverage_check = false
    material_coverage_check = false
  []
  # 双冷却环形燃料几何参数 (单位：mm)(无内外包壳)
# dt = 50000
pellet_inner_diameter = 10.291         # 芯块内直径mm
pellet_outer_diameter = 14.627         # 芯块外直径mm
length = 6e-5                    # 轴向长度(m)

mesh_size = 5e-5  #网格尺寸即可
n_azimuthal = '${fparse int(3.1415*(pellet_outer_diameter)/mesh_size*1e-3/4)*4}' #int()取整
n_radial_pellet = '${fparse int((pellet_outer_diameter-pellet_inner_diameter)/mesh_size*1e-3/2)}'
n_axial = 1                # 轴向单元数
# 计算半径参数 (转换为米)
pellet_inner_radius = '${fparse pellet_inner_diameter/2*1e-3}'
pellet_outer_radius = '${fparse pellet_outer_diameter/2*1e-3}'
[Mesh]
  [pellet1]
    type = AnnularMeshGenerator
    nr = ${n_radial_pellet}
    nt = ${n_azimuthal}
    rmin = ${pellet_inner_radius}
    rmax = ${pellet_outer_radius}
    growth_r = 1.0
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
  [cut_x]
    type = PlaneDeletionGenerator
    input = rename1
    point = '0 0 0'
    normal = '-1 0 0'  # 切割x>0区域
    new_boundary = 'y_axis'
  []
  [cut_y]
    type = PlaneDeletionGenerator
    input = cut_x
    point = '0 0 0'
    normal = '0 -1 0'  # 切割y>0区域
    new_boundary = 'x_axis'
  []
  [extrude]
    type = AdvancedExtruderGenerator
    input = cut_y                   # 修改输入为切割后的网格
    heights = '${length}'
    num_layers = '${n_axial}'
    direction = '0 0 1'
    bottom_boundary = '100'
    top_boundary = '101'
    subdomain_swaps = '1 1'
  []
  [rename_extrude]
    type = RenameBoundaryGenerator
    input = extrude
    old_boundary = '100 101'
    new_boundary = 'bottom top' # 最终边界命名
  []
  [rename2]
    type = RenameBlockGenerator
    input = rename_extrude
    old_block = '1'
    new_block = 'pellet'
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
    [a1]
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
      prop_names = 'l Gc'
      prop_values = '${l} ${Gc}'
      block = pellet
    []
    [sigma0_mat]
      type = ADParsedMaterial
      property_name = sigma0
      coupled_variables = 'sigma0_field'
      expression = 'sigma0_field'
      block = pellet
    []
  [a11]
    type = ADParsedMaterial
    property_name = a1
    coupled_variables = 'a1'
    expression = 'a1'
    block = pellet
  []
    #断裂力学-CZM模型
    [degradation]
      type = RationalDegradationFunction
      property_name = g
      expression = (1-d)^p/((1-d)^p+a1*d*(1+a2*d))*(1-eta)+eta
      phase_field = d
      material_property_names = 'a1'
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
      expression = 'alpha*Gc/c0/l+g*(psie_active)'
      coupled_variables = 'd psie_active'
      material_property_names = 'alpha(d) g(d) Gc c0 l'
      # output_properties = 'psi'
      # outputs = exodus
      block = pellet
    []
  []
  
  [Executioner]
    type = Transient
  
    # solve_type = NEWTON
    solve_type = PJFNK
    petsc_options_iname = '-ksp_gmres_restart -pc_type -pc_hypre_type  -snes_type'
    petsc_options_value = '201                hypre    boomeramg  vinewtonrsls'  
    accept_on_max_fixed_point_iteration = true # 达到最大迭代次数时接受解
    automatic_scaling = true # 启用自动缩放功能，有助于改善病态问题的收敛性
    compute_scaling_once = true  # 每个时间步都重新计算缩放
    nl_max_its = 30
    nl_rel_tol = 1e-6 # 非线性求解的相对容差
    nl_abs_tol = 1e-7 # 非线性求解的绝对容差
    l_tol = 1e-7  # 线性求解的容差
    l_abs_tol = 1e-8 # 线性求解的绝对容差
    l_max_its = 150 # 线性求解的最大迭代次数
    dtmin = 500
    # dt = ${dt}
    end_time = 1100000
    [TimeStepper]
      type = FunctionDT
      function = dt_limit_func
    []
  []
[Functions]
  [dt_limit_func]
    type = ParsedFunction
    expression = 'if(t < 250000, 500000,
                   if(t < 950000, 25000, 10000))'
  []
[]
  [Outputs]
    # exodus = true
    print_linear_residuals = false
  []
  