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