# === 参数研究案例 ===
# end_time = 1.10e+6
# Gf: 0.8
# length_scale_paramete: 1.75e-5
# 生成时间: 2025-02-25 13:02:57

# mpirun -n 10 /home/yp/projects/raccoon/raccoon-opt -i NoClad3D_quarter_ThermalCreepFracture_AllEigenstrainStaggered.i

pellet_density=10431.0#10431.0*0.85#kg⋅m-3
pellet_elastic_constants=2.0e11#Pa
pellet_nu = 0.345
pellet_thermal_expansion_coef=1.05e-5#K-1
pellet_K = '${fparse pellet_elastic_constants/3/(1-2*pellet_nu)}'
pellet_G = '${fparse pellet_elastic_constants/2/(1+pellet_nu)}'
Gf = 0.8 #断裂能
pellet_critical_fracture_strength=6.0e7#Pa
length_scale_paramete = 1.75e-5
pellet_critical_energy=${fparse Gf} #J⋅m-2

fission_rate = 2e19
grain_size = 10.0

#《《下面数据取自[1]Thermomechanical Analysis and Irradiation Test of Sintered Dual-Cooled Annular pellet》》

# 双冷却环形燃料几何参数 (单位：mm)(无内外包壳)
pellet_inner_diameter = 10.291         # 芯块内直径
pellet_outer_diameter = 14.627         # 芯块外直径
length = 6e-5                    # 轴向长度(m)
# 最大网格尺寸为6.0e-5m
n_radial_pellet = 36          # 燃料径向单元数
n_azimuthal = 768           # 周向基础单元数
growth_factor = 1.0        # 径向增长因子
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

[MultiApps]
  [fracture]
    type = TransientMultiApp
    input_files = 'sub_Gf0_8_le1_75e-5.i'
    cli_args = 'Gc=${pellet_critical_energy};l=${length_scale_paramete};E0=${pellet_elastic_constants}'
    execute_on = 'TIMESTEP_END'
    # 强制同步参数
    sub_cycling = false          # 禁止子循环
    catch_up = false             # 禁止追赶步
    max_failures = 0             # 严格同步模式
  []
[]

[Transfers]
  [from_d]
    type = MultiAppGeneralFieldShapeEvaluationTransfer
    from_multi_app = 'fracture'
    variable = d
    source_variable = d
  []
  [to_psie_active]
    type = MultiAppGeneralFieldShapeEvaluationTransfer
    to_multi_app = 'fracture'
    variable = psie_active
    source_variable = psie_active
  []
  [to_sigma0]
    type = MultiAppGeneralFieldShapeEvaluationTransfer
    to_multi_app = 'fracture'
    variable = sigma0_field
    source_variable = sigma0_field
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
  [./thermal_hoop_strain]
    order = CONSTANT
    family = MONOMIAL
  [../]
  [./creep_hoop_strain]
    order = CONSTANT
    family = MONOMIAL
  [../]
  [./swelling_hoop_strain]
    order = CONSTANT
    family = MONOMIAL
  [../]
  [./densification_hoop_strain]
    order = CONSTANT
    family = MONOMIAL
  [../]
  [vonMises]
    order = CONSTANT
    family = MONOMIAL
  []
  [d]
    block = pellet
  []

  [sigma0_field]
    family = MONOMIAL
    order = CONSTANT
    [InitialCondition]
      type = WeibullIC
      scale = ${pellet_critical_fracture_strength}
      shape = 50
      location = 0.0
      seed = 0
      block = pellet
    []
  []
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
    [./creep_strain]
      type = ADRankTwoAux
      variable = creep_hoop_strain
      rank_two_tensor = creep_eigenstrain
      index_i = 2
      index_j = 2  # zz分量对应环向
      execute_on = 'TIMESTEP_END'
      block = pellet
    [../]
    [./swelling_strain]
      type = ADRankTwoAux
      variable = swelling_hoop_strain
      rank_two_tensor = swelling_eigenstrain
      index_i = 2
      index_j = 2  # zz分量对应环向
      execute_on = 'TIMESTEP_END'
      block = pellet
    [../]
    [./densification_strain]
      type = ADRankTwoAux
      variable = densification_hoop_strain
      rank_two_tensor = densification_eigenstrain
      index_i = 2
      index_j = 2  # zz分量对应环向
      execute_on = 'TIMESTEP_END'
      block = pellet
    [../]
    [copy_sigma0]
      type = ADMaterialRealAux
      variable = sigma0_field
      property = sigma0
      execute_on = 'initial'
      block = pellet
    []
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
      initial_condition = 393.15
    []
    [x]
      initial_condition = 0.01
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
      type = ADMatHeatSource
      variable = T
      material_property = total_power
      block = pellet
    []
    #化学平衡方程
    [time_derivative]
      type = ADTimeDerivative
      variable = x
      block = pellet
    []
    [complex_diffusion]
      type = ADComplexDiffusionKernel
      variable = x
      temperature = T
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
    factor = 1.0e6
    function = gap_pressure
    use_displaced_mesh = true
  []
  [gap_pressure_fuel_y]
    type = Pressure
    variable = disp_y
    boundary = 'pellet_inner pellet_outer'
    factor = 1.0e6
    function = gap_pressure
    use_displaced_mesh = true
  []
  [coolant_bc]#对流边界条件
    type = ConvectiveFluxFunction
    variable = T
    boundary = 'pellet_inner pellet_outer'
    T_infinity = 393.15
    coefficient = gap_conductance#3500 W·m-2 K-1！！！！！！！！！！！！！！！！！！！！！！！！！！！
  []
  [x_0BC]
    type = NeumannBC
    variable = x
    boundary = 'pellet_inner pellet_outer x_axis y_axis'
    value = 0
  []
