#复现一下Multiphysics phase-field modeling of quasi-static cracking in urania ceramic nuclear fuel
#提到的花岗岩基准问题，顺利复现
thermal_conductivity_dem=0.026#孔隙的导热系数W⋅m-1⋅K-1
density=2650.0#kg⋅m-3
thermal_conductivity=3.5#W⋅m-1⋅K-1
specific_heat=1015.0#J⋅kg-1⋅K-1
thermal_expansion_coef=5.0e-6#K-1
elastic_constants=6.0e10#Pa
critical_energy=16#J⋅m-2
length_scale_paramete=3e-3#m
# E = 2e5
nu = 0.25
K = '${fparse elastic_constants/3/(1-2*nu)}'
G = '${fparse elastic_constants/2/(1+nu)}'



[MultiApps]
  [fracture]
    type = TransientMultiApp
    input_files = 'fracture_random_0.0014.i'
    cli_args = 'Gc=${critical_energy};l=${length_scale_paramete};E0=${elastic_constants};'
    execute_on = 'TIMESTEP_END'
  []
[]

[Transfers]
  [from_d]
    type = MultiAppGeneralFieldShapeEvaluationTransfer
    # type = MultiAppCopyTransfer
    from_multi_app = 'fracture'
    variable = d
    source_variable = d
  []
  [to_psie_active]
    type = MultiAppGeneralFieldShapeEvaluationTransfer
    # type = MultiAppCopyTransfer
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
  displacements = 'disp_x disp_y'
[]
[Mesh]
  [fmg]
    type = FileMeshGenerator
    file = granite0.0014.e
    []
[]

[Variables]
  [disp_x]
  []
  [disp_y]
  []
  [T]
    initial_condition = 293.15
  []
[]

[AuxVariables]
  [d]
    # 确保相场变量有足够的阶数来计算梯度
    order = FIRST
    family = LAGRANGE
  []
  [sigma0_field]
    family = MONOMIAL
    order = CONSTANT
    [InitialCondition]
      type = WeibullIC
      scale = 6.2e6
      shape = 50
      location = 0.0
      seed = 0
    []
  []
  # 第一主应力
  [./principal_stress_1]
    order = CONSTANT
    family = MONOMIAL
  [../]
  [hoop_stress]
    order = CONSTANT
    family = MONOMIAL
  []
[]
[AuxKernels]
  [copy_sigma0]
    type = ADMaterialRealAux
    variable = sigma0_field
    property = sigma0
    execute_on = 'initial timestep_end'
  []
  [./principal_stress_1]
    type = ADRankTwoScalarAux
    variable = principal_stress_1
    rank_two_tensor = stress  # 使用计算得到的应力张量
    scalar_type = MaxPrincipal  # 提取最大主应力
    execute_on = 'TIMESTEP_END'
    # block = 1
  [../]
  [hoop_stress]
    type = ADRankTwoScalarAux
    variable = hoop_stress
    rank_two_tensor = stress
    scalar_type = HoopStress
    point1 = '0 0 0'
    point2 = '0 0 1'
    execute_on = 'TIMESTEP_END'
  []
[]


[BCs]
  [inner_surface]
    type = FunctionDirichletBC  # 改用 FunctionDirichletBC
    variable = T
    boundary = inner_surface
    function = inner_temp_func
  []
  [outer_surface]
      type = FunctionDirichletBC  # 改用 FunctionDirichletBC
      variable = T
      boundary = outer_surface
      function = outer_temp_func
  []

      [x_zero_on_y_axis]
    type = DirichletBC
    variable = disp_x
    boundary = y_axis
    value = 0
  []
  [y_zero_on_x_axis]
    type = DirichletBC
    variable = disp_y
    boundary = x_axis
    value = 0
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

  [hcond_time]
    type = ADHeatConductionTimeDerivative
    variable = T
  []
  [heat_conduction]
    type = ADHeatConduction
    variable = T
  []
[]



