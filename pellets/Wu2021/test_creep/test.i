#这一步的目的是计算燃料棒的应力分布
#这一步加入蠕变，蠕变与氧超化学计量UO2+x有关。
#氧超化学计量需要多加入一个控制方程，即氧扩散方程，参考文献
#《[1] WEI LI, KOROUSH SHIRVAN. Multiphysics phase-field modeling of quasi-static cracking in urania ceramic nuclear fuel[J/OL]. Ceramics International, 2021, 47(1): 793-810. DOI:10.1016/j.ceramint.2020.08.191.》

pellet_density=10431.0#10431.0*0.85#kg⋅m-3
pellet_elastic_constants=2.2e11#Pa
pellet_nu = 0.345

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
  [./creep_hoop_strain]
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
  [./creep_strain]
    type = ADRankTwoAux
    variable = creep_hoop_strain
    rank_two_tensor = creep_eigenstrain
    index_i = 2
    index_j = 2  # zz分量对应环向
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
    [x]
      initial_condition = 0.01
      scaling = 1e2
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
      prop_names = 'density'
      prop_values = '${pellet_density}'
      block = pellet
    []
    # 然后定义总功率材料
    [total_power]
      type = ADTotalPowerMaterial
      power_history = power_history
      burnup = burnup
      pellet_radius = 0.0046609
      block = pellet
    []
    #定义燃耗（可以是常数或变量）
    [burnup]
      type = ADBurnupMaterial
      total_power = total_power
      initial_density = ${pellet_density}
      block = pellet
    []
  [pellet_thermal_conductivity]
    type = ADParsedMaterial
    property_name = thermal_conductivity
    coupled_variables = 'T'
    expression = '100/(7.5408 + 17.692*T/1000 + 3.6142*(T/1000)^2) + 6400/((T/1000)^2.5)*exp(-16.35/(T/1000))'
    block = pellet
  []

  [pellet_specific_heat]
    type = ADParsedMaterial
    property_name = specific_heat
    coupled_variables = 'T'
    expression = '52.1743 + 87.951*T/1000 - 84.2411*(T/1000)^2 + 31.542*(T/1000)^3 - 2.6334*(T/1000)^4 - 0.71391*(T/1000)^(-2)'
    block = pellet
  []
    #特征应变的加入
    #热应变
    [pellet_thermal_eigenstrain]
      type = ADComputeDilatationThermalExpansionFunctionEigenstrain
      dilatation_function = ThermalExpansionFunction    # 使用上面定义的函数
      stress_free_temperature = 500        # 参考温度
      temperature = T                         # 温度变量
      eigenstrain_name = thermal_eigenstrain  # 改用统一的命名
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
  # 蠕变相关
  [creep_rate]
    type = UO2CreepRate
    temperature = T
    oxygen_ratio = x
    fission_rate = 5e19
    theoretical_density = 95.0
    grain_size = 20.0
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
        eigenstrain_names = 'thermal_eigenstrain swelling_eigenstrain densification_eigenstrain creep_eigenstrain'
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
    emissivity_primary =0.8
    emissivity_secondary =0.8
    gap_conductivity = 0.2
    quadrature = true
    gap_geometry_type = CYLINDER
    cylinder_axis_point_1 = '0 0 0'
    cylinder_axis_point_2 = '0 0 0.0001'
  [../]
[]
[Functions]
  [gap_pressure]
    type = ParsedFunction
    expression = '1+5*t/6.912e7'
  []
  [power_history]
    type = PiecewiseLinear
    data_file = power_history.csv    # 创建一个包含上述数据的CSV文件，数据为<s,w/m>
    format = columns                 # 指定数据格式为列式
    scale_factor = 1.1166e7         # 保持原有的转换因子
  []
  [ThermalExpansionFunction]
    type = ParsedFunction
    expression = '(-4.972e-4 + 7.107e-6*t + 2.581e-9*t*t + 1.14e-13*t*t*t)'
   []
[]
[Executioner]
  type = Transient
  solve_type = 'PJFNK'
  petsc_options_iname = '-pc_type -pc_hypre_type -ksp_gmres_restart -pc_hypre_boomeramg_strong_threshold'
  petsc_options_value = 'hypre boomeramg 201 0.7'
  line_search = 'none'
  
  nl_rel_tol = 1e-6
  nl_abs_tol = 1e-8
  nl_max_its = 15
  
  l_max_its = 100
  l_tol = 1e-4
  
  start_time = 0.0
  end_time = 6.912e7
  dtmax = 43200
  
  [TimeStepper]
    type = IterationAdaptiveDT
    dt = 3600
    growth_factor = 1.5
    cutback_factor = 0.5
    optimal_iterations = 8
    iteration_window = 2
  []
  
  [Predictor]
    type = SimplePredictor
    scale = 1.0
  []
[]

[Postprocessors]
  [max_temp]
    type = ElementExtremeValue
    variable = T
    value_type = max
  []
  [min_temp]
    type = ElementExtremeValue
    variable = T
    value_type = min
  []
  [max_x]
    type = ElementExtremeValue
    variable = x
    value_type = max
    block = pellet
  []
  [min_x] 
    type = ElementExtremeValue
    variable = x
    value_type = min
    block = pellet
  []
  [avg_creep_rate]
    type = ElementAverageValue
    variable = creep_hoop_strain
    block = pellet
  []
[]

[Outputs]
  exodus = true
  csv = true
  [Console]
    type = Console
    max_rows = 10
    fit_mode = off
  []
[]