[]
[Materials]
    #定义芯块热导率、密度、比热等材料属性
    [pellet_properties2]
      type = ADGenericConstantMaterial
      prop_names = 'K G l Gc E0 density'
      prop_values = '${pellet_K} ${pellet_G} ${length_scale_paramete} ${pellet_critical_energy} ${pellet_elastic_constants} ${pellet_density}'
      block = pellet
    []
    # 为临界断裂强度生成威布尔分布
    [sigma0_mat]
      type = ADParsedMaterial
      property_name = sigma0
      coupled_variables = 'sigma0_field'
      expression = 'sigma0_field'  # 直接使用辅助变量的值
      block = pellet
    []
    [pellet_thermal_conductivity] #新加的！！！！！！！！！！！！！！！！！！！！！！
      type = ADParsedMaterial
      property_name = thermal_conductivity #参考某论文来的，不是Fink-Lukuta model（非常复杂）
      coupled_variables = 'T d'
      expression = '(100/(7.5408 + 17.692*T/1000 + 3.6142*(T/1000)^2) + 6400/((T/1000)^2.5)*exp(-16.35/(T/1000)))*(1-0.1*d)'
      block = pellet
    []
    [pellet_specific_heat]
      type = ADParsedMaterial
      property_name = specific_heat #Fink model
      coupled_variables = 'T x'  # 需要在AuxVariables中定义Y变量
      expression = '(296.7 * 535.285^2 * exp(535.285/T))/(T^2 * (exp(535.285/T) - 1)^2) + 2.43e-2 * T + (x+2) * 8.745e7 * 1.577e5 * exp(-1.577e5/(8.314*T))/(2 * 8.314 * T^2)'
      block = pellet
    []
    
    [total_power]
      type = ADDerivativeParsedMaterial
      property_name = total_power
      coupled_variables = 'd'  # 声明依赖的变量
      functor_names = 'power_history'  # 声明使用的函数
      functor_symbols = 'P'  # 为函数指定符号名称
      expression = 'P * (1-0.1*d)'  # 直接使用函数符号进行计算
      derivative_order = 1  # 需要计算导数时指定
      block = pellet
      output_properties = 'total_power'
      outputs = exodus
    []

    [pellet_thermal_eigenstrain]
      type = ADComputeThermalExpansionEigenstrain
      eigenstrain_name = thermal_eigenstrain
      stress_free_temperature = 393.15
      thermal_expansion_coeff = ${pellet_thermal_expansion_coef}
      temperature = T
      block = pellet
    []
    #定义燃耗（可以是常数或变量）
    [burnup]
      type = ADBurnupMaterial
      total_power = total_power
      initial_density = ${pellet_density}
      block = pellet
      output_properties = 'burnup'
      outputs = exodus
    []
    # 肿胀应变函数
    [swelling_coef]
      type = ADDerivativeParsedMaterial  # 改为ADParsedMaterial
      property_name = swelling_coef
      coupled_variables = 'T'
      material_property_names = 'burnup'
      expression = '(${pellet_density}*5.577e-5*(burnup*1) + 1.101e-29*pow(2800-T,11.73)*exp(-0.0162*(2800-T))*(1-exp(-0.0178*${pellet_density}*(burnup*1))))/3'
      block = pellet
    []
    [CD_factor]
      type = ADParsedMaterial
      property_name = CD_factor
      coupled_variables = 'T'
      expression = 'if(T < 1023.15, 7.2-0.0086*(T-298.15),1)'
      block = pellet
    []
    # 密实化温度因子函数
    [densification_coef]
      type = ADDerivativeParsedMaterial  # 改为ADParsedMaterial
      property_name = densification_coef
      coupled_variables = 'T'
      material_property_names = 'CD_factor burnup'
      expression = '0.001 * (exp(-4.605 * (burnup*1) / (CD_factor * 0.006024)) - 1)/3'# 0.6024是5000MWd/tU的转换系数
      block = pellet
    []
        # 肿胀应变计算
    [swelling_eigenstrain]
      type = ADComputeVariableFunctionEigenstrain
      eigen_base = '1 1 1 0 0 0'
      prefactor = swelling_coef
      eigenstrain_name = swelling_eigenstrain
      block = pellet
    [../]

    # 密实化应变计算
    [densification_eigenstrain]
      type = ADComputeVariableFunctionEigenstrain
      eigen_base = '1 1 1 0 0 0'
      prefactor = densification_coef
      eigenstrain_name = densification_eigenstrain
      block = pellet
    [../]

    #化学相关
    [D_fickian]
      type = ADParsedMaterial
      property_name = D_fickian
      coupled_variables = 'x T d'
      expression = '(1-0.9*d)*pow(10, -9.386 - 4260/(T) + 0.0012*T*x + 0.00075*T*log10(1+2/(x)))'
      block = pellet
    []
    [D_soret]
      type = ADDerivativeParsedMaterial
      property_name = D_soret
      coupled_variables = 'x T d'
      material_property_names = 'D_fickian(x,T,d)'
      expression = 'D_fickian * x * (-1380.8 - 134435.5*exp(-x/0.0261)) / ((2.0 + x)/(2.0 * (1.0 - 3.0*x) * (1.0 - 2.0*x)) * 8.314 * T * T)'
      block = pellet
    []
    # # # # 蠕变相关
  [creep_rate]
    type = UO2CreepRate
    temperature = T
    oxygen_ratio = x
    fission_rate = ${fission_rate}
    theoretical_density = 95.0
    grain_size = ${grain_size}
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
        eigenstrain_names = 'thermal_eigenstrain creep_eigenstrain swelling_eigenstrain densification_eigenstrain'
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
    [pellet_elasticity]
      type = SmallDeformationIsotropicElasticity
      bulk_modulus = K
      shear_modulus = G
      phase_field = d
      degradation_function = g
      decomposition = SPECTRAL
      output_properties = 'psie_active'
      outputs = exodus
      block = pellet
    []
    [pellet_stress]
      type = ComputeSmallDeformationStress
      elasticity_model = pellet_elasticity
      block = pellet
    []
