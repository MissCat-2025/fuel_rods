# 各种参数都取自[1]Multiphysics phase-field modeling of quasi-static cracking in urania ceramic nuclear fuel

#几何与网格参数
pellet_outer_radius = 4.1e-3#直径变半径，并且单位变mm
clad_inner_radius = 4.18e-3#直径变半径，并且单位变mm
clad_outer_radius = 4.78e-3#直径变半径，并且单位变mm
length = 0.1e-3 # 芯块长度17.78mm
n_elems_axial = 1 # 轴向网格数
n_elems_azimuthal = 100 # 周向网格数
n_elems_radial_clad = 4 # 包壳径向网格数
n_elems_radial_pellet = 20 # 芯块径向网格数

[Mesh]
  [pellet_clad_gap]
    type = ConcentricCircleMeshGenerator
    num_sectors = '${n_elems_azimuthal}'
    radii = '${pellet_outer_radius} ${clad_inner_radius} ${clad_outer_radius}'
    rings = '${n_elems_radial_pellet} 1 ${n_elems_radial_clad}'
    has_outer_square = false
    preserve_volumes = true
    smoothing_max_it = 10
  []
  [rename_pellet_outer_bdy]
    type = SideSetsBetweenSubdomainsGenerator
    input = pellet_clad_gap
    primary_block = 1
    paired_block = 2
    new_boundary = 'pellet_outer'
  []
  [rename_clad_inner_bdy]
    type = SideSetsBetweenSubdomainsGenerator
    input = rename_pellet_outer_bdy
    primary_block = 3
    paired_block = 2
    new_boundary = 'clad_inner'
  []
  [2d_mesh]
    type = BlockDeletionGenerator
    input = rename_clad_inner_bdy
    block = 2
  []
  [rename_outer]
    type = RenameBoundaryGenerator
    input = 2d_mesh
    old_boundary = 'outer'
    new_boundary = 'clad_outer'
  []
  [extrude]
    type = MeshExtruderGenerator
    input = rename_outer
    extrusion_vector = '0 0 ${length}'
    num_layers = '${n_elems_axial}'
    bottom_sideset = 'bottom'
    top_sideset = 'top'
  []
  [rename2]
    type = RenameBlockGenerator
    input = extrude
    old_block = '1 3'
    new_block = 'pellet clad'
  []
  [x_axis]
    type = ExtraNodesetGenerator
    input = rename2
    coord = '0 0 ${length}; 0 0 0;${clad_outer_radius} 0 0;-${clad_outer_radius} 0 0'
    new_boundary  = 'x_axis'
  []
  [y_axis]
    type = ExtraNodesetGenerator
    input = x_axis
    coord = '0 0 ${length}; 0 0 0;0 ${clad_outer_radius} 0;0 -${clad_outer_radius} 0'
    new_boundary  = 'y_axis'
  []
[]

#以上是生成几何与网格
# 》》》》》》》》》》》》》》》》》》》》》》》》》》》
# 》》》》》》》》》》》》》》》》》》》》》》》》》》》》》》》》

#力平衡方程相关参数
pellet_elastic_constants=2.01e11#Pa
pellet_nu = 0.345
pellet_K = '${fparse pellet_elastic_constants/3/(1-2*pellet_nu)}'
pellet_G = '${fparse pellet_elastic_constants/2/(1+pellet_nu)}'
clad_elastic_constants=7.52e10#Pa
clad_nu = 0.33

#热平衡方程相关参数
#芯块的热物理参数
pellet_density=10431.0#10431.0*0.85#kg⋅m-3
# pellet_specific_heat=300 # J/(kg·K)
# pellet_thermal_conductivity = 5 # W/(m·K)
pellet_thermal_expansion_coef=1e-5#K-1
#芯块的断裂力学参数
Gf = 3 #断裂能
pellet_critical_fracture_strength=6.0e7#Pa

length_scale_paramete=2.5e-5
pellet_critical_energy=${fparse Gf} #J⋅m-2
# pellet_critical_energy=${fparse (1+3.22e-5/length_scale_paramete/2)*Gf} #J⋅m-2
#包壳的热物理参数
clad_density=6.59e3#kg⋅m-3
clad_specific_heat=264.5 # J/(kg·K)
clad_thermal_conductivity = 16 # W/(m·K)
clad_thermal_expansion_coef=5.0e-6#K-1

[MultiApps]
  [fracture]
    type = TransientMultiApp
    input_files = 'step5_Addfracture_sub.i'
    cli_args = 'Gc=${pellet_critical_energy};l=${length_scale_paramete};E0=${pellet_elastic_constants}'
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
    type = ADDirichletBC
    variable = disp_y
    boundary = 'x_axis'
    value = 0
  []
  [x_zero_on_x_plane]
    type = ADDirichletBC
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
[]

