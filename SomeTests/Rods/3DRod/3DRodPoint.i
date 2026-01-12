
#conda activate moose && dos2unix 3DRodPoint.i&&mpirun -n 12 /home/yp/projects/fuel_rods/fuel_rods-opt -i 3DRodPoint.i
# === 参数研究案例 ===
initial_T=530

pellet_nu = 0.345
density_percent = 0.95
# density_percent100 = '${fparse density_percent*100}'
pellet_density='${fparse density_percent*10980}'#10431.0*0.85#kg⋅m-3理论密度为10.980
# grain_size = 10

#《《下面数据取自[1]王兆,张新虎,王召浩,等.基于MOOSE平台的UO2燃料性能分析[J].材料导报,2022,36(07):156-162.
LinearPower = 35
LinearPower0_2 = '${fparse LinearPower*0.2}'

# 网格控制参数n_azimuthal = 512时网格尺寸为6.8e-5m
pellet_outer_radius = 4.1e-3#直径变半径，并且单位变mm
length = 119e-3 # 芯块长度17.78mm
n_elems_axial = 10 # 轴向网格数
grid_sizes  = 20e-5 # 网格尺寸
#将下列参数转化为整数
n_elems_azimuthal = '${fparse 2*ceil(3.1415*2*(pellet_outer_radius/(4*grid_sizes)/2))}'  # 周向网格数（向上取整）
n_elems_radial_pellet = '${fparse int(pellet_outer_radius/(4*grid_sizes))}'          # 芯块径向网格数（直接取整）


power_factor = '${fparse 1000*1/3.1415926/pellet_outer_radius/pellet_outer_radius}' #新加的！！！！！！！！！！！！！！！！！！！！！！

[Mesh]
  [pellet_clad_gap]
    type = ConcentricCircleMeshGenerator
    num_sectors = '${n_elems_azimuthal}'  # 周向网格数
    radii = '${pellet_outer_radius}'
    rings = '${n_elems_radial_pellet}'
    has_outer_square = false
    preserve_volumes = true
    portion = full # 生成四分之一计算域
    smoothing_max_it=666 # 平滑迭代次数
  []
  [rename]
    type = RenameBoundaryGenerator
    input = pellet_clad_gap
    old_boundary = 'outer'
    new_boundary = 'pellet_outer' # 将边界命名为yplane xplane clad_outer

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
[center_point]
  type = ExtraNodesetGenerator
  input = rename2
  coord = '0 0 0'
  new_boundary  = 'center_point'
[]
[]


[GlobalParams]
    displacements = 'disp_x disp_y disp_z'
[]
[AuxVariables]
  [hoop_stress]
    order = CONSTANT
    family = MONOMIAL
  []
  [MaxPrincipal]
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
  [MaxPrincipalStress]
    type = ADRankTwoScalarAux
    variable = MaxPrincipal
    rank_two_tensor = stress
    scalar_type = MaxPrincipal
    execute_on = 'TIMESTEP_END'
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
      initial_condition = ${initial_T}
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
    [./solid_z]
        type = ADStressDivergenceTensors
        variable = disp_z
        component = 2
    [../]
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
    []
[]
[BCs]
    #固定平面
  [y_zero_on_y_plane]
    type = DirichletBC
    variable = disp_y
    boundary = 'center_point'
    value = 0
  []
  [x_zero_on_x_plane]
    type = DirichletBC
    variable = disp_x
    boundary = 'center_point'
    value = 0
  []
  [z_zero_on_bottom_top]
    type = DirichletBC
    variable = disp_z
    boundary = 'center_point'
    value = 0
  []

  [coolant_bc]#对流边界条件
  type = ConvectiveFluxFunction
  variable = T
  boundary = 'bottom'
  T_infinity = 600
  coefficient = 10000#3500 W·m-2 K-1！！！！！！！！！！！！！！！！！！！！！！！！！！！
  []
  [coolant_bc2]#对流边界条件
  type = ConvectiveFluxFunction
  variable = T
  boundary = 'pellet_outer top'
  T_infinity = 620
  coefficient = 3500#3500 W·m-2 K-1！！！！！！！！！！！！！！！！！！！！！！！！！！！
  []
  #芯块包壳间隙压力边界条件
  [gap_pressure_fuel_x]
    type = Pressure
    variable = disp_x
    boundary = 'pellet_outer'
    factor = 2e6 # 间隙压力2.5MPa
  []
  [gap_pressure_fuel_y]
    type = Pressure
    variable = disp_y
    boundary = 'pellet_outer'
    factor = 2e6
  []
[]

