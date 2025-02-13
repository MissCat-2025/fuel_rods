#这一步的目的是计算燃料棒的应力分布
#这一步加入蠕变，蠕变与氧超化学计量UO2+x有关。
#氧超化学计量需要多加入一个控制方程，即氧扩散方程，参考文献
#《[1] WEI LI, KOROUSH SHIRVAN. Multiphysics phase-field modeling of quasi-static cracking in urania ceramic nuclear fuel[J/OL]. Ceramics International, 2021, 47(1): 793-810. DOI:10.1016/j.ceramint.2020.08.191.》

#该输入文件取自pellets/Wu2021/test_creep/step6_AddCreepStrain.i，可任意替换


pellet_density=10431.0#10431.0*0.85#kg⋅m-3
pellet_elastic_constants=2.2e11#Pa
pellet_nu = 0.345
pellet_specific_heat=300 # J/(kg·K)
pellet_thermal_conductivity = 5 # W/(m·K)
pellet_thermal_expansion_coef=1e-5#K-1

clad_density=6.59e3#kg⋅m-3
clad_elastic_constants=7.52e10#Pa
clad_nu = 0.33
clad_specific_heat=264.5
clad_thermal_conductivity = 16
clad_thermal_expansion_coef=5.0e-6#K-1

#几何与网格参数
pellet_outer_radius = 4.1e-3#直径变半径，并且单位变mm
clad_inner_radius = 4.18e-3#直径变半径，并且单位变mm
clad_outer_radius = 4.78e-3#直径变半径，并且单位变mm
length = 0.1e-3 # 芯块长度17.78mm
n_elems_axial = 1 # 轴向网格数
n_elems_azimuthal = 40 # 周向网格数
n_elems_radial_clad = 3 # 包壳径向网格数
n_elems_radial_pellet = 8 # 芯块径向网格数

[Mesh]
  parallel_type = distributed  # 添加这一行
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


[GlobalParams]
    displacements = 'disp_x disp_y disp_z'
[]
[AuxVariables]
  # 导出应力
  [./hoop_stress]
    order = CONSTANT
    family = MONOMIAL
  [../]
    [./creep_hoop_strain]
      order = CONSTANT
      family = MONOMIAL
    [../]
      [vonMises]
        order = CONSTANT
        family = MONOMIAL
      []
[]

[AuxKernels]
  #导出各种数据
  [./hoop_stress]
    type = ADRankTwoScalarAux
    variable = hoop_stress
    rank_two_tensor = stress
    scalar_type = HoopStress
    point1 = '0 0 0'        # 圆心坐标
    point2 = '0 0 -0.0178'        # 定义旋转轴方向（z轴）
    execute_on = 'TIMESTEP_END'
  [../]
    [./creep_strain]
      type = ADRankTwoAux
      variable = creep_hoop_strain
      rank_two_tensor = creep_eigenstrain
      index_i = 2
      index_j = 2  # zz分量对应环向
      execute_on = 'TIMESTEP_END'
      block = pellet
    [../]
      [vonMisesStress]
        type = ADRankTwoScalarAux
        variable = vonMises
        rank_two_tensor = stress
        execute_on = 'TIMESTEP_END'
        scalar_type = VonMisesStress
        # 不需要 index_i 和 index_j，因为我们使用 VonMisesStress 标量类型
      []
[]

[Variables]
    [disp_x]
    []
    [disp_y]
    []
    [disp_z]
    []
    [T]
      initial_condition = 500
    []
    [x]
    initial_condition =0.01
    block = pellet
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
    [solid_z]
        type = ADStressDivergenceTensors
        variable = disp_z
        component = 2
    []
    #热传导方程
    [heat_conduction]
      type = ADHeatConduction
      variable = T
    []
    [hcond_time]
      type = ADHeatConductionTimeDerivative
      variable = T
    []
    [Fheat_source]
      type = ADMatHeatSource
      variable = T
      material_property = total_power
      block = pellet
    []
    #氧扩散方程
  #化学平衡方程
  [time_derivative]
    type = ADTimeDerivative
    variable = x
    block = pellet
  []
  [complex_diffusion]
    type = ADComplexDiffusionKernel  # 需要实现这个自定义kernel
    variable = x
    temperature = T
    block = pellet
  []
