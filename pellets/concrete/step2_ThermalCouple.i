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
    [clad_stress]
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
  expression = '1+t/86400'
[]
[]
[Executioner]
    type = Transient
    solve_type = 'PJFNK'
    petsc_options_iname = '-pc_type -pc_hypre_type'
    petsc_options_value = 'hypre boomeramg'
    dt = 3600
    end_time = 86400
  []
[Outputs]
  exodus = true
[]