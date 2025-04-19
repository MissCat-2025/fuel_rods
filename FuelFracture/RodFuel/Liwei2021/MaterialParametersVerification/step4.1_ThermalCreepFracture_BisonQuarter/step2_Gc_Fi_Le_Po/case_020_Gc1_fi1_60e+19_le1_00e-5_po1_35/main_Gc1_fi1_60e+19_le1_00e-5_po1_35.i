# === 参数研究案例 ===
# end_time = 3.00e+5
# Gc: 1
# fission_rate: 1.60e+19
# length_scale_paramet: 1.00e-5
# power_factor_mod: 1.35
# 生成时间: 2025-04-03 00:10:57

# mpirun -n 12 /home/yp/projects/raccoon/raccoon-opt -i NoClad3D_ThermalCreepFracture.i
# mpirun -n 12 /home/yp/projects/raccoon/raccoon-opt -i NoClad3D_ThermalCreepFracture.i --mesh-only KAERI_HANARO_UpperRod1.e
pellet_density=10431.0#10431.0*0.85#kg⋅m-3
pellet_nu = 0.316
pellet_thermal_expansion_coef=1e-5#K-1
Gc = 1 #断裂能
pellet_critical_fracture_strength=6.0e7#Pa
length_scale_paramete=2e-5
grid_sizes = 8e-5 #mm,最大网格尺寸
fission_rate = 1.60e+19
power_factor_mod = 1.35
# 各种参数都取自[1]Multiphysics phase-field modeling of quasi-static cracking in urania ceramic nuclear fuel
#几何与网格参数
pellet_outer_radius = 4.1e-3#直径变半径，并且单位变mm
length = 4.75e-5 # 芯块长度17.78mm
n_elems_axial = 1 # 轴向网格数
#将下列参数转化为整数
n_elems_azimuthal = '${fparse 2*ceil(3.1415*2*(pellet_outer_radius/(4*grid_sizes)/2))}'  # 周向网格数（向上取整）
n_elems_radial_pellet = '${fparse int(pellet_outer_radius/(4*grid_sizes))}'          # 芯块径向网格数（直接取整）
pellet_critical_energy=${fparse Gc} #J⋅m-2

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