[]
[BCs]
  #固定平面的位移边界条件
  [y_zero_on_y_plane]
    type = ADDirichletBC
    variable = disp_y
    boundary = 'x_axis'
    value = 0
  []
  [x_zero_on_x_plane]
    type = ADDirichletBC
    variable = disp_x
    boundary = 'y_axis'
    value = 0
  []
  [z_zero_on_bottom_top]
    type = DirichletBC
    variable = disp_z
    boundary = 'bottom'
    value = 0
  []
    #冷却剂压力
    [colden_pressure_fuel_x]
      type = Pressure
      variable = disp_x
      boundary = 'clad_outer'
      factor = 15.5e6
      use_displaced_mesh = true
    []
    [colden_pressure_fuel_y]
      type = Pressure
      variable = disp_y
      boundary = 'clad_outer'
      factor = 15.5e6
      use_displaced_mesh = true
    []
    #芯块包壳间隙压力
    [gap_pressure_fuel_x]
      type = Pressure
      variable = disp_x
      boundary = 'clad_inner pellet_outer'
      factor = 2.5e6
      use_displaced_mesh = true
    []
    [gap_pressure_fuel_y]
      type = Pressure
      variable = disp_y
      boundary = 'clad_inner pellet_outer'
      factor = 2.5e6
      use_displaced_mesh = true
  []
  [coolant_bc]#对流边界条件
    type = DirichletBC
    variable = T
    boundary = clad_outer
    value = 500
  []
  #氧浓度边界条件
  [x_dirichlet_bc]
    type = DirichletBC
    variable = x
    boundary = pellet_outer
    value = 0.01
  []
[]
[Materials]
    #定义芯块热导率、密度、比热等材料属性
    [pellet_properties]
      type = ADGenericConstantMaterial
      prop_names = 'density thermal_conductivity specific_heat'
      prop_values = '${pellet_density} ${pellet_thermal_conductivity} ${pellet_specific_heat}'
      block = pellet
    []
    # 然后定义总功率材料
    [total_power]
      type = ADTotalPowerMaterial_NoBurnup
      power_history = power_history
      pellet_radius = ${pellet_outer_radius}
      block = pellet
    []
    #特征应变的加入
    #热应变
    [pellet_thermal_eigenstrain]
      type = ADComputeThermalExpansionEigenstrain
      eigenstrain_name = thermal_eigenstrain
      stress_free_temperature = 500
      thermal_expansion_coeff = ${pellet_thermal_expansion_coef}
      temperature = T
      block = pellet
    []
  # # # # # 蠕变相关
  [creep_rate]
    type = UO2CreepRate
    temperature = T
    oxygen_ratio = x
    fission_rate = 1e19
    theoretical_density = 95.0
    grain_size = 10.0
    vonMisesStress = vonMises
    block = pellet
  []
    # 蠕变特征应变
    [creep_eigenstrain]
      type = ADComputeUO2CreepEigenstrain
      eigenstrain_name = creep_eigenstrain
      block = pellet
    []
    [pellet_strain]
        type = ADComputeSmallStrain 
        eigenstrain_names = 'thermal_eigenstrain creep_eigenstrain'
        block = pellet
    []
    [pellet_elasticity_tensor]
      type = ADComputeIsotropicElasticityTensor
      youngs_modulus = ${pellet_elastic_constants}
      poissons_ratio = ${pellet_nu}
      block = pellet
    []


    #定义包壳热导率、密度、比热等材料属性
    [clad_properties]
      type = ADGenericConstantMaterial
      prop_names = ' density specific_heat thermal_conductivity'
      prop_values = '${clad_density} ${clad_specific_heat} ${clad_thermal_conductivity}'
      block = clad
    []
    [clad_thermal_eigenstrain]
      type = ADComputeThermalExpansionEigenstrain
      eigenstrain_name = thermal_eigenstrain
      stress_free_temperature = 500
      thermal_expansion_coeff = ${clad_thermal_expansion_coef}
      temperature = T
      block = clad
    []
    [clad_strain]
      type = ADComputeSmallStrain 
      eigenstrain_names = 'thermal_eigenstrain'
      block = clad
    []
    [clad_elasticity_tensor]
        type = ADComputeIsotropicElasticityTensor
        youngs_modulus = ${clad_elastic_constants}
        poissons_ratio = ${clad_nu}
        block = clad
    []

    # 计算应力
    [stress]
        type = ADComputeLinearElasticStress
    []

