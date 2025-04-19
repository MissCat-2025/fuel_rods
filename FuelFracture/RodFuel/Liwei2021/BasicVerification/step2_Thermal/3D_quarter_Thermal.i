# 各种参数都取自[1]Multiphysics phase-field modeling of quasi-static cracking in urania ceramic nuclear fuel
# conda activate moose
# mpirun -n 12 /home/yp/projects/raccoon/raccoon-opt -i 3D_quarter_Thermal.i
# 》》》》》》》》》》》》》》》》》》》》》》》》》》》
# 》》》》》》》》》》》》》》》》》》》》》》》》》》》》》》》》

#力平衡方程相关参数
pellet_elastic_constants=2.0e11#Pa
pellet_nu = 0.345
clad_elastic_constants=7.52e10#Pa
clad_nu = 0.33

#热平衡方程相关参数
#芯块的热物理参数
pellet_density=10431.0#10431.0*0.85#kg⋅m-3
pellet_thermal_expansion_coef=1e-5#K-1

#包壳的热物理参数
clad_density=6.59e3#kg⋅m-3
clad_specific_heat=264.5 # J/(kg·K)
clad_thermal_conductivity = 16 # W/(m·K)
clad_thermal_expansion_coef=5.0e-6#K-1

# 各种参数都取自[1]Multiphysics phase-field modeling of quasi-static cracking in urania ceramic nuclear fuel
#几何与网格参数
pellet_outer_radius = 4.1e-3#直径变半径，并且单位变mm
clad_inner_radius = 4.18e-3#直径变半径，并且单位变mm
clad_outer_radius = 4.78e-3#直径变半径，并且单位变mm
length = 4.75e-4 # 芯块长度17.78mm
n_elems_axial = 1 # 轴向网格数
grid_sizes = 1.9e-4 #mm,最大网格尺寸（虚），1.9e-4真实的网格尺寸为4.75e-5
#将下列参数转化为整数
n_elems_azimuthal = '${fparse 2*ceil(3.1415*2*pellet_outer_radius/grid_sizes/2)}'  # 周向网格数（向上取整）
n_elems_radial_pellet = '${fparse int(pellet_outer_radius/grid_sizes)}'          # 芯块径向网格数（直接取整）

n_elems_radial_clad = 4


[Mesh]
  [pellet_clad_gap]
    type = ConcentricCircleMeshGenerator
    num_sectors = '${n_elems_azimuthal}'  # 周向网格数
    radii = '${pellet_outer_radius} ${clad_inner_radius} ${clad_outer_radius}'
    rings = '${n_elems_radial_pellet} 1 ${n_elems_radial_clad}'
    has_outer_square = false
    preserve_volumes = true
    portion = top_right # 生成四分之一计算域
    smoothing_max_it=666 # 平滑迭代次数
  []
  [rename_pellet_outer_bdy]
    type = SideSetsBetweenSubdomainsGenerator
    input = pellet_clad_gap
    primary_block = 1
    paired_block = 2
    new_boundary = 'pellet_outer' #将block1与block2之间的边界命名为pellet_outer
  []
  [rename_clad_inner_bdy]
    type = SideSetsBetweenSubdomainsGenerator
    input = rename_pellet_outer_bdy
    primary_block = 3
    paired_block = 2
    new_boundary = 'clad_inner' #将block3与block2之间的边界命名为clad_inner
  []

  [2d_mesh]
    type = BlockDeletionGenerator
    input = rename_clad_inner_bdy
    block = 2 # 删除block2
  []
  [rename]
    type = RenameBoundaryGenerator
    input = 2d_mesh
    old_boundary = 'bottom left outer'
    new_boundary = 'yplane xplane clad_outer' # 将边界命名为yplane xplane clad_outer

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
  old_block  = '1 3'
  new_block  = 'pellet clad' # 将block1和block3分别命名为pellet和clad
[]
[]

[GlobalParams]
    displacements = 'disp_x disp_y disp_z'
[]

[Variables]
  #定义位移变量 - 用于求解力平衡方程
    [disp_x]
      family = LAGRANGE
      order = FIRST
    []
    [disp_y]
    []
    [disp_z]
    []
    #定义温度变量 - 用于求解热传导方程
    [T]
      initial_condition = 293.15 # 初始温度500K
    []
[]

[Kernels]
  #1. 力平衡方程相关项
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
    #2. 热传导方程相关项
    [heat_conduction]
      type = ADHeatConduction # 热传导项 ∇·(k∇T)
      variable = T
    []
    [hcond_time]
      type = ADHeatConductionTimeDerivative # 时间导数项 ρc∂T/∂t
      variable = T
    []
    [Fheat_source]
      type = HeatSource
      variable = T
      function = power_history
      block = pellet
    []
[]

