# 各种参数都取自[1]Multiphysics phase-field modeling of quasi-static cracking in urania ceramic nuclear fuel

#几何与网格参数
pellet_outer_radius = 4.1e-3#直径变半径，并且单位变mm
clad_inner_radius = 4.18e-3#直径变半径，并且单位变mm
clad_outer_radius = 4.78e-3#直径变半径，并且单位变mm
length = 11e-3 # 芯块长度17.78mm
n_elems_axial = 2 # 轴向网格数
n_elems_azimuthal = 50 # 周向网格数
n_elems_radial_clad = 4 # 包壳径向网格数
n_elems_radial_pellet = 30 # 芯块径向网格数

[Mesh]
    [pellet_clad_gap]
      type = ConcentricCircleMeshGenerator
      num_sectors = '${n_elems_azimuthal}'  # 周向网格数
      radii = '${pellet_outer_radius} ${clad_inner_radius} ${clad_outer_radius}'
      rings = '${n_elems_radial_pellet} 1 ${n_elems_radial_clad}'
      has_outer_square = false
      preserve_volumes = true
      portion = top_right # 生成四分之一计算域
      smoothing_max_it=10 # 平滑迭代次数
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
    type = MeshExtruderGenerator
    input = rename
    extrusion_vector = '0 0 ${length}' # 轴向长度
    num_layers = '${n_elems_axial}' # 轴向网格数
    bottom_sideset = 'bottom' # 命名为底面
    top_sideset = 'top' # 命名为顶面
  []
  [rename2]
    type = RenameBlockGenerator
    input = extrude
    old_block  = '1 3'
    new_block  = 'pellet clad' # 将block1和block3分别命名为pellet和clad
  []
[]

#以上是生成几何与网格
# 》》》》》》》》》》》》》》》》》》》》》》》》》》》
# 》》》》》》》》》》》》》》》》》》》》》》》》》》》》》》》》

#力平衡方程相关参数
pellet_elastic_constants=2.2e11#Pa
pellet_nu = 0.345
clad_elastic_constants=7.52e10#Pa
clad_nu = 0.33

#热平衡方程相关参数
#芯块的热物理参数
pellet_density=10431.0#10431.0*0.85#kg⋅m-3
# pellet_specific_heat=300 # J/(kg·K)
# pellet_thermal_conductivity = 5 # W/(m·K)
# pellet_thermal_expansion_coef=1e-5#K-1

#包壳的热物理参数
clad_density=6.59e3#kg⋅m-3
clad_specific_heat=264.5 # J/(kg·K)
clad_thermal_conductivity = 16 # W/(m·K)
clad_thermal_expansion_coef=5.0e-6#K-1

#上一节将基础的热力耦合实现了。但是反应堆中温度变化大，各种材料参数也会随着变化，以及间隙压力，热源的变化等，
#这一章，我们将一一实现这些涉及[Functions]与[Materials]的参数。
# 以下是[Functions]与[Materials]中全部需要补充的实现的内容：
# 为了理清楚哪些参数需要变化，我们将各种方程与边界条件写在下面，并分析其变化。

# 热传导方程：ρc∂T/∂t = ∇·(k∇T) + q'''(在域Ω内)，
#   其中：ρ为密度，c为定压比热容，k为热导率，q'''为体积热源。【热源q'''、定压比热容c】需要变化、【密度ρ】不变 
#   边界条件：
#   - 绝热边界：-k∇T·n = 0
#   - 温度边界：T = T₀ ，T₀为冷却剂温度{冷却剂温度}会发生变化
#   - 间隙传热：q = h(T₁-T₂)，h为等效导热系数{假设间隙压力}不变化
#   - 热应变εth，ε热 = α(T-T₀)，【热膨胀系数α】需要变化


####### #1. 力平衡方程：∇·σ + f = 0  (在域Ω内)，没有f，无相关可变的参数
#但ε总 = ε弹 + ε热 = B·u + εth，【B相关参数】目前先不变
#   边界条件：σ·n = t  (在域Ω的边界Γ上)，有包壳外的{水的压力边界条件Pressure}，与{芯块包壳间隙压力边界条件Pressure}
#   应力与应变的关系：σ = D·ε弹  (在域Ω内)，D为弹性矩阵，【弹性矩阵D】先不变

