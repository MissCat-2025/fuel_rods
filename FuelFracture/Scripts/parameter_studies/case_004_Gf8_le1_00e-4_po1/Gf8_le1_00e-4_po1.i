# === 参数研究案例 ===
# end_time = 5.0
# Gf: 8
# length_scale_paramete: 1.00e-4
# power_factor_mod: 1
# 生成时间: 2025-02-25 12:10:21

#step2计算了gap压力与冷却剂压力对应下的应力应变，
#step3基于此，开始启动反应堆，热交换开始，于是热力耦合开始
#边界条件[BCs]的变化：包壳外出现冷却剂，它既有500K的温度，也有15.5MP的压力
#核[kernel]的变化：加入热平衡方程的三项
#材料[Materials]的变化：加入热相关的参数（常数）：热膨胀系数，热传导系数，比热，密度

pellet_density=10431.0#10431.0*0.85#kg⋅m-3
pellet_elastic_constants=2.2e11#Pa
pellet_nu = 0.345
pellet_specific_heat=300
pellet_thermal_conductivity = 5
pellet_thermal_expansion_coef=1e-5#K-1

# mpirun -n 12 /home/yp/projects/raccoon/raccoon-opt -i NoClad3D_ThermalCouple.i 
#《《下面数据取自[1]Thermomechanical Analysis and Irradiation Test of Sintered Dual-Cooled Annular pellet》》

# 双冷却环形燃料几何参数 (单位：mm)(无内外包壳)
pellet_inner_diameter = 10.291         # 芯块内直径
pellet_outer_diameter = 14.627         # 芯块外直径
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


[GlobalParams]
    displacements = 'disp_x disp_y disp_z'
[]
[AuxVariables]
  [./hoop_stress]
    order = CONSTANT
    family = MONOMIAL
  [../]
              # 热应变分量
  [./thermal_hoop_strain]
    order = CONSTANT
    family = MONOMIAL
  [../]
  [./mechanical_hoop_strain]
    order = CONSTANT
    family = MONOMIAL
  [../]
  [./total_hoop_strain]
    order = CONSTANT
    family = MONOMIAL
  [../]
[]

[AuxKernels]
  [./hoop_stress]
    type = ADRankTwoScalarAux
    variable = hoop_stress
    rank_two_tensor = stress
    scalar_type = HoopStress
    point1 = '0 0 0'        # 圆心坐标
    point2 = '0 0 -0.0178'        # 定义旋转轴方向（z轴）
    execute_on = 'TIMESTEP_END'
  [../]
  [./thermal_strain]
    type = ADRankTwoAux
    variable = thermal_hoop_strain
    rank_two_tensor = thermal_eigenstrain
    index_i = 2
    index_j = 2  # zz分量对应环向
    execute_on = 'TIMESTEP_END'
  [../]
    [./mechanical_strain]
      type = ADRankTwoAux
      variable = mechanical_hoop_strain
      rank_two_tensor = mechanical_strain
      index_i = 2
      index_j = 2
      execute_on = 'TIMESTEP_END'
    [../]
    [./total_strain]
      type = ADRankTwoScalarAux
      variable = total_hoop_strain
      rank_two_tensor = total_strain
      scalar_type = VolumetricStrain
      point1 = '0 0 0'
      point2 = '0 0 -0.0178'
      execute_on = 'TIMESTEP_END'
    [../]
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
[]
[Kernels]
  #力平衡方程
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
      type = HeatSource
      variable = T
      value=4.8e8
      block = pellet
    []
[]
[BCs]
  #固定平面
  [y_zero_on_y_plane]
    type = DirichletBC
    variable = disp_y
    boundary = 'x_axis'
    value = 0
  []
  [x_zero_on_x_plane]
    type = DirichletBC
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

  #芯块包壳间隙压力
  [gap_pressure_fuel_x]
    type = Pressure
    variable = disp_x
    boundary = 'pellet_inner pellet_outer'
    factor = 2.5e6
    use_displaced_mesh = true
  []
  [gap_pressure_fuel_y]
    type = Pressure
    variable = disp_y
    boundary = 'pellet_inner pellet_outer'
    factor = 2.5e6
    use_displaced_mesh = true
  []
  [coolant_bc]#对流边界条件
    type = ConvectiveFluxFunction
    variable = T
    boundary = 'pellet_inner pellet_outer'
    T_infinity = 500
    coefficient = 3500#3500 W·m-2 K-1
  []
[]
[Materials]
    #定义芯块热导率、密度、比热等材料属性
    [pellet_properties]
      type = ADGenericConstantMaterial
      prop_names = ' density specific_heat thermal_conductivity'
      prop_values = '${pellet_density} ${pellet_specific_heat} ${pellet_thermal_conductivity}'
      block = pellet
    []
    [pellet_thermal_eigenstrain]
      type = ADComputeThermalExpansionEigenstrain
      eigenstrain_name = thermal_eigenstrain
      stress_free_temperature = 500
      thermal_expansion_coeff = ${pellet_thermal_expansion_coef}
      temperature = T
      block = pellet
    []
    [pellet_strain]
        type = ADComputeSmallStrain 
        eigenstrain_names = 'thermal_eigenstrain'
        block = pellet
    []
    [pellet_elasticity_tensor]
      type = ADComputeIsotropicElasticityTensor
      youngs_modulus = ${pellet_elastic_constants}
      poissons_ratio = ${pellet_nu}
      block = pellet
    []
    [clad_stress]
        type = ADComputeLinearElasticStress
    []

[]

[Executioner]
    type = Transient
    solve_type = 'PJFNK'
    petsc_options_iname = '-pc_type -pc_factor_mat_solver_package -ksp_type'
    petsc_options_value = 'lu superlu_dist gmres'
    dtmax = 1
    dtmin = 1
    end_time = 5
    automatic_scaling = true # 启用自动缩放功能，有助于改善病态问题的收敛性
    compute_scaling_once = true  # 每个时间步都重新计算缩放
    nl_max_its = 3
    nl_rel_tol = 1e-5 # 非线性求解的相对容差
    nl_abs_tol = 1e-8 # 非线性求解的绝对容差
    l_tol = 1e-6  # 线性求解的容差
    l_max_its = 10 # 线性求解的最大迭代次数
    # accept_on_max_fixed_point_iteration = true # 达到最大迭代次数时接受解
    [TimeStepper]
      type = IterationAdaptiveDT
      dt = 1
      cutback_factor = 0.5
      growth_factor = 2
      optimal_iterations = 10
      iteration_window = 5  
  []
[]
[Outputs]
  [my_checkpoint]
    type = Checkpoint
    time_step_interval = 5    # 每5个时间步保存
    num_files = 4            # 保留最近4个检查点
    wall_time_interval = 600 # 每10分钟保存一次（秒）
  []
  exodus =  true
[]