#这一步的目的是计算燃料棒的应力分布
#这一步加入中子相关的参数，包括燃耗，辐照密实化应变，肿胀应变
#功率函数逐渐接近真实的功率时间函数

pellet_density=10431.0#10431.0*0.85#kg⋅m-3
pellet_elastic_constants=2.2e11#Pa
pellet_nu = 0.345
pellet_specific_heat=300
pellet_thermal_conductivity = 5
pellet_thermal_expansion_coef=1e-5#K-1

clad_density=6.59e3#kg⋅m-3
clad_elastic_constants=7.52e10#Pa
clad_nu = 0.33
clad_specific_heat=264.5
clad_thermal_conductivity = 16
clad_thermal_expansion_coef=5.0e-6#K-1

[Mesh]
    file = 'Oconee_Rod_15309.e'
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
  # 各种应变
  # 热应变
  [./thermal_hoop_strain]
    order = CONSTANT
    family = MONOMIAL
  [../] 
  # 辐照密实化应变
  [./densification_hoop_strain]
    order = CONSTANT
    family = MONOMIAL
  [../]
  # 肿胀应变
  [./swelling_hoop_strain]
    order = CONSTANT
    family = MONOMIAL
  [../]
  # 弹性应变
  [./mechanical_hoop_strain]
    order = CONSTANT
    family = MONOMIAL
  [../]
  # 总应变
  [./total_hoop_strain]
    order = CONSTANT
    family = MONOMIAL
  [../]
  # 燃耗
  [./burnup]
    order = CONSTANT
    family = MONOMIAL
  [../]
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
  [./densification_strain]
    type = ADRankTwoAux
    variable = densification_hoop_strain
    rank_two_tensor = densification_eigenstrain
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
    index_j = 2
    execute_on = 'TIMESTEP_END'
    block = pellet
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
  # 燃耗
  [./burnup]
    type = ADMaterialRealAux
    variable = burnup
    property = burnup
    execute_on = 'INITIAL TIMESTEP_END'
    block = pellet
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
      function = power_history
      block = pellet
    []
[]
[BCs]
  #固定平面
  [x_zero_on_y_axis]
    type = DirichletBC
    variable = disp_y
    boundary = 'yplane'
    value = 0
  []
  [y_zero_on_x_axis]
    type = DirichletBC
    variable = disp_x
    boundary = 'xplane'
    value = 0
  []
  [z_zero_on_bottom]
    type = DirichletBC
    variable = disp_z
    boundary = 'bottom top'
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
      function = gap_pressure
      use_displaced_mesh = true
    []
    [gap_pressure_fuel_y]
      type = Pressure
      variable = disp_y
      boundary = 'clad_inner pellet_outer'
      factor = 2.5e6
      function = gap_pressure
      use_displaced_mesh = true
  []
  #热相关边界条件
  [ADNeumannBC0]
    type = ADNeumannBC
    variable = T
    boundary = 'yplane xplane'
    value = 0
  []
  [coolant_bc]#对流边界条件
    type = DirichletBC
    variable = T
    boundary = clad_outer
    value = 500
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
    #定义燃耗（可以是常数或变量）
    [burnup]
      type = ADBurnupMaterial
      power_density = power_history  # 使用定义的功率历史函数
      initial_density = ${pellet_density}
      block = pellet
    []
    #特征应变的加入
    [pellet_thermal_eigenstrain]
      type = ADComputeThermalExpansionEigenstrain
      eigenstrain_name = thermal_eigenstrain
      stress_free_temperature = 500
      thermal_expansion_coeff = ${pellet_thermal_expansion_coef}
      temperature = T
      block = pellet
    []
        # 肿胀应变函数
    [swelling_coef]
      type = ADDerivativeParsedMaterial  # 改为ADParsedMaterial
      property_name = swelling_coef
      coupled_variables = 'T'
      material_property_names = 'burnup'
      expression = '(${pellet_density}*5.577e-5*burnup + 1.101e-29*pow(2800-T,11.73)*exp(-0.0162*(2800-T))*(1-exp(-0.0178*${pellet_density}*burnup)))/3'
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
      expression = '0.04 * (exp(-4.605 * burnup / (CD_factor * 0.006024)) - 1)/3'# 0.6024是5000MWd/tU的转换系数
      block = pellet
    []
        # 肿胀应变计算
    [swelling_eigenstrain]
      type = ADComputeVariableEigenstrain
      eigen_base = '1 1 1 0 0 0'
      prefactor = swelling_coef
      eigenstrain_name = swelling_eigenstrain
      block = pellet
    [../]

    # 密实化应变计算
    [densification_eigenstrain]
      type = ADComputeVariableEigenstrain
      eigen_base = '1 1 1 0 0 0'
      prefactor = densification_coef
      eigenstrain_name = densification_eigenstrain
      block = pellet
    [../]
    [pellet_strain]
        type = ADComputeSmallStrain 
        eigenstrain_names = 'thermal_eigenstrain swelling_eigenstrain densification_eigenstrain'
        output_properties = '_total_strain'
        outputs = exodus
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
    emissivity_primary =1
    emissivity_secondary =1
    gap_conductivity = 51
    quadrature = true
    gap_geometry_type = CYLINDER
    cylinder_axis_point_1 = '0 0 0'
    cylinder_axis_point_2 = '0 0 0.0001'
  [../]
[]
[Functions]
[gap_pressure]
  type = ParsedFunction
  expression = '1+5*t/86400'
[]
[power_history]
  type = PiecewiseLinear
  data_file = power_history.csv    # 创建一个包含上述数据的CSV文件，数据为<s,w/m>
  format = columns                 # 指定数据格式为列式
  scale_factor = 1.1166e7         # 保持原有的转换因子
[]
[]
[Executioner]
    type = Transient
    solve_type = 'PJFNK'
    petsc_options_iname = '-pc_type -pc_hypre_type'
    petsc_options_value = 'hypre boomeramg'
    dtmin = 3600
    dtmax = 864000
    end_time =6.912e79
    automatic_scaling = true # 启用自动缩放功能，有助于改善病态问题的收敛性
    compute_scaling_once = true  # 每个时间步都重新计算缩放
    nl_max_its = 5
    nl_rel_tol = 5e-9 # 非线性求解的相对容差
    nl_abs_tol = 5e-9 # 非线性求解的绝对容差
    l_tol = 5e-8  # 线性求解的容差
    l_max_its = 500 # 线性求解的最大迭代次数
    accept_on_max_fixed_point_iteration = true # 达到最大迭代次数时接受解
    [TimeStepper]
      type = IterationAdaptiveDT
      dt = 3600
      growth_factor = 2  # 时间步长增长因子
      cutback_factor = 0.5 # 时间步长缩减因子
      optimal_iterations = 8 # 期望的非线性迭代次数
    []
  []
[Outputs]
  exodus = true
[]