# ！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！
# 
#好，我们目前理清楚了。但是有没有发现有的参数我用【】，有的参数我用{}，
#这是因为【】表示的是直接与咱们画的网格节点有关的参数，即[Materials]参数
#例如热导率，由于热导率与温度有关，而正常来讲我们求解域内的温度不能全一样，而如何表示这么一个形式呢？想起我们之前画的网格了吗？每个网格点都有自己的温度，因此每个网格节点也对应一个自己的热导率。
#【】是与网格节点有关的参数，计算时会逐个计算节点热导率而形成一个热导率矩阵k[_qp],_qp表示的是每个网格单元上的积分点。
#[Materials]中定义的参数，都是与网格节点有关的参数,因此一般在Materials中定义的函数（如  [stress] type = ADComputeLinearElasticStress []），都有computeQpProperties()函数，该函数的目的是计算出每个网格节点上的对应的参数值。
#[Materials]操作与网格节点相关的量，表示为x[_qp]，都有computeQpProperties()函数。
#如果我们继续外推，[Variables]中定义的变量，与网格节点与时间有关都有关系。
# 这是理解MOOSE的关键。
#
#！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！

# 而{}表示的是[Functions]里的函数，它与网格节点无关，它表示的是一个函数，这个函数可以是一个常数，也可以是一个变量，也可以是一个表达式。
# 例如：包壳外的{水的压力边界条件Pressure}，与{芯块包壳间隙压力边界条件Pressure}，边界条件所有的值都对应同一个值，这个值的规律被定义在[Functions]中。
# 当然，你也可以将[Functions]与[Materials]结合起来。

#到了这里，我们开始完善[Materials]与[Functions]了
# [Materials]
# 1. 芯块材料属性：经验公式、比热容经验公式
# 2. 包壳材料属性：暂无
# 3. 热-力耦合：线性热应变经验公式
# [Functions]
# 1. 源项（功率分布）
# 2. 边界条件（冷却剂温度，冷却剂压力，间隙压力）

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
      type = HeatSource # 体积热源项 q''' W/m³
      variable = T
      value = 1 # 
      function = power_density # 功率密度=value*function，#新加的！！！！！！！！！！！！！！！！！！！！！！
      block = pellet # 只在芯块区域有热源
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
  #3. 温度边界条件
  [ADNeumannBC0]
    type = ADNeumannBC # 绝热边界条件
    variable = T
    boundary = 'yplane xplane'
    value = 0
  []
  [coolant_bc]
    type = ADFunctionDirichletBC # 冷却剂温度边界条件
    variable = T
    boundary = clad_outer
    function = colden_temperature #新加的！！！！！！！！！！！！！！！！！！！！！！
  []
[]

[Materials]
  #1. 芯块材料属性
  #热物理属性
  [pellet_properties]
    type = ADGenericConstantMaterial
    prop_names = 'density'
    prop_values = '${pellet_density}'
    block = pellet
  []
  [pellet_thermal_conductivity] #新加的！！！！！！！！！！！！！！！！！！！！！！
    type = ADParsedMaterial
    property_name = thermal_conductivity
    coupled_variables = 'T'
    expression = '100/(7.5408 + 17.692*T/1000 + 3.6142*(T/1000)^2) + 6400/((T/1000)^2.5)*exp(-16.35/(T/1000))'
    block = pellet
  []
  [pellet_specific_heat] #新加的！！！！！！！！！！！！！！！！！！！！！！
    type = ADParsedMaterial
    property_name = specific_heat
    coupled_variables = 'T'
    expression = '52.1743 + 87.951*T/1000 - 84.2411*(T/1000)^2 + 31.542*(T/1000)^3 - 2.6334*(T/1000)^4 - 0.71391*(T/1000)^(-2)'
    block = pellet
  []
  #热应变
  [pellet_thermal_eigenstrain] #新加的！！！！！！！！！！！！！！！！！！！！！！
    type = ADComputeDilatationThermalExpansionFunctionEigenstrain
    dilatation_function = ThermalExpansionFunction    # 使用上面定义的函数
    stress_free_temperature = 500        # 参考温度
    temperature = T                         # 温度变量
    eigenstrain_name = thermal_eigenstrain  # 改用统一的命名
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
    youngs_modulus = ${pellet_elastic_constants} # 弹性模量
    poissons_ratio = ${pellet_nu} # 泊松比
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
    stress_free_temperature = 500 # 参考温度500K，这个值对于模拟结果影响巨大，一般取为初始温度
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

