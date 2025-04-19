[Problem]
    kernel_coverage_check = false
    material_coverage_check = false
  []
  # 各种参数都取自[1]Multiphysics phase-field modeling of quasi-static cracking in urania ceramic nuclear fuel
#几何与网格参数
pellet_outer_radius = 4.1e-3#直径变半径，并且单位变mm
length = 4.75e-5 # 芯块长度17.78mm
n_elems_axial = 1 # 轴向网格数
grid_sizes = 1.9e-4 #mm,最大网格尺寸（虚），1.9e-4真实的网格尺寸为4.75e-5
#将下列参数转化为整数
n_elems_azimuthal = '${fparse 2*ceil(3.1415*2*pellet_outer_radius/grid_sizes/2)}'  # 周向网格数（向上取整）
n_elems_radial_pellet = '${fparse int(pellet_outer_radius/grid_sizes)}'          # 芯块径向网格数（直接取整）


[Mesh]
  [pellet_clad_gap]
    type = ConcentricCircleMeshGenerator
    num_sectors = '${n_elems_azimuthal}'  # 周向网格数
    radii = '${pellet_outer_radius}'
    rings = '${n_elems_radial_pellet}'
    has_outer_square = false
    preserve_volumes = true
    portion = top_right # 生成四分之一计算域
    smoothing_max_it=666 # 平滑迭代次数
  []
  [rename]
    type = RenameBoundaryGenerator
    input = pellet_clad_gap
    old_boundary = 'bottom left outer'
    new_boundary = 'yplane xplane pellet_outer' # 将边界命名为yplane xplane clad_outer

  []
[extrude]
  type = AdvancedExtruderGenerator
  input = rename                   # 修改输入为切割后的网格
  heights = '${length}'
  num_layers = '${n_elems_axial}'
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
  old_block  = '1'
  new_block  = 'pellet' # 将block1和block3分别命名为pellet和clad
[]
[]
  
  [Variables]
    [d]
      block = pellet
    []
  []
  
  [AuxVariables]
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
    [bounds_dummy]
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
      prop_names = 'l Gc a1'
      prop_values = '${l} ${Gc} ${a1}'
      block = pellet
    []
    [sigma0_mat]
      type = ADParsedMaterial
      property_name = sigma0
      coupled_variables = 'sigma0_field'
      expression = 'sigma0_field'
      block = pellet
    []
    [degradation]
      type = RationalDegradationFunction
      property_name = g
      expression = (1-d)^p/((1-d)^p+a1*d*(1+a2*d+a3*d^2))*(1-eta)+eta
      phase_field = d
      material_property_names = 'a1'
      parameter_names = 'p a2 a3 eta'
      parameter_values = '2.5 3.1748 0 1e-6' #指数软化
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
  
    solve_type = NEWTON
    petsc_options_iname = '-ksp_gmres_restart -pc_type -pc_hypre_type  -snes_type'
    petsc_options_value = '201                hypre    boomeramg  vinewtonrsls'   
    automatic_scaling = true # 启用自动缩放功能，有助于改善病态问题的收敛性
    compute_scaling_once = true  # 每个时间步都重新计算缩放
    
    nl_max_its = 5
    nl_rel_tol = 1e-6 # 非线性求解的相对容差
    nl_abs_tol = 1e-7 # 非线性求解的绝对容差
    l_tol = 1e-7  # 线性求解的容差
    l_abs_tol = 1e-8 # 线性求解的绝对容差
    l_max_its = 150 # 线性求解的最大迭代次数
    accept_on_max_fixed_point_iteration = true # 达到最大迭代次数时接受解
    dtmin = 50
    dt = 2500 # 时间步长3600s
    end_time = 3.2e5 # 总时间24h
  
    fixed_point_rel_tol =1e-4 # 固定点迭代的相对容差
    # [TimeStepper]
    #   type = FunctionDT
    #   function = dt_limit_func
    # []
  []
  # [Postprocessors]
  #   [d_average]
  #     type = ElementAverageValue
  #     variable = d
  #     # value_type = average
  #     execute_on = 'initial timestep_end'
  #     block = pellet
  #   []
  #   [d_increment]
  #     type = ChangeOverTimePostprocessor
  #     change_with_respect_to_initial = false
  #     postprocessor = d_average
  #     execute_on = 'initial timestep_end'
  #   []
  #   [dt_limit]
  #     type = FunctionValuePostprocessor
  #     function = dt_limit_func
  #     execute_on = 'TIMESTEP_BEGIN'
  #   []
  # []
  
  # [Functions]
  #   [dt_limit_func]
  #     type = ParsedFunction
  #     expression = 'if(t <20000,5000,
  #                     if(t <95000,
  #                       if(abs(d_increment) < 1e-3,5000, 
  #                         if(abs(d_increment) < 5e-3,2500, 
  #                           if(abs(d_increment) < 1e-2,2000, 
  #                             if(abs(d_increment) < 5e-2,1000, 
  #                               if(abs(d_increment) < 1e-1,500,100))))),
  #                       if(abs(d_increment) < 1e-3,2000, 
  #                         if(abs(d_increment) < 5e-3,1000, 
  #                           if(abs(d_increment) < 1e-2,500, 
  #                             if(abs(d_increment) < 5e-2,250, 
  #                               if(abs(d_increment) < 1e-1,100,50)))))))'
  #     symbol_names = 'd_increment'
  #     symbol_values = 'd_increment'
  #   []
  # []
  
  [Outputs]
    print_linear_residuals = false
  []