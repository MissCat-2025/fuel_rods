# 这第一步就是为生成网格文件Oconee_Rod_15309.e
# 语法要求：仅仅为了生成网格文件：Run with --mesh-only:
#https://mooseframework.inl.gov/source/meshgenerators/ConcentricCircleMeshGenerator.html
#   mpirun -n 10 ../../fuel_rods-opt -i step1_to_generate_e.i --mesh-only Oconee_Rod_15309.e
#《[1] WEI LI, KOROUSH SHIRVAN. Multiphysics phase-field modeling of quasi-static cracking in urania ceramic nuclear fuel[J/OL]. Ceramics International, 2021, 47(1): 793-810. DOI:10.1016/j.ceramint.2020.08.191.

pellet_outer_radius = 4.1e-3#直径变半径，并且单位变mm
n_elems_azimuthal = 100 # 周向网格数
n_elems_radial_pellet =20 # 芯块径向网格数


pellet_elastic_constants=2.2e11#Pa
pellet_nu = 0.345

#热平衡方程相关参数
#芯块的热物理参数
pellet_density=10431.0#10431.0*0.85#kg⋅m-3
pellet_specific_heat=300 # J/(kg·K)
pellet_thermal_conductivity = 5 # W/(m·K)
pellet_thermal_expansion_coef=1e-5#K-1



[Mesh]
    [pellet]
      type = ConcentricCircleMeshGenerator
      num_sectors = '${n_elems_azimuthal}'  # 周向网格数
      radii = '${pellet_outer_radius}'
      rings = '${n_elems_radial_pellet}'
      has_outer_square = false
      preserve_volumes = true
      # portion = top_right # 生成四分之一计算域
      smoothing_max_it=15 # 平滑迭代次数
    []
  [rename2]
    type = RenameBlockGenerator
    input = pellet
    old_block  = '1'
    new_block  = 'pellet' # 将block1和block3分别命名为pellet和clad
  []
  [center_line]
    type = ExtraNodesetGenerator
    input = rename2
    coord = '0 0'
    new_boundary  = 'center'
  []
[]


[GlobalParams]
  displacements = 'disp_x disp_y'
[]

[Variables]
#定义位移变量 - 用于求解力平衡方程
  [disp_x]
    family = LAGRANGE
    order = FIRST
  []
  [disp_y]
  []
  #定义温度变量 - 用于求解热传导方程
  [T]
    initial_condition = 500 # 初始温度500K
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
    type = HeatSource # 体积热源项 q'''
    variable = T
    value = 4.2e8 # 功率密度 W/m³
    block = pellet # 只在芯块区域有热源
  []
[]

[BCs]
#1. 位移边界条件
#固定平面的位移边界条件
[y_zero_on_y_plane]
  type = DirichletBC
  variable = disp_y
  boundary = 'center'
  value = 0
[]
[x_zero_on_x_plane]
  type = DirichletBC
  variable = disp_x
  boundary = 'center'
  value = 0
[]
#2. 压力边界条件
#冷却剂压力边界条件
[coolant_bc]
  type = DirichletBC # 冷却剂温度边界条件
  variable = T
  boundary = 1
  value = 600 # 冷却剂温度500K
[]
[]

[Materials]
#1. 芯块材料属性
#热物理属性
[pellet_properties]
  type = ADGenericConstantMaterial
  prop_names = 'density specific_heat thermal_conductivity'
  prop_values = '${pellet_density} ${pellet_specific_heat} ${pellet_thermal_conductivity}'
  block = pellet
[]
#热-力耦合：热应变
[pellet_thermal_eigenstrain]
  type = ADComputeThermalExpansionEigenstrain
  eigenstrain_name = thermal_eigenstrain
  stress_free_temperature = 500 # 参考温度500K，这个值对于模拟结果影响巨大，一般取为初始温度
  thermal_expansion_coeff = ${pellet_thermal_expansion_coef} # 热膨胀系数
  temperature = T
  block = pellet
[]
#力学属性
[pellet_strain]
  type = ADComputeSmallStrain
  eigenstrain_names = 'thermal_eigenstrain'
  block = pellet
[]
[pellet_elasticity_tensor]
  type = ADComputeIsotropicElasticityTensor
  youngs_modulus = ${pellet_elastic_constants} # 弹性模量
  poissons_ratio = ${pellet_nu} # 泊松比
  block = pellet
[]
[stress]
  type = ADComputeLinearElasticStress
[]
[]

[Executioner]
type = Transient # 瞬态求解器
solve_type = 'PJFNK' #求解器，PJFNK是预处理雅可比自由牛顿-克雷洛夫方法

automatic_scaling = true # 启用自动缩放功能，有助于改善病态问题的收敛性
compute_scaling_once = true  # 每个时间步都重新计算缩放
nl_max_its = 20
nl_rel_tol = 5e-7 # 非线性求解的相对容差
nl_abs_tol = 1e-7 # 非线性求解的绝对容差
l_tol = 1e-7  # 线性求解的容差
l_max_its = 50 # 线性求解的最大迭代次数
accept_on_max_fixed_point_iteration = true # 达到最大迭代次数时接受解
dt = 1 # 时间步长3600s
end_time = 3e5 # 总时间24h
# 现在我们就卡死nl_max_its = 10，  以及l_max_its = 50以试一下各个求解器
  petsc_options_iname = '-pc_type -pc_factor_mat_solver_package'
  petsc_options_value = 'lu       superlu_dist                 '
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
  # petsc_options_iname = '-pc_type -pc_hypre_type'
  # petsc_options_value = 'hypre boomeramg'  # 代数多重网格，大问题效果好
#5.GMRES重启参数（并列第二快）大规模问题
  # petsc_options_iname = '-ksp_gmres_restart  -pc_type  -pc_hypre_type  -pc_hypre_boomeramg_max_iter'
  # petsc_options_value = '201                  hypre     boomeramg       4'

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
[]

[Outputs]
exodus = true #表示输出exodus格式文件
[]