# 线密度转为体积密度的转换系数
power_factor = '${fparse 1000*1/3.1415926/pellet_outer_radius/pellet_outer_radius}' #新加的！！！！！！！！！！！！！！！！！！！！！！
[Functions]
  [power_density] #新加的！！！！！！！！！！！！！！！！！！！！！！
    type = PiecewiseLinear
    data_file = power_history.csv    # 创建一个包含上述数据的CSV文件，数据为<s,w/m>
    format = columns                 # 指定数据格式为列式
    scale_factor = ${power_factor}         # 保持原有的转换因子
    # 论文中只给了线密度，需要化为体积密度
  []
  [colden_pressure] #新加的！！！！！！！！！！！！！！！！！！！！！！
    #冷却剂压力随时间的变化
    type = PiecewiseLinear
    x = '0          125000   175000   300000'
    y = '0          15.5     15.5     0.0'
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
    x = '0          300000'
    y = '2.5          14'
    scale_factor = 1
  []
  [ThermalExpansionFunction] #新加的！！！！！！！！！！！！！！！！！！！！！！
    type = ParsedFunction
    expression = '(-4.972e-4 + 7.107e-6*t + 2.581e-9*t*t + 1.14e-13*t*t*t)'
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
    gap_conductivity = 0.25 # 间隙等效导热系数
    quadrature = true
    gap_geometry_type = CYLINDER # 圆柱形间隙
    cylinder_axis_point_1 = '0 0 0'
    cylinder_axis_point_2 = '0 0 0.0001'
  []
[]

[Executioner]
  type = Transient # 瞬态求解器
  solve_type = 'PJFNK' #求解器，PJFNK是预处理雅可比自由牛顿-克雷洛夫方法

  automatic_scaling = true # 启用自动缩放功能，有助于改善病态问题的收敛性
  compute_scaling_once = true  # 每个时间步都重新计算缩放
  nl_max_its = 20
  nl_rel_tol = 5e-7 # 非线性求解的相对容差
  nl_abs_tol = 1e-7 # 非线性求解的绝对容差
  l_tol = 1e-7  # 线性求解的容差
  l_max_its = 50 # 线性求解的最大迭代次数
  accept_on_max_fixed_point_iteration = true # 达到最大迭代次数时接受解
  dt = 14400 # 时间步长3600s
  end_time = 3e5 # 总时间24h
  # 现在我们就卡死nl_max_its = 10，  以及l_max_its = 50以试一下各个求解器

    # #1.不完全LU分解（最慢，甚至第一步就不收敛）
    # petsc_options_iname = '-pc_type'
    # petsc_options_value = 'ilu'      # 不完全LU分解
  # 2.直接求解器（最快）
    # petsc_options_iname = '-pc_type'
    # petsc_options_value = 'lu'       # LU分解，小问题效果好
  #3.加速收敛，（巨慢，第一步倒是收敛了）中等规模
    # petsc_options_iname = '-pc_type -sub_pc_type -sub_pc_factor_shift_type'
    # petsc_options_value = 'asm lu NONZERO'  # 加速收敛
  #4.多重网格（第二快）大规模
    petsc_options_iname = '-pc_type -pc_hypre_type'
    petsc_options_value = 'hypre boomeramg'  # 代数多重网格，大问题效果好
  #5.GMRES重启参数（并列第二快）大规模问题
    # petsc_options_iname = '-ksp_gmres_restart  -pc_type  -pc_hypre_type  -pc_hypre_boomeramg_max_iter'
    # petsc_options_value = '201                  hypre     boomeramg       4'
 

    #计算到约130000s时，环形应力达到2Gpa，早已发生开裂，因此无法收敛。
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
  [axial_stress]
    order = CONSTANT
    family = MONOMIAL
  []

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
  [axial_stress]
    type = ADRankTwoScalarAux
    variable = axial_stress
    rank_two_tensor = stress
    scalar_type = AxialStress
    point1 = '0 0 0'
    point2 = '0 0 1'
    execute_on = 'TIMESTEP_END'
  []
[]


[Outputs]
  exodus = true #表示输出exodus格式文件
[]