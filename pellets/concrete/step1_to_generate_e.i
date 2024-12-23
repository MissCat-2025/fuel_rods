# 这第一步就是为生成网格文件Oconee_Rod_15309.e
# 语法要求：仅仅为了生成网格文件：Run with --mesh-only:
#https://mooseframework.inl.gov/source/meshgenerators/ConcentricCircleMeshGenerator.html
#   mpirun -n 10 ../../fuel_rods-opt -i step1_to_generate_e.i --mesh-only Oconee_Rod_15309.e
#《《下面数据取自[1]邓超群, 向烽瑞, 贺亚男, 等. 基于MOOSE平台的棒状燃料元件性能分析程序开发与验证[J]. 原子能科学技术, 2021, 55(7): 1296-1303.》》
l=0.005#相场断裂尺度参数
x = '${fparse l/5}' #网格尺寸



steel_ring_inner_diameter = 0.281 # 钢环内直径9.5758mm
concrete_inner_diameter = 0.3 # 包壳内直径9.5758mm
concrete_outer_diameter = 0.45 # 包壳外直径10.922mm

steel_ring_inner_radius = '${fparse steel_ring_inner_diameter/2}'#直径变半径，并且单位变mm
concrete_inner_radius = '${fparse concrete_inner_diameter/2}'#直径变半径，并且单位变mm
concrete_outer_radius = '${fparse concrete_outer_diameter/2}'#直径变半径，并且单位变mm


n_elems_azimuthal = '${fparse ceil(0.4*3.14*concrete_outer_diameter/x)}' #网格尺寸 # 周向网格数


n_elems_steel_ring = '${fparse ceil((concrete_inner_diameter-steel_ring_inner_diameter)/x)}' #网格尺寸 # 钢环径向网格数
n_elems_concrete = '${fparse ceil((concrete_outer_diameter-concrete_inner_diameter)/x)}' #网格尺寸 # 包壳径向网格数

[Mesh]
    [pellet_clad_gap]
      type = ConcentricCircleMeshGenerator
      num_sectors = '${n_elems_azimuthal}'
      radii = '${steel_ring_inner_radius} ${concrete_inner_radius} ${concrete_outer_radius}'
      rings = '1 ${n_elems_steel_ring} ${n_elems_concrete}'
      has_outer_square = false
      preserve_volumes = true
      portion = top_right
      # smoothing_max_it=10
    []

    [rename_steel_ring_inner_bdy]
      type = SideSetsBetweenSubdomainsGenerator
      input = pellet_clad_gap
      primary_block = 2
      paired_block = 1
      new_boundary = 'steel_ring_inner'
    []
    [rename_steel_ring_outer_bdy]
      type = SideSetsBetweenSubdomainsGenerator
      input = rename_steel_ring_inner_bdy
      primary_block = 3
      paired_block = 2
      new_boundary = 'steel_ring_outer'
    []

    [2d_mesh]
      type = BlockDeletionGenerator
      input = rename_steel_ring_outer_bdy
      block = 1
    []
    [rename]
      type = RenameBoundaryGenerator
      input = 2d_mesh
      old_boundary = 'bottom left outer'
      new_boundary = 'x_axis y_axis concrete_outer'

    []
  [rename2]
    type = RenameBlockGenerator
    input = rename
    old_block  = '2 3'
    new_block  = 'steel_ring concrete'
  []
[]
