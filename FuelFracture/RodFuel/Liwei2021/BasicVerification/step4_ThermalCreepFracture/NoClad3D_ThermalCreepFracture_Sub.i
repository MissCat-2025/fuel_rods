# === 参数研究案例 ===
# power_factor_mod: 1.5
# Gf: 8
# length_scale_paramete: 3.00e-4
# 生成时间: 2025-02-21 08:28:25

[Problem]
    kernel_coverage_check = false
    material_coverage_check = false
  []
 # 各种参数都取自[1]Multiphysics phase-field modeling of quasi-static cracking in urania ceramic nuclear fuel
#几何与网格参数
pellet_outer_radius = 4.1e-3#直径变半径，并且单位变mm
length = 4.75e-5 # 芯块长度17.78mm
n_elems_axial = 1 # 轴向网格数
grid_sizes = 2.9e-4 #mm,最大网格尺寸（虚），1.9e-4真实的网格尺寸为4.75e-5
#将下列参数转化为整数
n_elems_azimuthal = '${fparse 2*ceil(3.1415*2*pellet_outer_radius/grid_sizes/2)}'  # 周向网格数（向上取整）
n_elems_radial_pellet = '${fparse int(pellet_outer_radius/grid_sizes)}'          # 芯块径向网格数（直接取整）

#自适应法线公差
normal_tol = '${fparse 3.14*pellet_outer_radius/n_elems_azimuthal*1e-3/100}'

[Mesh]
  [pellet_clad_gap]
    type = ConcentricCircleMeshGenerator
    num_sectors = '${n_elems_azimuthal}'  # 周向网格数
    radii = '${pellet_outer_radius}'
    rings = '${n_elems_radial_pellet}'
    has_outer_square = false
    preserve_volumes = true
    portion = full # 生成四分之一计算域
    smoothing_max_it=666 # 平滑迭代次数
  []
  [rename]
    type = RenameBoundaryGenerator
    input = pellet_clad_gap
    old_boundary = 'outer'
    new_boundary = 'pellet_outer' # 将边界命名为yplane xplane clad_outer
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
# 创建x轴切割边界面 (y=0线)
[x_axis_cut]
  type = SideSetsBetweenSubdomainsGenerator
  input = rename2
  new_boundary = 'yplane'
  primary_block = 'pellet'
  paired_block = 'pellet'
  normal = '0 1 0'  # 法线方向为Y轴
  normal_tol = '${normal_tol}'
[]
# 创建x轴切割边界面 (y=0线)
[y_axis_cut]
  type = SideSetsBetweenSubdomainsGenerator
  input = x_axis_cut
  new_boundary = 'xplane'
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
    automatic_scaling = true # 启用自动缩放功能，有助于改善病态问题的收敛性
    compute_scaling_once = true  # 每个时间步都重新计算缩放
    
    nl_max_its = 30
    nl_rel_tol = 1e-6 # 非线性求解的相对容差
    nl_abs_tol = 1e-7 # 非线性求解的绝对容差
    l_tol = 1e-7  # 线性求解的容差
    l_abs_tol = 1e-8 # 线性求解的绝对容差
    l_max_its = 150 # 线性求解的最大迭代次数
    accept_on_max_fixed_point_iteration = true # 达到最大迭代次数时接受解
    dtmin = 50
    dt = 10000 # 时间步长3600s
    end_time = 3.5e5 # 总时间24h
  
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
      expression = 'if(t <20000,5000,
                      if(t <95000,
                        if(abs(d_increment) < 1e-3,5000, 
                          if(abs(d_increment) < 5e-3,2500, 
                            if(abs(d_increment) < 1e-2,2000, 
                              if(abs(d_increment) < 5e-2,1000, 
                                if(abs(d_increment) < 1e-1,500,100))))),
                        if(abs(d_increment) < 1e-3,2000, 
                          if(abs(d_increment) < 5e-3,1000, 
                            if(abs(d_increment) < 1e-2,500, 
                              if(abs(d_increment) < 5e-2,250, 
                                if(abs(d_increment) < 1e-1,100,50)))))))'
      symbol_names = 'd_increment'
      symbol_values = 'd_increment'
    []
  []
  
  [Outputs]
    print_linear_residuals = false
  []