[BCs]
  #1. 位移边界条件
  #固定平面的位移边界条件
  [y_zero_on_y_plane]
    type = DirichletBC
    variable = disp_y
    boundary = 'yplane'
    value = 0
  []
  [x_zero_on_x_plane]
    type = DirichletBC
    variable = disp_x
    boundary = 'xplane'
    value = 0
  []
  [z_zero_on_bottom_top]
    type = DirichletBC
    variable = disp_z
    boundary = 'bottom'
    value = 0
  []
  #2. 压力边界条件
  #冷却剂压力边界条件
  [colden_pressure_fuel_x]
    type = Pressure
    variable = disp_x
    boundary = 'clad_outer'
    factor = 1e6 # 冷却剂压力15.5MPa
    function = colden_pressure #新加的！！！！！！！！！！！！！！！！！！！！！！
    use_displaced_mesh = true
  []
  [colden_pressure_fuel_y]
    type = Pressure
    variable = disp_y
    boundary = 'clad_outer'
    factor = 1e6
    function = colden_pressure #新加的！！！！！！！！！！！！！！！！！！！！！！
    use_displaced_mesh = true
  []
  #芯块包壳间隙压力边界条件
  [gap_pressure_fuel_x]
    type = Pressure
    variable = disp_x
    boundary = 'clad_inner pellet_outer'
    factor = 1e6 # 间隙压力2.5MPa
    function = gap_pressure #新加的！！！！！！！！！！！！！！！！！！！！！！
    use_displaced_mesh = true
  []
  [gap_pressure_fuel_y]
    type = Pressure
    variable = disp_y
    boundary = 'clad_inner pellet_outer'
    factor = 1e6
    function = gap_pressure #新加的！！！！！！！！！！！！！！！！！！！！！！
    use_displaced_mesh = true
  []
  [coolant_bc]#对流边界条件
    type = ConvectiveFluxFunction
    variable = T
    boundary = clad_outer
    T_infinity = colden_temperature
    coefficient = 3.4e4#3.4e4 W·m-2 K-1
  []
  [T_0BC]
    type = NeumannBC
    variable = T
    boundary = 'xplane yplane'
    value = 0
  []
[]

[AuxVariables]
  [hoop_stress]
    order = CONSTANT
    family = MONOMIAL
  []
  [radial_stress]    # 径向应力，用于检查压力在径向的传递
    order = CONSTANT
    family = MONOMIAL
  []
  [./thermal_hoop_strain]
    order = CONSTANT
    family = MONOMIAL
  [../] 
[]

[AuxKernels]
  [hoop_stressP]
    type = ADRankTwoScalarAux
    variable = hoop_stress
    rank_two_tensor = stress #这里的stress与材料属性中的ADComputeLinearElasticStress有关，它帮我们计算出来了stress
    scalar_type = HoopStress #关于其他应力的导出形式，请参考：https://mooseframework.inl.gov/source/utils/RankTwoScalarTools.html
    #point2-point1的向量就是轴的方向（x,y,z）。正负不影响结果，大小也不影响结果
    point1 = '0 0 0'
    point2 = '0 0 1'
    execute_on = 'TIMESTEP_END' #表示在每个时间步结束时执行，
    # execute_on还有INITIAL、LINEAR、NONLINEAR、TIMESTEP_BEGIN、FINAL等形式
  []
  [radial_stress]
    type = ADRankTwoScalarAux
    variable = radial_stress
    rank_two_tensor = stress
    scalar_type = RadialStress
    point1 = '0 0 0'
    point2 = '0 0 -1'
    execute_on = 'TIMESTEP_END'
  []
    [./thermal_strain]
      type = ADRankTwoAux
      variable = thermal_hoop_strain
      rank_two_tensor = thermal_eigenstrain
      index_i = 2
      index_j = 2  # zz分量对应环向
      execute_on = 'TIMESTEP_END'
    [../]
[]



