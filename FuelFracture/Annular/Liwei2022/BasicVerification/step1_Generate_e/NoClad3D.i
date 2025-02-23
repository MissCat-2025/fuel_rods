# (已验证)这第一步就是测试生成网格文件KAERI_HANARO_UpperRod1_NoClad3D.e   注意：这文件生成的是无内外包壳的3D模型，而不是1/4模型3D模型
# 语法要求：仅仅为了生成网格文件：Run with --mesh-only:
#https://mooseframework.inl.gov/source/meshgenerators/ConcentricCircleMeshGenerator.html
#mpirun -n 10 ../../../../../raccoon-opt -i NoClad3D.i --mesh-only KAERI_HANARO_UpperRod1_NoClad3D.e
#《《下面数据取自[1]Thermomechanical Analysis and Irradiation Test of Sintered Dual-Cooled Annular pellet》》

# 双冷却环形燃料几何参数 (单位：mm)(无内外包壳)
pellet_inner_diameter = 10.291         # 芯块内直径
pellet_outer_diameter = 14.627         # 芯块外直径
length = 6e-5                    # 轴向长度(m)
# 网格控制参数n_azimuthal = 512时网格尺寸为6.8e-5m
n_radial_pellet = 32          # 燃料径向单元数
n_azimuthal = 512           # 周向基础单元数
growth_factor = 1.0        # 径向增长因子
n_axial = 1                # 轴向单元数
# 计算半径参数 (转换为米)
pellet_inner_radius = '${fparse pellet_inner_diameter/2*1e-3}'
pellet_outer_radius = '${fparse pellet_outer_diameter/2*1e-3}'
#自适应法线公差
normal_tol = '${fparse 3.14*pellet_inner_diameter/n_azimuthal*1e-3/10}'
[Mesh]
  [pellet1]
    type = AnnularMeshGenerator
    nr = ${n_radial_pellet}
    nt = ${n_azimuthal}
    rmin = ${pellet_inner_radius}
    rmax = ${pellet_outer_radius}
    growth_r = ${growth_factor}
    boundary_id_offset = 10
    boundary_name_prefix = 'pellet'
  []
  [pellet]
    type = SubdomainIDGenerator
    input = pellet1
    subdomain_id = 1
  []
  [rename1]
    type = RenameBoundaryGenerator
    input = pellet
    old_boundary = 'pellet_rmin pellet_rmax'
    new_boundary = 'pellet_inner pellet_outer'
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
    old_block = '1'
    new_block = 'pellet'
  []
  # 创建x轴切割边界面 (y=0线)
  [x_axis_cut]
    type = SideSetsBetweenSubdomainsGenerator
    input = rename2
    new_boundary = 'x_axis'
    primary_block = 'pellet'
    paired_block = 'pellet'
    normal = '0 1 0'  # 法线方向为Y轴
    normal_tol = '${normal_tol}'
  []
  # 创建x轴切割边界面 (y=0线)
  [y_axis_cut]
    type = SideSetsBetweenSubdomainsGenerator
    input = x_axis_cut
    new_boundary = 'y_axis'
    primary_block = 'pellet'
    paired_block = 'pellet'
    normal = '1 0 0'  # 法线方向为X轴
    normal_tol = '${normal_tol}'
  []
[]