[MultiApps]
  [fracture]
    type = TransientMultiApp
    input_files = 'sub_Gc1_fi1_60e+19_le1_00e-5_po1_35.i'
    cli_args = 'Gc=${pellet_critical_energy};l=${length_scale_paramete}'
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
  [to_ALL]
    type = MultiAppGeneralFieldShapeEvaluationTransfer
    to_multi_app = 'fracture'
    variable = 'psie_active a1'
    source_variable = 'psie_active a1'
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
  [./hoop_stress]
    type = ADRankTwoScalarAux
    variable = hoop_stress
    rank_two_tensor = stress
    scalar_type = HoopStress
    point1 = '0 0 0'        # 圆心坐标
    point2 = '0 0 -0.0178'        # 定义旋转轴方向（z轴）
    execute_on = 'TIMESTEP_END'
  [../]
    [copy_sigma0]
      type = ADMaterialRealAux
      variable = sigma0_field
      property = sigma0
      execute_on = 'initial'
      block = pellet
    []
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
  # #芯块包壳间隙压力边界条件
  # [gap_pressure_fuel_x]
  #   type = Pressure
  #   variable = disp_x
  #   boundary = 'pellet_outer'
  #   factor = 1e6 # 间隙压力2.5MPa
  #   function = gap_pressure #新加的！！！！！！！！！！！！！！！！！！！！！！
  #   use_displaced_mesh = true
  # []
  # [gap_pressure_fuel_y]
  #   type = Pressure
  #   variable = disp_y
  #   boundary = 'pellet_outer'
  #   factor = 1e6
  #   function = gap_pressure #新加的！！！！！！！！！！！！！！！！！！！！！！
  #   use_displaced_mesh = true
  # []
  [T_0BC]
    type = NeumannBC
    variable = T
    boundary = 'xplane yplane'
    value = 0
  []
  [coolant_bc]#对流边界条件
    type = ConvectiveFluxFunction
    variable = T
    boundary = 'pellet_outer'
    T_infinity = 500
    coefficient = gap_conductance#3500 W·m-2 K-1！！！！！！！！！！！！！！！！！！！！！！！！！！！
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
      prop_names = 'l Gc density nu'
      prop_values = '${length_scale_paramete} ${pellet_critical_energy} ${pellet_density} ${pellet_nu}'
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
    property_name = thermal_conductivity
    coupled_variables = 'T'
    expression = '(100/(7.5408 + 17.692*T/1000 + 3.6142*(T/1000)^2) + 6400/((T/1000)^2.5)*exp(-16.35/(T/1000)))'
    block = pellet
    []
    [pellet_specific_heat]
      type = ADParsedMaterial
      property_name = specific_heat #Fink model
      coupled_variables = 'T x'  # 需要在AuxVariables中定义Y变量
      expression = '(296.7 * 535.285^2 * exp(535.285/T))/(T^2 * (exp(535.285/T) - 1)^2) + 2.43e-2 * T + (x+2) * 8.745e7 * 1.577e5 * exp(-1.577e5/(8.314*T))/(2 * 8.314 * T^2)'
      block = pellet
    []
    [pellet_elastic_constants]
      type = ADParsedMaterial
      property_name = E #Fink model
      coupled_variables = 'T'  # 需要在AuxVariables中定义Y变量
      expression = '210.0e9*(1.0-1.0915e-4*T*0)'
      block = pellet
    []
    [total_power]
      type = ADDerivativeParsedMaterial
      property_name = total_power
      coupled_variables = 'd'  # 声明依赖的变量
      functor_names = 'power_history'  # 声明使用的函数
      functor_symbols = 'P'  # 为函数指定符号名称
      expression = 'P * (1-0.001*d)'  # 直接使用函数符号进行计算
      derivative_order = 1  # 需要计算导数时指定
      block = pellet
      output_properties = 'total_power'
      outputs = exodus
    []

    [pellet_thermal_eigenstrain]
      type = ADComputeThermalExpansionEigenstrain
      eigenstrain_name = thermal_eigenstrain
      stress_free_temperature = 500
      thermal_expansion_coeff = ${pellet_thermal_expansion_coef}
      temperature = T
      block = pellet
    []

    #化学相关
    [D_fickian]
      type = ADParsedMaterial
      property_name = D_fickian
      coupled_variables = 'x T d'
      expression = '(1-0.99*d)*pow(10, -9.386 - 4260/(T) + 0.0012*T*x + 0.00075*T*log10(1+2/(x)))'
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
    fission_rate = ${fparse fission_rate}
    theoretical_density = 95.0
    grain_size = 10.0
    vonMisesStress = vonMises
    consider_transient_creep = false
    block = pellet
    []
    # 蠕变特征应变
    [creep_eigenstrain]
      type = ADComputeUO2CreepEigenstrain
      eigenstrain_name = creep_eigenstrain
      # output_properties = 'psip_active'
      # outputs = exodus
      block = pellet
    []
    #力学属性
    [pellet_strain]
    type = ADComputeSmallStrain
    eigenstrain_names = 'thermal_eigenstrain creep_eigenstrain'
    block = pellet
    []

    # [a1]
    #   type = ADDerivativeParsedMaterial
    #   property_name = a1
    #   material_property_names = 'Gc E l sigma0'
    #   expression = '1.5*E*Gc/sigma0/sigma0/l'
    #   output_properties = 'a1'
    #   outputs = exodus
    #   block = pellet
    # []
    [a1]
      type = ADDerivativeParsedMaterial
      property_name = a1
      material_property_names = 'Gc E l sigma0'
      expression = '4*E*Gc/sigma0/sigma0/3.14159/l'
      output_properties = 'a1'
      outputs = exodus
      block = pellet
    []
    [crack_geometric]
      type = CrackGeometricFunction
      property_name = alpha
      expression = 'd'
      phase_field = d
      block = pellet
    []

    [degradation]
      type = RationalDegradationFunction
      property_name = g
      expression = (1-d)^p/((1-d)^p+a1*d*(1+a2*d))*(1-eta)+eta
      phase_field = d
      material_property_names = 'a1'
      parameter_names = 'p a2 eta'
      parameter_values = '2 -0.5 1e-6'
      block = pellet
    []
    # [pellet_elasticity]
    #   type = SmallDeformationIsotropicElasticity
    #   bulk_modulus = K
    #   shear_modulus = G
    #   phase_field = d
    #   degradation_function = g
    #   decomposition = SPECTRAL
    #   output_properties = 'psie_active'
    #   outputs = exodus
    #   block = pellet
    # []
      [pellet_elasticity]
      type = SmallDeformationHBasedElasticity
      youngs_modulus = E
      poissons_ratio = nu
      tensile_strength = sigma0
      fracture_energy = Gc
      phase_field = d
      degradation_function = g
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
power_factor = '${fparse 1000*1/3.1415926/pellet_outer_radius/pellet_outer_radius/power_factor_mod}' #新加的！！！！！！！！！！！！！！！！！！！！！！
[Functions]
  [power_history] #新加的！！！！！！！！！！！！！！！！！！！！！！
    type = PiecewiseLinear
    x = '0.0 100000 125000 175000 300000'
    y = '0.0 18.0 35.0 35.0 0.0'
    scale_factor = ${power_factor}
  []
  [gap_conductance]
    type = PiecewiseLinear
    x = '0 300000'
    y = '3400 3300'
    scale_factor = 1         # 保持原有的转换因子
  []
  # [gap_pressure] #新加的！！！！！！！！！！！！！！！！！！！！！！
  #   #间隙压力随时间的变化
  #   type = PiecewiseLinear
  #   x = '0          125000   175000   300000'
  #   y = '2.5  6  10  14'
  #   scale_factor = 1
  # []
  [dt_limit_func]
    type = ParsedFunction
    expression = 'if(t < 50000, 10000,
                   if(t < 100000, 2000,
                   if(t < 125000, 2000,
                   if(t < 175000, 10000,2000))))'
  []