[]
[ThermalContact]
  [./thermal_contact]
    type = GapHeatTransfer
    variable = T
    primary = clad_inner
    secondary = pellet_outer
    emissivity_primary =0.8
    emissivity_secondary =0.8
    gap_conductivity = 0.18
    quadrature = true
    gap_geometry_type = CYLINDER
    cylinder_axis_point_1 = '0 0 0'
    cylinder_axis_point_2 = '0 0 0.0001'
  [../]
[]
[Functions]
  [power_history]
    type = PiecewiseLinear
    data_file = power_history.csv    # 创建一个包含上述数据的CSV文件，数据为<s,w/m>
    format = columns                 # 指定数据格式为列式
    scale_factor = 1.5166e7         # 保持原有的转换因子
  []
[]
[Executioner]
  type = Transient
  # solve_type = 'PJFNK'
  solve_type = 'PJFNK'  # 使用预处理的雅可比无矩阵方法
  # petsc_options_iname = '-pc_type -pc_factor_mat_solver_package -ksp_type'
  # petsc_options_value = 'lu superlu_dist gmres'
    # 减少内存使用
  # petsc_options = '-ksp_reuse_preconditioner -pc_factor_reuse_ordering'
  # line_search = 'basic'  # 添加基本线搜索
  # petsc_options_iname = '-pc_type -ksp_type -pc_hypre_type'
  # petsc_options_value = 'hypre    gmres     boomeramg'
  # reuse_preconditioner = true
  # reuse_preconditioner_max_linear_its = 20
  # petsc_options_iname = '-pc_type -pc_hypre_type'
  # petsc_options_value = 'hypre    boomeramg'
  # line_search = 'basic'  # 添加线搜索以提高稳定性
  # petsc_options_iname = '-pc_type -pc_hypre_type -ksp_gmres_restart'
  # petsc_options_value = 'hypre boomeramg 200'
# petsc_options_iname = '-pc_type -ksp_type -pc_factor_shift_type -pc_factor_shift_amount'
# petsc_options_value = 'bjacobi  gmres     NONZERO        1e-10'
  # petsc_options_iname = '-pc_type -pc_factor_mat_solver_package'
  # petsc_options_value = 'lu       superlu_dist                 '
  petsc_options_iname = '-ksp_gmres_restart -pc_type -pc_hypre_type'
  petsc_options_value = '201                hypre    boomeramg'
  # solve_type = 'NEWTON'
  # petsc_options = '-ksp_converged_reason'
  # petsc_options_iname = '-pc_type -pc_factor_mat_solver_package -ksp_type'
  # petsc_options_value = 'lu       superlu_dist                  gmres'
  dtmax = 20000
  dtmin = 1
  end_time =300000
  # automatic_scaling = true # 启用自动缩放功能，有助于改善病态问题的收敛性
  # compute_scaling_once = true  # 每个时间步都重新计算缩放
  nl_max_its = 20
  nl_rel_tol = 5e-5 # 非线性求解的相对容差
  nl_abs_tol = 5e-6 # 非线性求解的绝对容差
  l_tol = 5e-5  # 线性求解的容差
  l_max_its = 100 # 线性求解的最大迭代次数
  accept_on_max_fixed_point_iteration = true # 达到最大迭代次数时接受解
  [TimeStepper]
    type = IterationAdaptiveDT
    dt = 1000
    growth_factor = 2  # 时间步长增长因子
    cutback_factor = 0.5 # 时间步长缩减因子
    optimal_iterations = 8 # 期望的非线性迭代次数
  []
[]
[Outputs]
  # exodus = true
[]