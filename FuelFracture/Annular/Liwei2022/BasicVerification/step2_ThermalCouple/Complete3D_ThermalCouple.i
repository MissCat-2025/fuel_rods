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

#mpirun -n 10 ../../../../../raccoon-opt -i Complete3D.i --mesh-only KAERI_HANARO_UpperRod1.e
#《《下面数据取自[1]Thermomechanical Analysis and Irradiation Test of Sintered Dual-Cooled Annular pellet》》

# 双冷却环形燃料几何参数 (单位：mm)
inclad_inner_diameter = 9.0      # 内包壳内直径
inclad_outer_diameter = 10.14    # 内包壳外直径
pellet_inner_diameter = 10.291         # 芯块内直径
pellet_outer_diameter = 14.627         # 芯块外直径
outclad_inner_diameter = 14.76    # 外包壳内直径
outclad_outer_diameter = 15.9     # 外包壳外直径
length = 6e-5                    # 轴向长度(m)

# 网格控制参数n_azimuthal = 512时网格尺寸为6.8e-5m
n_radial_inner_clad = 3    # 内包壳径向单元数
n_radial_pellet = 32          # 燃料径向单元数
n_radial_outer_clad = 3    # 外包壳径向单元数
n_azimuthal = 512           # 周向基础单元数
growth_factor = 1.0        # 径向增长因子
n_axial = 1                # 轴向单元数
# 计算半径参数 (转换为米)
inner_clad_inner_radius = '${fparse inclad_inner_diameter/2*1e-3}'
inner_clad_outer_radius = '${fparse inclad_outer_diameter/2*1e-3}'
pellet_inner_radius = '${fparse pellet_inner_diameter/2*1e-3}'
pellet_outer_radius = '${fparse pellet_outer_diameter/2*1e-3}'
outer_clad_inner_radius = '${fparse outclad_inner_diameter/2*1e-3}'
outer_clad_outer_radius = '${fparse outclad_outer_diameter/2*1e-3}'
#自适应法线公差
normal_tol = '${fparse 3.14*pellet_inner_diameter/n_azimuthal*1e-3/10}'
[Mesh]
  [inner_clad1]
    type = AnnularMeshGenerator
    nr = ${n_radial_inner_clad}
    nt = ${n_azimuthal}
    rmin = ${inner_clad_inner_radius}
    rmax = ${inner_clad_outer_radius}
    growth_r = ${growth_factor}
    boundary_id_offset = 10
    boundary_name_prefix = 'inclad'
  []
  [inner_clad]
    type = SubdomainIDGenerator
    input = inner_clad1
    subdomain_id = 1
  []
  [pellet1]
    type = AnnularMeshGenerator
    nr = ${n_radial_pellet}
    nt = ${n_azimuthal}
    rmin = ${pellet_inner_radius}
    rmax = ${pellet_outer_radius}
    growth_r = ${growth_factor}
    boundary_id_offset = 20
    boundary_name_prefix = 'pellet'
  []
  [pellet]
    type = SubdomainIDGenerator
    input = pellet1
    subdomain_id = 2
  []
  [outer_clad1]
    type = AnnularMeshGenerator
    nr = ${n_radial_outer_clad}
    nt = ${n_azimuthal}
    rmin = ${outer_clad_inner_radius}
    rmax = ${outer_clad_outer_radius}
    growth_r = ${growth_factor}
    boundary_id_offset = 30
    boundary_name_prefix = 'outclad'
  []
  [outer_clad]
    type = SubdomainIDGenerator
    input = outer_clad1
    subdomain_id = 3
  []
  [combine]
    type = CombinerGenerator
    inputs = 'inner_clad pellet outer_clad'
  []
  [rename1]
    type = RenameBoundaryGenerator
    input = combine
    old_boundary = 'inclad_rmin inclad_rmax pellet_rmin pellet_rmax outclad_rmin outclad_rmax'
    new_boundary = 'inclad_inner inclad_outer pellet_inner pellet_outer outclad_inner outclad_outer'
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
    old_block = '1 2 3'
    new_block = 'inclad pellet outclad'
  []
  # 创建x轴切割边界面 (y=0线)
  [x_axis_cut]
    type = SideSetsBetweenSubdomainsGenerator
    input = rename2
    new_boundary = 'x_axis'
    primary_block = 'pellet outclad inclad'
    paired_block = 'pellet outclad inclad'
    normal = '0 1 0'  # 法线方向为Y轴
    normal_tol = '${normal_tol}'
  []
  # 创建x轴切割边界面 (y=0线)
  [y_axis_cut]
    type = SideSetsBetweenSubdomainsGenerator
    input = x_axis_cut
    new_boundary = 'y_axis'
    primary_block = 'pellet outclad inclad'
    paired_block = 'pellet outclad inclad'
    normal = '1 0 0'  # 法线方向为X轴
    normal_tol = '${normal_tol}'
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
  #冷却剂压力
  [colden_pressure_fuel_x]
    type = Pressure
    variable = disp_x
    boundary = 'inclad_inner outclad_outer'
    factor = 15.5e6
    use_displaced_mesh = true
  []
  [colden_pressure_fuel_y]
    type = Pressure
    variable = disp_y
    boundary = 'inclad_inner outclad_outer'
    factor = 15.5e6
    use_displaced_mesh = true
  []
  #芯块包壳间隙压力
  [gap_pressure_fuel_x]
    type = Pressure
    variable = disp_x
    boundary = 'inclad_outer outclad_inner pellet_inner pellet_outer'
    factor = 2.5e6
    use_displaced_mesh = true
  []
  [gap_pressure_fuel_y]
    type = Pressure
    variable = disp_y
    boundary = 'inclad_outer outclad_inner pellet_inner pellet_outer'
    factor = 2.5e6
    use_displaced_mesh = true
  []
  [coolant_bc]#对流边界条件
    type = ConvectiveFluxFunction
    variable = T
    boundary = 'inclad_inner outclad_outer'
    T_infinity = 500
    coefficient = 3.4e4#3.4e4 W·m-2 K-1
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
      block = 'inclad outclad' 
    []
    [clad_thermal_eigenstrain]
      type = ADComputeThermalExpansionEigenstrain
      eigenstrain_name = thermal_eigenstrain
      stress_free_temperature = 500
      thermal_expansion_coeff = ${clad_thermal_expansion_coef}
      temperature = T
      block = 'inclad outclad'
    []
    [clad_strain]
      type = ADComputeSmallStrain 
      eigenstrain_names = 'thermal_eigenstrain'
      block = 'inclad outclad'
    []
    [clad_elasticity_tensor]
        type = ADComputeIsotropicElasticityTensor
        youngs_modulus = ${clad_elastic_constants}
        poissons_ratio = ${clad_nu}
        block = 'inclad outclad'
    []
    [clad_stress]
        type = ADComputeLinearElasticStress
    []

[]
[ThermalContact]
  [./thermal_contact1]
    type = GapHeatTransfer
    variable = T
    primary = inclad_outer
    secondary = pellet_inner
    emissivity_primary = 0.8
    emissivity_secondary = 0.8
    gap_conductivity = 0.15
    quadrature = true
    gap_geometry_type = CYLINDER
    cylinder_axis_point_1 = '0 0 0'
    cylinder_axis_point_2 = '0 0 0.0001'
  [../]
    [./thermal_contact2]
      type = GapHeatTransfer
      variable = T
      primary = outclad_inner
      secondary = pellet_outer
      emissivity_primary = 0.8
      emissivity_secondary = 0.8
      gap_conductivity = 0.15
      quadrature = true
      gap_geometry_type = CYLINDER
      cylinder_axis_point_1 = '0 0 0'
      cylinder_axis_point_2 = '0 0 0.0001'
    [../]
    []
[Executioner]
    type = Transient
    solve_type = 'PJFNK'
  petsc_options_iname = '-pc_type -pc_factor_mat_solver_package'
  petsc_options_value = 'lu       superlu_dist                 '
    dt = 1
    end_time = 10
  []
[Outputs]
  exodus = true
[]