[]

[Executioner]
  type = Transient # 瞬态求解器
  solve_type = 'NEWTON' #求解器，PJFNK是预处理雅可比自由牛顿-克雷洛夫方法
  petsc_options_iname = '-pc_type -pc_factor_mat_solver_package -ksp_type'
  petsc_options_value = 'lu superlu_dist gmres'

  automatic_scaling = true # 启用自动缩放功能，有助于改善病态问题的收敛性
  compute_scaling_once = true  # 每个时间步都重新计算缩放
  nl_max_its = 30
  nl_rel_tol = 1e-6 # 非线性求解的相对容差
  nl_abs_tol = 1e-7 # 非线性求解的绝对容差
  l_tol = 1e-7  # 线性求解的容差
  l_abs_tol = 1e-8 # 线性求解的绝对容差
  l_max_its = 150 # 线性求解的最大迭代次数
  accept_on_max_fixed_point_iteration = true # 达到最大迭代次数时接受解
  dtmin = 500
  end_time = 3e5 # 总时间24h

  fixed_point_rel_tol =1e-4 # 固定点迭代的相对容差
  [TimeStepper]
    type = FunctionDT
    function = dt_limit_func
  []
[]

[Outputs]
  [my_checkpoint]
    type = Checkpoint
    time_step_interval = 5    # 每5个时间步保存
    num_files = 2            # 保留最近4个检查点
    wall_time_interval = 600 # 每10分钟保存一次（秒）
  []
  exodus = true #表示输出exodus格式文件
  print_linear_residuals = false
[]
