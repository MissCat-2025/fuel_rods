# mpirun -n 16 /home/yp/projects/raccoon/raccoon-opt -i NoClad3D_ThermallFracture.i

pellet_density=10431.0#10431.0*0.85#kg⋅m-3
pellet_elastic_constants=2.0e11#Pa
pellet_nu = 0.345
# pellet_specific_heat=300
# pellet_thermal_conductivity = 5
pellet_thermal_expansion_coef=1e-5#K-1
pellet_K = '${fparse pellet_elastic_constants/3/(1-2*pellet_nu)}'
pellet_G = '${fparse pellet_elastic_constants/2/(1+pellet_nu)}'
Gc = 3 #断裂能
pellet_critical_fracture_strength=6.0e7#Pa
length_scale_paramete=5e-5
a1 = '${fparse 4*pellet_elastic_constants*Gc/pellet_critical_fracture_strength/pellet_critical_fracture_strength/3.14159/length_scale_paramete}' 

# 各种参数都取自[1]Multiphysics phase-field modeling of quasi-static cracking in urania ceramic nuclear fuel
#几何与网格参数
pellet_outer_radius = 4.1e-3#直径变半径，并且单位变mm
length = 4.75e-5 # 芯块长度17.78mm
n_elems_axial = 1 # 轴向网格数
grid_sizes = 1.9e-4 #mm,最大网格尺寸（虚），1.9e-4真实的网格尺寸为4.75e-5
#将下列参数转化为整数
n_elems_azimuthal = '${fparse 2*ceil(3.1415*2*pellet_outer_radius/grid_sizes/2)}'  # 周向网格数（向上取整）
n_elems_radial_pellet = '${fparse int(pellet_outer_radius/grid_sizes)}'          # 芯块径向网格数（直接取整）


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
    input_files = 'NoClad3D_quarter_ThermallFractureNewH_Sub.i'
    cli_args = 'Gc=${Gc};l=${length_scale_paramete};a1=${a1}'
    execute_on = 'TIMESTEP_END'
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
      function = power_history
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

#芯块包壳间隙压力边界条件
# [gap_pressure_fuel_x]
#   type = Pressure
#   variable = disp_x
#   boundary = 'pellet_outer'
#   factor = 1e6 # 间隙压力2.5MPa
#   function = gap_pressure #新加的！！！！！！！！！！！！！！！！！！！！！！
#   use_displaced_mesh = false
# []
# [gap_pressure_fuel_y]
#   type = Pressure
#   variable = disp_y
#   boundary = 'pellet_outer'
#   factor = 1e6
#   function = gap_pressure #新加的！！！！！！！！！！！！！！！！！！！！！！
#   use_displaced_mesh = false
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
coefficient = 3440#3500 W·m-2 K-1！！！！！！！！！！！！！！！！！！！！！！！！！！！
[]

[]
[Materials]
    #定义芯块热导率、密度、比热等材料属性
    [pellet_properties2]
      type = ADGenericConstantMaterial
      prop_names = 'E nu l Gc a1 density K G'
      prop_values = '${pellet_elastic_constants} ${pellet_nu} ${length_scale_paramete} ${Gc} ${a1} ${pellet_density} ${pellet_K} ${pellet_G}'
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
    expression = '(100/(7.5408 + 17.692*T/1000 + 3.6142*(T/1000)^2) + 6400/((T/1000)^2.5)*exp(-16.35/(T/1000)))*(1-0.05*d)'
    block = pellet
    []
    [pellet_specific_heat]
      type = ADParsedMaterial
      property_name = specific_heat #Fink model
      coupled_variables = 'T'  # 需要在AuxVariables中定义Y变量
      expression = '(296.7 * 535.285^2 * exp(535.285/T))/(T^2 * (exp(535.285/T) - 1)^2) + 2.43e-2 * T + (2) * 8.745e7 * 1.577e5 * exp(-1.577e5/(8.314*T))/(2 * 8.314 * T^2)'
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

    [degradation]
      type = RationalDegradationFunction
      property_name = g
      expression = (1-d)^p/((1-d)^p+a1*d*(1+a2*d+a3*d^2))*(1-eta)+eta
      phase_field = d
      material_property_names = 'a1'
      parameter_names = 'p a2 a3 eta'
      parameter_values = '2.5 3.1748 0 1e-6' #指数软化
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
power_factor = '${fparse 1000*1/3.1415926/pellet_outer_radius/pellet_outer_radius}' #新加的！！！！！！！！！！！！！！！！！！！！！！
[Functions]
  [power_history] #新加的！！！！！！！！！！！！！！！！！！！！！！
    type = PiecewiseLinear
    x = '0.0 100000 125000 175000 300000'
    y = '0.0 18.0 34.0 34.0 0.0'
    scale_factor = ${power_factor}
  []
[]

[Executioner]
  type = Transient # 瞬态求解器
  solve_type = 'NEWTON' #求解器，PJFNK是预处理雅可比自由牛顿-克雷洛夫方法
  petsc_options_iname = '-ksp_gmres_restart -pc_type -pc_hypre_type'
  petsc_options_value = '201                hypre    boomeramg'  

  automatic_scaling = true # 启用自动缩放功能，有助于改善病态问题的收敛性
  compute_scaling_once = true  # 每个时间步都重新计算缩放

  nl_max_its = 5
  nl_rel_tol = 1e-6 # 非线性求解的相对容差
  nl_abs_tol = 1e-7 # 非线性求解的绝对容差
  l_tol = 1e-7  # 线性求解的容差
  l_abs_tol = 1e-8 # 线性求解的绝对容差
  l_max_its = 150 # 线性求解的最大迭代次数
  accept_on_max_fixed_point_iteration = true # 达到最大迭代次数时接受解
  dtmin = 50
  dt = 2500 # 时间步长3600s
  end_time = 3.2e5 # 总时间24h

  fixed_point_rel_tol =1e-4 # 固定点迭代的相对容差
  # [TimeStepper]
  #   type = FunctionDT
  #   function = dt_limit_func
  # []
[]



[Outputs]
  exodus = true #表示输出exodus格式文件
  # file_base = 'outputs/h=${h}_l=${length_scale_paramete}_Gc=${Gc}'
  print_linear_residuals = false
[]
