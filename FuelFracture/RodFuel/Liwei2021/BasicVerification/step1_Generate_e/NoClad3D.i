# (这第一步就是测试生成网格文件UnknownRod1_NoClad3D_quarter.e   注意：这文件生成的是不带外包壳的3D模型，而且是1/4模型3D模型
# 语法要求：仅仅为了生成网格文件：Run with --mesh-only:
#https://mooseframework.inl.gov/source/meshgenerators/ConcentricCircleMeshGenerator.html
#conda activate moose
#mpirun -n 10 /home/yp/projects/raccoon/raccoon-opt -i NoClad3D.i --mesh-only UnknownRod1_NoClad3D.e


# 各种参数都取自[1]Multiphysics phase-field modeling of quasi-static cracking in urania ceramic nuclear fuel
#几何与网格参数
pellet_outer_radius = 4.1e-3#直径变半径，并且单位变mm
length = 4.75e-5 # 芯块长度17.78mm
n_elems_axial = 1 # 轴向网格数
grid_sizes = 2.9e-4 #mm,最大网格尺寸（虚），1.9e-4真实的网格尺寸为4.75e-5
#将下列参数转化为整数
n_elems_azimuthal = '${fparse 2*ceil(3.1415*2*pellet_outer_radius/grid_sizes/2)}'  # 周向网格数（向上取整）
n_elems_radial_pellet = '${fparse int(pellet_outer_radius/grid_sizes)}'          # 芯块径向网格数（直接取整）

#自适应法线公差
normal_tol = '${fparse 3.14*pellet_outer_radius/n_elems_azimuthal*1e-3/100}'

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
# 创建x轴切割边界面 (y=0线)
[x_axis_cut]
  type = SideSetsBetweenSubdomainsGenerator
  input = rename2
  new_boundary = 'yplane'
  primary_block = 'pellet'
  paired_block = 'pellet'
  normal = '0 1 0'  # 法线方向为Y轴
  normal_tol = '${normal_tol}'
[]
# 创建x轴切割边界面 (y=0线)
[y_axis_cut]
  type = SideSetsBetweenSubdomainsGenerator
  input = x_axis_cut
  new_boundary = 'xplane'
  primary_block = 'pellet'
  paired_block = 'pellet'
  normal = '1 0 0'  # 法线方向为X轴
  normal_tol = '${normal_tol}'
[]
[]