[Materials]
  #1. 芯块材料属性
  #热物理属性
  [pellet_properties]
    type = ADGenericConstantMaterial
    prop_names = 'K G l Gc E0 density'
    prop_values = '${pellet_K} ${pellet_G} ${length_scale_paramete} ${pellet_critical_energy} ${pellet_elastic_constants} ${pellet_density}'
    output_properties = 'l Gc'
    outputs = exodus
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
  coupled_variables = 'T d'
  expression = '(100/(7.5408 + 17.692*T/1000 + 3.6142*(T/1000)^2) + 6400/((T/1000)^2.5)*exp(-16.35/(T/1000)))*(1-0.8*d)'
  block = pellet
  []
  [pellet_specific_heat] #新加的！！！！！！！！！！！！！！！！！！！！！！
    type = ADParsedMaterial
    property_name = specific_heat
    coupled_variables = 'T d'
    expression = '(52.1743 + 87.951*T/1000 - 84.2411*(T/1000)^2 + 31.542*(T/1000)^3 - 2.6334*(T/1000)^4 - 0.71391*(T/1000)^(-2))*(1-0.8*d)'
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
    eigenstrain_names = thermal_eigenstrain
    block = pellet
  []
  # # 断裂力学-CZM模型
  # [degradation]
  #   type = RationalDegradationFunction
  #   property_name = g
  #   expression = (1-d)^p/((1-d)^p+(4*Gc*E0/sigma0^2/3.14/l)*d*(1+a2*d))
  #   phase_field = d
  #   material_property_names = 'Gc sigma0 l E0'
  #   parameter_names = 'p a2'
  #   parameter_values = '2 -0.5'
  #   block = pellet
  # []
  # [crack_geometric]
  #   type = CrackGeometricFunction
  #   property_name = alpha
  #   expression = '2*d-d*d'
  #   phase_field = d
  #   block = pellet
  # []
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
    expression = '4*d'
    phase_field = d
    block = pellet
  []  
    # # Rankine有效应力计算
    # [elasticity]
    #   type = TensionCompressionSplitElasticity
    #   poisson_ratio = ${nu}
    #   elastic_constants = E0
    #   phase_field = d
    #   tensile_strength = sigma0
    #   degradation_function = g
    #   output_properties = 'psie_active'
    #   outputs = exodus
    #   block = 1
    # []
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
    block = clad
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
    x = '0          300000'
    y = '2.5          14'
    scale_factor = 1
  []
  [dt_limit_func]
    type = ParsedFunction
    expression = 'if(t <40000,10000,
                       if(abs(d_increment) < 1e-3,5000, 
                         if(abs(d_increment) < 5e-3,4000, 
                           if(abs(d_increment) < 1e-2,3000, 
                             if(abs(d_increment) < 5e-2,2000, 
                               if(abs(d_increment) < 1e-1,100,10))))))'
    symbol_names = 'd_increment'
    symbol_values = 'd_increment'
  []
  # [ThermalExpansionFunction] #新加的！！！！！！！！！！！！！！！！！！！！！！
  #   type = ParsedFunction
  #   expression = '(-4.972e-4 + 7.107e-6*t + 2.581e-9*t*t + 1.14e-13*t*t*t)'
  # []
[]

[Postprocessors]
  [d_average]
    type = ElementAverageValue
    variable = d
    # value_type = average
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

[ThermalContact] #新加的！！！！！！！！！！！！！！！！！！！！！！
  [thermal_contact]
    type = GapHeatTransfer # 间隙传热模型
    variable = T
    primary = clad_inner # 主边界
    secondary = pellet_outer # 从边界
    emissivity_primary = 0.8 # 主边界发射率
    emissivity_secondary = 0.8 # 从边界发射率
    gap_conductivity = 1 # 间隙等效导热系数
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
  nl_max_its = 5
  nl_rel_tol = 1e-5 # 非线性求解的相对容差
  # nl_abs_tol = 1e-7 # 非线性求解的绝对容差
  l_tol = 1e-5  # 线性求解的容差
  l_max_its = 50 # 线性求解的最大迭代次数
  accept_on_max_fixed_point_iteration = true # 达到最大迭代次数时接受解
  dtmin = 0.0001
  dt = 10000 # 时间步长3600s
  end_time = 3e5 # 总时间24h

  fixed_point_rel_tol =1e-3 # 固定点迭代的相对容差
  [TimeStepper]
    type = FunctionDT
    function = dt_limit_func
  []

  # 现在我们就卡死nl_max_its = 10，  以及l_max_its = 50以试一下各个求解器
  # petsc_options_iname = '-pc_type -pc_factor_mat_solver_package'
  # petsc_options_value = 'lu       superlu_dist                 '
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
  petsc_options_iname = '-ksp_gmres_restart -pc_type -pc_hypre_type'
  petsc_options_value = '200                hypre    boomeramg'  
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
  [d]
    block = pellet
  []
  [./max]
    order = CONSTANT
    family = MONOMIAL
  [../]
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
  [./max]
    type = ElementLengthAux
    variable = max
    method = max
    execute_on = initial
  [../]
  [copy_sigma0]
    type = ADMaterialRealAux
    variable = sigma0_field
    property = sigma0
    execute_on = 'initial'
    block = pellet
  []
[]

h=${fparse 3.14*pellet_outer_radius/2/n_elems_azimuthal}

[Outputs]
  exodus = true #表示输出exodus格式文件
  file_base = 'outputs/PF1_2222222222/h=${h}_l=${length_scale_paramete}_Gc=${Gf}'
[]