[Materials]
  #开始定义热导率、密度、比热等材料属性
      # 燃料芯块热传导性能

  [bulk_properties]
    type = ADGenericConstantMaterial
    prop_names = 'K G l Gc density E0 specific_heat'
    prop_values = '${K} ${G} ${length_scale_paramete} ${critical_energy} ${density} ${elastic_constants} ${specific_heat}'
  []
  # 为临界断裂强度生成威布尔分布
  [sigma0_mat]
    type = ADParsedMaterial
    property_name = sigma0
    coupled_variables = 'sigma0_field'
    expression = 'sigma0_field'  # 直接使用辅助变量的值
  []
  [thermal_conductivity]
    type = ADDerivativeParsedMaterial
    property_name = thermal_conductivity
    coupled_variables = 'd'
    expression =         '(1-d)*DD+d*DD1'
    constant_names       = 'DD DD1'
    constant_expressions = '${thermal_conductivity} ${thermal_conductivity_dem}' # 您之前定义的表达式
  []
  [degradation]
    type = RationalDegradationFunction
    property_name = g
    expression = (1-d)^p/((1-d)^p+(1.5*E0*Gc/sigma0^2)/l*d*(1+a2*d))*(1-eta)+eta
    phase_field = d
    material_property_names = 'Gc sigma0 l E0'
    parameter_names = 'p a2 eta'
    parameter_values = '2 2 1e-6'
  []
  [crack_geometric]
    type = CrackGeometricFunction
    property_name = alpha
    expression = '4*d'
    phase_field = d
  []
  # [degradation]
  #   type = RationalDegradationFunction
  #   property_name = g
  #   expression = (1-d)^p/((1-d)^p+(2*E0*Gc/sigma0^2)*(xi/c0/l)*d*(1+a2*d+a3*d^2))*(1-eta)+eta
  #   phase_field = d
  #   material_property_names = 'Gc sigma0 xi c0 l E0'
  #   parameter_names = 'p a2 a3 eta '
  #   parameter_values = '2 -0.5 0 1e-6'
  # []
  # [crack_geometric]
  #   type = CrackGeometricFunction
  #   property_name = alpha
  #   expression = '2*d-d*d'
  #   phase_field = d
  # []
  #定义应变相关的材料属性
  #第一个是热膨胀的应变
  [eigenstrain1]
    type = ADComputeThermalExpansionEigenstrain
    eigenstrain_name = thermal_eigenstrain
    #这个是热膨胀的温度，这个stress_free_temperature是指在这个温度下，材料是没有应力的
    stress_free_temperature = 293.15
    thermal_expansion_coeff = ${thermal_expansion_coef}
    temperature = T
  []


  [strain]
    type = ADComputeSmallStrain
        eigenstrain_names = thermal_eigenstrain
        # outputs = exodus
  []
  [elasticity]
    type = SmallDeformationSpectralElasticity  # 改用我们新实现的材料
    bulk_modulus = K
    shear_modulus = G
    phase_field = d
    degradation_function = g
    output_properties = 'psie_active'
    outputs = exodus
  []
  [stress]
    type = ComputeSmallDeformationStress
    elasticity_model = elasticity
    # output_properties = 'stress'
    # outputs = exodus
  []

  # 断裂能密度计算
  [crack_surface_density]
    type = CrackSurfaceDensity
    phase_field = d
    normalization_constant = c0  # 通常为2.0
    regularization_length = l
    crack_geometric_function = alpha
    crack_surface_density = gamma
  []
  #   # 断裂能计算
  # [fracture_energy_density]
  #     type = ADParsedMaterial
  #     property_name = fracture_energy
  #     coupled_variables = 'd'
  #     material_property_names = 'Gc gamma'  # 使用crack_surface_density计算的gamma
  #     expression = 'Gc * gamma'  # 断裂能 = Gc * gamma
  # []
[]



[Executioner]
  type = Transient

  # solve_type = NEWTON
  solve_type = PJFNK
  petsc_options_iname = '-pc_type -pc_factor_mat_solver_package'
  petsc_options_value = 'lu       superlu_dist                 '
  # -pc_type lu: 使用LU分解作为预处理器
  # -pc_factor_mat_solver_package superlu_dist: 使用分布式SuperLU作为矩阵求解器

  automatic_scaling = true # 启用自动缩放功能，有助于改善病态问题的收敛性
  compute_scaling_once = true  # 每个时间步都重新计算缩放

  nl_max_its = 20
  nl_rel_tol = 1e-7 # 非线性求解的相对容差
  nl_abs_tol = 5e-8 # 非线性求解的绝对容差
  l_tol = 1e-7  # 线性求解的容差
  l_max_its = 20 # 线性求解的最大迭代次数

  end_time = 5000 # 模拟的结束时间

  fixed_point_max_its =8# 最大固定点迭代次数
  accept_on_max_fixed_point_iteration = true # 达到最大迭代次数时接受解
  fixed_point_rel_tol = 1e-5 # 固定点迭代的相对容差
  fixed_point_abs_tol = 1e-6 # 固定点迭代的绝对容差

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
  # # 计算整个域的总弹性应变能
  # [total_elastic_energy]
  #   type = ADElementIntegralMaterialProperty
  #   mat_prop = psie  # 从elasticity材料中获取的活性弹性应变能
  #   execute_on = 'TIMESTEP_END'
  # []
  # # 计算整个域的总断裂能
  # [total_fracture_energy]
  #   type = ADElementIntegralMaterialProperty
  #   mat_prop = fracture_energy
  #   execute_on = 'TIMESTEP_END'
  # []
[]

[VectorPostprocessors]
  [sigma0_dist]
    type = ElementValueSampler
    variable = sigma0_field
    sort_by = id
    execute_on = 'INITIAL'  # 只在初始时刻统计
  []
[]

[Functions]
  [dt_limit_func]
    type = ParsedFunction
    expression = 'if(abs(d_increment) < 5e-4, 50, 
                       if(abs(d_increment) < 1e-3,10, 
                         if(abs(d_increment) < 5e-3, 1, 
                           if(abs(d_increment) < 1e-2, 0.1, 
                             if(abs(d_increment) < 5e-2, 0.01, 
                               if(abs(d_increment) < 1e-1, 0.001, 0.0001))))))'
    symbol_names = 'd_increment'
    symbol_values = 'd_increment'
  []
  [inner_temp_func]
    type = ParsedFunction
    expression = '296.3651116313752 + (393.4266861626193 - 296.3651116313752) * (1 - exp(-0.004908803340257075 * t))'
[]
[outer_temp_func]
    type = ParsedFunction
    expression = '293.1781642369561 + (319.99999999999994 - 293.1781642369561) * (1 - exp(-0.0006710717453973476 * t))'
[]
[]

[Outputs]
  execute_on = 'INITIAL TIMESTEP_END'
  exodus = true
  print_linear_residuals = false
  checkpoint = false        
  file_base = 'PF_CZM_2_a4d_${length_scale_paramete}'
#   [csv] # 添加CSV输出，为了输出断裂韧度分布
#     type = CSV
#     file_base = energy_evolution
#  show = 'total_elastic_energy total_fracture_energy'
#   []
[]