[Materials]
    #定义芯块热导率、密度、比热等材料属性
    [pellet_properties2]
      type = ADGenericConstantMaterial
      prop_names = 'density nu'
      prop_values = '${pellet_density} ${pellet_nu}'
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
      coupled_variables = 'T'  # 需要在AuxVariables中定义Y变量
      expression = '(296.7 * 535.285^2 * exp(535.285/T))/(T^2 * (exp(535.285/T) - 1)^2) + 2.43e-2 * T + (2) * 8.745e7 * 1.577e5 * exp(-1.577e5/(8.314*T))/(2 * 8.314 * T^2)'
      block = pellet
    []
    [pellet_elastic_constants]
      type = ADParsedMaterial
      property_name = E #Fink model
      coupled_variables = 'T'  # 需要在AuxVariables中定义Y变量
      expression = '2.334*10^11*(1-2.752*(1-D))*(1-1.0915*10^(-4)*T)'
      constant_names = 'D'
      constant_expressions = '${density_percent}'
      block = pellet
    []
    [thermal_eigenstrain_coef]
      type = ADDerivativeParsedMaterial  # 改为ADParsedMaterial
      property_name = thermal_eigenstrain_coef
      coupled_variables = 'T'
      expression = '-4.972e-4+7.107e-6*T+2.581e-9*T^2+1.14e-13*T^3'# 0.6024是5000MWd/tU的转换系数
      block = pellet
    []
    # 肿胀应变计算
    [eigenstrain]
      type = ADComputeThermalExpansionEigenstrain
      eigenstrain_name = thermal_eigenstrain
      stress_free_temperature = ${initial_T}  # 应力自由温度为初始温度
      thermal_expansion_coeff = 1e-5
      temperature = T
    []
    [pellet_strain]
      type = ADComputeSmallStrain 
      eigenstrain_names = 'thermal_eigenstrain'
    []
    [pellet_elasticity_tensor]
      type = ADComputeVariableIsotropicElasticityTensor
      youngs_modulus = E
      poissons_ratio = nu
    []
    [stress]
      type = ADComputeLinearElasticStress
    []
    [strain_energy_density]
      type = ADStrainEnergyDensity
      incremental = false
    []
[]
[Functions]
  [power_history] #新加的！！！！！！！！！！！！！！！！！！！！！！
    type = PiecewiseLinear
    x = '0.0 2400.0 98400.0 110000 120000'
    y = '0.0 ${LinearPower0_2} ${LinearPower} ${LinearPower} 0'
    scale_factor = ${power_factor}
  []
[]
[Executioner]
  type = Transient # 瞬态求解器
  solve_type = 'NEWTON' #求解器，PJFNK是预处理雅可比自由牛顿-克雷洛夫方法
  # petsc_options_iname = '-ksp_gmres_restart -pc_type -pc_hypre_type'
  # petsc_options_value = '201                hypre    boomeramg'  
  # solve_type = 'NEWTON'
  # solve_type = 'NEWTON'
  # petsc_options_iname = '-pc_type   -snes_type        -snes_qn_type   -snes_qn_scale_type -snes_linesearch_type' 
  # petsc_options_value = 'lu         qn               lbfgs           jacobian           bt'
  petsc_options_iname = '-pc_type -ksp_type' 
  petsc_options_value = 'lu gmres' 
  automatic_scaling = true # 启用自动缩放功能，有助于改善病态问题的收敛性
  compute_scaling_once = true  # 每个时间步都重新计算缩放
  # reuse_preconditioner = true
  # reuse_preconditioner_max_linear_its = 20
  nl_max_its = 150
  nl_rel_tol = 5e-10 # 非线性求解的相对容差
  nl_abs_tol = 5e-9 # 非线性求解的绝对容差
  l_tol = 5e-10  # 线性求解的容差
  l_abs_tol = 5e-9 # 线性求解的绝对容差
  l_max_its = 500 # 线性求解的最大迭代次数
  accept_on_max_fixed_point_iteration = true # 达到最大迭代次数时接受解
  dtmin = 2500
  dtmax = 2500
  end_time = 120000 # 总时间24h
[]

[Postprocessors]
  [T_avg]
    type = ElementAverageValue
    variable = T
    block = pellet
  []
  [hoop_stress_max]
    type = ElementExtremeValue
    variable = hoop_stress
    value_type = max
    block = pellet
  []
  [max_principal_avg]
    type = ElementAverageValue
    variable = MaxPrincipal
    block = pellet
  []
  [strain_energy_total]
    type = ElementIntegralMaterialProperty
    mat_prop = strain_energy_density
    block = pellet
  []
[]

[Outputs]
  exodus = true #表示输出exodus格式文件
  print_linear_residuals = false
  [csv]
    type = CSV
    execute_on = 'TIMESTEP_END'
  []
[]
