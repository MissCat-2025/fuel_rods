# 这第一步就是为生成网格文件Oconee_Rod_15309.e
# 语法要求：仅仅为了生成网格文件：Run with --mesh-only:
#https://mooseframework.inl.gov/source/meshgenerators/ConcentricCircleMeshGenerator.html
#   mpirun -n 10 ../../fuel_rods-opt -i step1_to_generate_e.i --mesh-only Oconee_Rod_15309.e
#《《下面数据取自[1]邓超群, 向烽瑞, 贺亚男, 等. 基于MOOSE平台的棒状燃料元件性能分析程序开发与验证[J]. 原子能科学技术, 2021, 55(7): 1296-1303.》》

pellet_outer_diameter = 9.3218 # 芯块外直径9.3218m
clad_inner_diameter = 9.5758 # 包壳内直径9.5758m
clad_outer_diameter = 10.922 # 包壳外直径10.922m
pellet_outer_radius = '${fparse pellet_outer_diameter/2*1e-3}'#直径变半径，并且单位变mm
clad_inner_radius = '${fparse clad_inner_diameter/2*1e-3}'#直径变半径，并且单位变mm
clad_outer_radius = '${fparse clad_outer_diameter/2*1e-3}'#直径变半径，并且单位变mm
length = 17.78e-3 # 芯块长度17.78mm

n_elems_axial = 2 # 轴向网格数
n_elems_azimuthal = 50 # 周向网格数

n_elems_radial_clad = 4 # 包壳径向网格数
n_elems_radial_pellet = 30 # 芯块径向网格数

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