[Materials]
  #1. 芯块材料属性
    #热物理属性
    [pellet_properties2]
      type = ADGenericConstantMaterial
      prop_names = 'density'
      prop_values = '${pellet_density}'
      block = pellet
    []
  [pellet_thermal_conductivity] #新加的！！！！！！！！！！！！！！！！！！！！！！
    type = ADParsedMaterial
    property_name = thermal_conductivity
    coupled_variables = 'T'
    expression = '(100/(7.5408 + 17.692*T/1000 + 3.6142*(T/1000)^2) + 6400/((T/1000)^2.5)*exp(-16.35/(T/1000)))'
    block = pellet
  []
  [pellet_specific_heat]
    type = ADParsedMaterial
    property_name = specific_heat #Fink model
    coupled_variables = 'T'  # 需要在AuxVariables中定义Y变量
    expression = '(296.7 * 535.285^2 * exp(535.285/T))/(T^2 * (exp(535.285/T) - 1)^2) + 2.43e-2 * T + (2) * 8.745e7 * 1.577e5 * exp(-1.577e5/(8.314*T))/(2 * 8.314 * T^2)'
    block = pellet
  []
  #热应变
  [pellet_thermal_eigenstrain]
    type = ADComputeThermalExpansionEigenstrain
    eigenstrain_name = thermal_eigenstrain
    stress_free_temperature = 293.15 # 参考温度500K，这个值对于模拟结果影响巨大，一般取为初始温度
    thermal_expansion_coeff = ${pellet_thermal_expansion_coef} # 热膨胀系数
    temperature = T
    block = pellet
  []
  #力学属性
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
  #2. 包壳材料属性
  #热物理属性
  [clad_properties]
    type = ADGenericConstantMaterial
    prop_names = 'density specific_heat thermal_conductivity'
    prop_values = '${clad_density} ${clad_specific_heat} ${clad_thermal_conductivity}'
    block = clad
  []
  #热-力耦合：热应变
  [clad_thermal_eigenstrain]
    type = ADComputeThermalExpansionEigenstrain
    eigenstrain_name = thermal_eigenstrain
    stress_free_temperature = 293.15 # 参考温度500K，这个值对于模拟结果影响巨大，一般取为初始温度
    thermal_expansion_coeff = ${clad_thermal_expansion_coef} # 热膨胀系数
    temperature = T
    block = clad
  []
  #力学属性
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
  #一起计算应力
  [stress]
    type = ADComputeLinearElasticStress
  []
[]

[ThermalContact] #新加的！！！！！！！！！！！！！！！！！！！！！！
  [thermal_contact]
    type = GapHeatTransfer # 间隙传热模型
    variable = T
    primary = clad_inner # 主边界
    secondary = pellet_outer # 从边界
    emissivity_primary = 0.8 # 主边界发射率
    emissivity_secondary = 0.8 # 从边界发射率
    gap_conductivity = 50 # 间隙等效导热系数
    quadrature = true
    gap_geometry_type = CYLINDER # 圆柱形间隙
    cylinder_axis_point_1 = '0 0 0'
    cylinder_axis_point_2 = '0 0 0.0001'
  []
[]
# 线密度转为体积密度的转换系数
power_factor = '${fparse 1000*1/3.1415926/pellet_outer_radius/pellet_outer_radius}' #新加的！！！！！！！！！！！！！！！！！！！！！！
[Functions]
  [power_history] #新加的！！！！！！！！！！！！！！！！！！！！！！
    type = PiecewiseLinear
    x = '0.0 100000 125000 175000 300000'
    y = '0.0 18.0 35.0 35.0 0.0'
    scale_factor = ${power_factor}
  []
  [colden_pressure] #新加的！！！！！！！！！！！！！！！！！！！！！！
    #冷却剂压力随时间的变化
    type = PiecewiseLinear
    x = '0          125000   175000   300000'
    y = '0.1          15.5     15.5     0.1'
    scale_factor = 1
  []
  [colden_temperature] #新加的！！！！！！！！！！！！！！！！！！！！！！
    #冷却剂温度随时间的变化
    type = PiecewiseLinear
    x = '0          125000   175000   300000'
    y = '293.15          600     600     293.15'
    scale_factor = 1
  []
  [gap_pressure] #新加的！！！！！！！！！！！！！！！！！！！！！！
    #间隙压力随时间的变化
    type = PiecewiseLinear
    x = '0          125000   175000   300000'
    y = '2.5  6  10  14'
    scale_factor = 1
  []
[]



[Executioner]
  type = Transient # 瞬态求解器
  solve_type = 'PJFNK' #求解器，PJFNK是预处理雅可比自由牛顿-克雷洛夫方法
  petsc_options_iname = '-pc_type -pc_factor_mat_solver_package -ksp_type'
  petsc_options_value = 'lu superlu_dist gmres'

  automatic_scaling = true # 启用自动缩放功能，有助于改善病态问题的收敛性
  compute_scaling_once = true  # 每个时间步都重新计算缩放
  nl_max_its = 30
  nl_rel_tol = 1e-7 # 非线性求解的相对容差
  nl_abs_tol = 1e-8 # 非线性求解的绝对容差
  l_tol = 1e-7  # 线性求解的容差
  l_abs_tol = 1e-8 # 线性求解的绝对容差
  l_max_its = 150 # 线性求解的最大迭代次数
  accept_on_max_fixed_point_iteration = true # 达到最大迭代次数时接受解
  dtmin =1
  dtmax = 10000
  end_time = 3e5 # 总时间24h

  fixed_point_rel_tol =1e-4 # 固定点迭代的相对容差
  [TimeStepper]
    type = IterationAdaptiveDT
    dt = 5000
    growth_factor = 1.1
    cutback_factor = 0.5
  []
[]


[Outputs]
  exodus = true #表示输出exodus格式文件
  print_linear_residuals = false
[]
