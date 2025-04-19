# mpirun -n 16 /home/yp/projects/raccoon/raccoon-opt -i NoClad3D_ThermallFractureStaggered.i

pellet_density=10431.0#10431.0*0.85#kg⋅m-3
pellet_elastic_constants=2.2e11#Pa
pellet_nu = 0.345
# pellet_specific_heat=300
# pellet_thermal_conductivity = 5
pellet_thermal_expansion_coef=1e-5#K-1
pellet_K = '${fparse pellet_elastic_constants/3/(1-2*pellet_nu)}'
pellet_G = '${fparse pellet_elastic_constants/2/(1+pellet_nu)}'
Gf = 3 #断裂能
pellet_critical_fracture_strength=6.0e7#Pa
length_scale_paramete=6e-5
pellet_critical_energy=${fparse Gf} #J⋅m-2

#《《下面数据取自[1]Thermomechanical Analysis and Irradiation Test of Sintered Dual-Cooled Annular pellet》》

# 双冷却环形燃料几何参数 (单位：mm)(无内外包壳)
pellet_inner_diameter = 10.291         # 芯块内直径mm
pellet_outer_diameter = 14.627         # 芯块外直径mm
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

[MultiApps]
  [fracture]
    type = TransientMultiApp
    input_files = 'NoClad3D_ThermallFractureStaggered_SubApp.i'
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
  [./mechanical_hoop_strain]
    order = CONSTANT
    family = MONOMIAL
  [../]
  [./total_hoop_strain]
    order = CONSTANT
    family = MONOMIAL
  [../]
  [d]
    block = pellet
  []
  [x]
    block = pellet
    initial_condition = 0.01
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
    type = ADRankTwoScalarAux
    variable = thermal_hoop_strain
    rank_two_tensor = thermal_eigenstrain
    scalar_type = HoopStress
    point1 = '0 0 0'        # 圆心坐标
    point2 = '0 0 -0.0178'        # 定义旋转轴方向（z轴）
    execute_on = 'TIMESTEP_END'
  [../]
    [./mechanical_strain]
      type = ADRankTwoScalarAux
      variable = mechanical_hoop_strain
      rank_two_tensor = mechanical_strain
      scalar_type = HoopStress
      point1 = '0 0 0'        # 圆心坐标
      point2 = '0 0 -0.0178'        # 定义旋转轴方向（z轴）
      execute_on = 'TIMESTEP_END'
    [../]
    [./total_strain]
      type = ADRankTwoScalarAux
      variable = total_hoop_strain
      rank_two_tensor = total_strain
      scalar_type = HoopStress
      point1 = '0 0 0'
      point2 = '0 0 -0.0178'
      execute_on = 'TIMESTEP_END'
    [../]
      [copy_sigma0]
        type = ADMaterialRealAux
        variable = sigma0_field
        property = sigma0
        execute_on = 'initial'
        block = pellet
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
    factor = 2.0e6
    use_displaced_mesh = true
  []
  [gap_pressure_fuel_y]
    type = Pressure
    variable = disp_y
    boundary = 'pellet_inner pellet_outer'
    factor = 2.0e6
    use_displaced_mesh = true
  []
  [coolant_bc]#对流边界条件
    type = ConvectiveFluxFunction
    variable = T
    boundary = 'pellet_inner pellet_outer'
    T_infinity = 393.15
    coefficient = gap_conductance#3500 W·m-2 K-1！！！！！！！！！！！！！！！！！！！！！！！！！！！
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
    [total_power]
      type = ADDerivativeParsedMaterial
      property_name = total_power
      coupled_variables = 'd'  # 声明依赖的变量
      functor_names = 'power_history'  # 声明使用的函数
      functor_symbols = 'P'  # 为函数指定符号名称
      expression = 'P * (1-d)'  # 直接使用函数符号进行计算
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
    [pellet_strain]
        type = ADComputeSmallStrain 
        eigenstrain_names = 'thermal_eigenstrain'
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
  [gap_conductance]
    type = PiecewiseLinear
    x = '0 1000000'
    y = '3500 2000'
    scale_factor = 1         # 保持原有的转换因子
  []
  [power_history] #新加的！！！！！！！！！！！！！！！！！！！！！！
  type = PiecewiseLinear #论文的功率历史
  x = '0          864000   1000000'
  y = '0.1          105     0'
  scale_factor = ${power_factor}         # 保持原有的转换因子
  # 论文中只给了线密度，需要化为体积密度
  []
  [dt_limit_func]
    type = ParsedFunction
    expression = 'if(t < 0.2, 0.1,
                   if(t < 864000,
                      if(abs(d_increment) < 1e-3, 100000,
                         if(abs(d_increment) < 5e-3, 50000,
                            if(abs(d_increment) < 1e-2, 20000,
                               if(abs(d_increment) < 5e-2, 10000,
                                  if(abs(d_increment) < 1e-1, 5000, 1000)))))
                      ,
                      if(abs(d_increment) < 1e-3, 25000,
                         if(abs(d_increment) < 5e-3, 10000,
                            if(abs(d_increment) < 1e-2, 5000,
                               if(abs(d_increment) < 5e-2, 2500,
                                  if(abs(d_increment) < 1e-1, 1000, 500)))))
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
    nl_rel_tol = 1e-5 # 非线性求解的相对容差
    nl_abs_tol = 1e-8 # 非线性求解的绝对容差
    l_tol = 1e-6  # 线性求解的容差
    l_abs_tol = 1e-9 # 线性求解的绝对容差
    l_max_its = 150 # 线性求解的最大迭代次数
    dtmin = 1
    end_time = 1000000

    [TimeStepper]
      type = FunctionDT
      function = dt_limit_func
    []
[]
[Outputs]
  exodus = true
[]