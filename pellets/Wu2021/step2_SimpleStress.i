# 各种参数都取自[1]Multiphysics phase-field modeling of quasi-static cracking in urania ceramic nuclear fuel
#几何与网格参数
pellet_outer_radius = 4.1e-3#直径变半径，并且单位变mm
clad_inner_radius = 4.18e-3#直径变半径，并且单位变mm
clad_outer_radius = 4.78e-3#直径变半径，并且单位变mm
length = 11e-3 # 芯块长度17.78mm
n_elems_axial = 2 # 轴向网格数
n_elems_azimuthal = 50 # 周向网格数
n_elems_radial_clad = 4 # 包壳径向网格数
n_elems_radial_pellet = 30 # 芯块径向网格数
#材料参数

pellet_elastic_constants=2.2e11#Pa
pellet_nu = 0.345
# pellet_density=10431.0#10431.0*0.85#kg⋅m-3
# pellet_specific_heat=300
# pellet_thermal_conductivity = 5


clad_elastic_constants=7.52e10#Pa
clad_nu = 0.33
# clad_density=6.59e3#kg⋅m-3
# clad_specific_heat=264.5
# clad_thermal_conductivity = 16
# clad_thermal_expansion_coef=5.0e-6#K-1



[Mesh]
    [pellet_clad_gap]
      type = ConcentricCircleMeshGenerator
      num_sectors = '${n_elems_azimuthal}'  # 周向网格数
      radii = '${pellet_outer_radius} ${clad_inner_radius} ${clad_outer_radius}'
      rings = '${n_elems_radial_pellet} 1 ${n_elems_radial_clad}'
      has_outer_square = false
      preserve_volumes = true
      portion = top_right # 生成四分之一计算域
      smoothing_max_it=10 # 平滑迭代次数
    []
    [rename_pellet_outer_bdy]
      type = SideSetsBetweenSubdomainsGenerator
      input = pellet_clad_gap
      primary_block = 1
      paired_block = 2
      new_boundary = 'pellet_outer' #将block1与block2之间的边界命名为pellet_outer
    []
    [rename_clad_inner_bdy]
      type = SideSetsBetweenSubdomainsGenerator
      input = rename_pellet_outer_bdy
      primary_block = 3
      paired_block = 2
      new_boundary = 'clad_inner' #将block3与block2之间的边界命名为clad_inner
    []

    [2d_mesh]
      type = BlockDeletionGenerator
      input = rename_clad_inner_bdy
      block = 2 # 删除block2
    []
    [rename]
      type = RenameBoundaryGenerator
      input = 2d_mesh
      old_boundary = 'bottom left outer'
      new_boundary = 'yplane xplane clad_outer' # 将边界命名为yplane xplane clad_outer

    []
  [extrude]
    type = MeshExtruderGenerator
    input = rename
    extrusion_vector = '0 0 ${length}' # 轴向长度
    num_layers = '${n_elems_axial}' # 轴向网格数
    bottom_sideset = 'bottom' # 命名为底面
    top_sideset = 'top' # 命名为顶面
  []
  [rename2]
    type = RenameBlockGenerator
    input = extrude
    old_block  = '1 3'
    new_block  = 'pellet clad' # 将block1和block3分别命名为pellet和clad
  []
[]

[GlobalParams]
    displacements = 'disp_x disp_y disp_z' 
[]
[AuxVariables]
  # 先定义环向应力，以便后续AuxKernels用于导出应力数据
  [./hoop_stress]
    order = CONSTANT
    family = MONOMIAL
  [../]
[]

[AuxKernels]
  # 导出应力，以便于ParaView查看应力分布
  [./hoop_stress]
    type = ADRankTwoScalarAux
    variable = hoop_stress #对应AuxVariables中的hoop_stress
    rank_two_tensor = stress #对应Materials中的stress
    scalar_type = HoopStress #用什么方式处理这个stress即计算出我们需要的查看或分析的环向应力hoop_stress？
    point1 = '0 0 0'        # 圆心坐标
    point2 = '0 0 -1'        # 定义旋转轴方向（z轴）

    # 执行时机
    execute_on = 'TIMESTEP_END'
    #INITIAL - 仅在模拟开始时执行一次（初始条件的设置，只需计算一次的参数）
    #TIMESTEP_BEGIN - 在每个时间步开始时执行（需要在时间步开始时更新的变量，作为其他计算的输入量，边界条件的更新）
    #TIMESTEP_END - 在每个时间步结束时执行（不需要参与主要计算的辅助变量，输出结果，计算后处理量（如应力、应变等））
    #NONLINEAR - 在每个非线性迭代时执行（参与非线性求解的变量，需要在每次迭代中更新的量，耦合项的计算）
    #LINEAR - 在每个线性迭代时执行
    #TIMESTEP - 等同于 TIMESTEP_BEGIN
    #FINAL - 在模拟结束时执行
    #CUSTOM - 自定义执行时机
  [../]
[]

[Variables]
    [disp_x]
    []
    [disp_y]
    []
    [disp_z]
    []
[]
[Kernels]
  # 定义应力平衡方程
  # 应力平衡方程：σ_ij,j + f_i = 0
  # 其中，σ_ij是应力张量，f_i是体力（如重力），j是空间坐标。
  # 在有限元中，应力平衡方程通过将应力张量与位移梯度（即应变）联系起来，并考虑边界条件和载荷来求解。
  # 应力平衡方程在每个节点上建立，形成一个线性方程组，通过求解这个方程组可以得到节点的位移。
  # 应力平衡方程是结构分析中的基本方程，用于描述材料在受力作用下的变形和应力分布。
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
[]

[BCs]
  # 定义边界条件
  [y_zero_on_y_plane]
    #y平面上的y的位移为0
    type = DirichletBC
    variable = disp_y
    boundary = 'yplane'
    value = 0
  []
  [x_zero_on_x_plane]
    #x平面上的x的位移为0
    type = DirichletBC
    variable = disp_x
    boundary = 'xplane'
    value = 0
  []
  [z_zero_on_bottom]
    #底面上的z的位移为0
    type = DirichletBC
    variable = disp_z
    boundary = 'bottom'
    value = 0
  []
  [PressureOnBoundaryX]
    #芯块包壳间隙压力
    type = Pressure
    variable = disp_x
    boundary = 'clad_inner pellet_outer'
    factor = 1e6 #压力大小
    use_displaced_mesh = true #是否使用变形网格
  []
  [PressureOnBoundaryY]
    #芯块包壳间隙压力
    type = Pressure
    variable = disp_y
    boundary = 'clad_inner pellet_outer'
    factor = 1e6 #压力大小
    use_displaced_mesh = true #是否使用变形网格
  []
[]
#
[Materials]
  # 定义材料属性
    [pellet_strain]
        type = ADComputeSmallStrain 
        block = pellet
    []
    [pellet_elasticity_tensor]
      type = ADComputeIsotropicElasticityTensor
      youngs_modulus = ${pellet_elastic_constants}
      poissons_ratio = ${pellet_nu}
      block = pellet
    []

    [clad_strain]
      type = ADComputeSmallStrain 
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
[Executioner]
    type = Transient
    solve_type = 'NEWTON'
    dt = 1
    end_time = 5
  []
[Outputs]
  exodus = true
[]