[]
# 线密度转为体积密度的转换系数
power_factor = '${fparse 1000*1/3.1415926/(pellet_outer_radius^2-pellet_inner_radius^2)}' #新加的！！！！！！！！！！！！！！！！！！！！！！
[Functions]
  # [power_history] #新加的！！！！！！！！！！！！！！！！！！！！！！
  #   type = PiecewiseLinear #论文的功率历史
  #   x = '0          864000   6912000   8208000'
  #   y = '0.1          105     75     0'
  #   scale_factor = ${power_factor}         # 保持原有的转换因子
  #   # 论文中只给了线密度，需要化为体积密度
  # []
  [gap_pressure] #新加的！！！！！！！！！！！！！！！！！！！！！！
  #间隙压力随时间的变化
  type = PiecewiseLinear
  x = '0 1100000'
  y = '2.0 12'
  scale_factor = 1
  []
  [gap_conductance]
    type = PiecewiseLinear
    x = '0 1100000'
    y = '3500 3000'
    scale_factor = 1         # 保持原有的转换因子
  []
  [power_history] #新加的！！！！！！！！！！！！！！！！！！！！！！
  type = PiecewiseLinear #论文的功率历史
  x = '0 864000 950000 1000000   '
  y = '0 105 100 0'
  scale_factor = ${power_factor}         # 保持原有的转换因子
  # 论文中只给了线密度，需要化为体积密度
  []
  [dt_limit_func]
    type = ParsedFunction
    expression = 'if(t < 300000, 50000,
                   if(t < 950000,
                      if(abs(d_increment) < 1e-3, 20000,
                         if(abs(d_increment) < 5e-3, 10000,
                            if(abs(d_increment) < 1e-2, 5000,
                               if(abs(d_increment) < 5e-2, 2500,
                                  if(abs(d_increment) < 1e-1, 1000, 500)))))
                      ,
                      if(abs(d_increment) < 1e-3, 10000,
                         if(abs(d_increment) < 5e-3, 5000,
                            if(abs(d_increment) < 1e-2, 2500,
                               if(abs(d_increment) < 5e-2, 1000,
                                  if(abs(d_increment) < 1e-1, 500, 100)))))
                   ))'
    symbol_names = 'd_increment'
    symbol_values = 'd_increment'
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

[Executioner]
    type = Transient
    solve_type = 'PJFNK'
    petsc_options_iname = '-pc_type -pc_factor_mat_solver_package -ksp_type'
    petsc_options_value = 'lu superlu_dist gmres'
    accept_on_max_fixed_point_iteration = true # 达到最大迭代次数时接受解
    automatic_scaling = true # 启用自动缩放功能，有助于改善病态问题的收敛性
    compute_scaling_once = true  # 每个时间步都重新计算缩放
    nl_max_its = 30
    nl_rel_tol = 1e-6 # 非线性求解的相对容差
    nl_abs_tol = 1e-8 # 非线性求解的绝对容差
    l_tol = 1e-7  # 线性求解的容差
    l_abs_tol = 1e-9 # 线性求解的绝对容差
    l_max_its = 150 # 线性求解的最大迭代次数
    dtmin = 1
    end_time = 1100000

    [TimeStepper]
      type = FunctionDT
      function = dt_limit_func
    []
[]
[Outputs]
  [my_checkpoint]
    type = Checkpoint
    time_step_interval = 5    # 每5个时间步保存
    num_files = 4            # 保留最近4个检查点
    wall_time_interval = 600 # 每10分钟保存一次（秒）
  []
  exodus = true
[]