# 这第一步就是为生成网格文件Oconee_Rod_15309.e
# 语法要求：仅仅为了生成网格文件：Run with --mesh-only:
#
#   mpirun -n 10 ../../fuel_rods-opt -i step1_to_generate_e.i --mesh-only Oconee_Rod_15309.e
#《《下面数据取自[1]邓超群, 向烽瑞, 贺亚男, 等. 基于MOOSE平台的棒状燃料元件性能分析程序开发与验证[J]. 原子能科学技术, 2021, 55(7): 1296-1303.》》

pellet_outer_diameter = 9.3218 # 芯块外直径9.3218mm
clad_inner_diameter = 9.5758 # 包壳内直径9.5758mm
clad_outer_diameter = 10.922 # 包壳外直径10.922mm
pellet_outer_radius = '${fparse pellet_outer_diameter/2*1e-3}'#直径变半径，并且单位变mm
clad_inner_radius = '${fparse clad_inner_diameter/2*1e-3}'#直径变半径，并且单位变mm
clad_outer_radius = '${fparse clad_outer_diameter/2*1e-3}'#直径变半径，并且单位变mm
length = 17.78e-3 # 芯块长度17.78mm

n_elems_axial = 10 # 芯块轴向网格数
n_elems_azimuthal = 10 # 芯块周向网格数
n_elems_radial_pellet = 15 # 芯块径向网格数
n_elems_radial_clad = 5 # 包壳径向网格数


[Mesh]
      #这里需要注意的是：
    #二维芯块的单元类型是四边形和三角形，圆心一定范围的小区域是三角形,其他为四边形,二维包壳的单元类型是四边形
    #很明显,我们想要block1为芯块,block2为包壳.这样可大大方便写代码,但是
    #默认的block划分中,block划分的依据为单元类型,而不是我们想要的依据为几何形状
    #最终我们通过设置quad_subdomain_id和tri_subdomain_id,将block1设置为四边形芯块,block2设置为四边形包壳,block3设置为三角形芯块
  [pellet]
    type = AnnularMeshGenerator
    rmin = 0    # 芯块内径(实心圆柱)
    rmax = '${pellet_outer_radius}'  # 芯块外径(mm)
    nr = '${n_elems_radial_pellet}'     # 径向网格数
    nt = '${n_elems_azimuthal}'     # 周向网格数
    dmin = 0
    dmax = 90 # 周向角度，0-90是圆周四分之一，360是整个圆周
    growth_r = 0.88 # 径向增长因子，越小，网格加密越靠近芯块外径
    boundary_id_offset = 0  # 添加这行为了确保与包壳的边界ID不重叠
    boundary_name_prefix = 'pellet_'  # 添加这行，给芯块的边界添加前缀


    quad_subdomain_id = 1  # 添加这行，将四边形单元分配到子区域1
    tri_subdomain_id = 3   # 添加这行，将三角形单元分配到子区域3,因为同一个block的单元类型是相同的
  []
    [cladding]  # 生成包壳网格 
      type = AnnularMeshGenerator
      nr = '${n_elems_radial_clad}'
      nt = '${n_elems_azimuthal}'  
      rmin = '${clad_inner_radius}'  # 包壳内径(mm)
      rmax = '${clad_outer_radius}'  # 包壳外径(mm)
      dmin = 0
      dmax = 90
      growth_r = 1.25
      boundary_id_offset = 10  # 添加这行，确保与芯块的边界ID不重叠
      boundary_name_prefix = 'clad_'  # 添加这行，给包壳的边界添加前缀
    quad_subdomain_id = 2  # 添加这行，将包壳的四边形单元分配到子区域2
  []
  [two_blocks]
    type = MeshCollectionGenerator
    inputs = 'pellet cladding'
  []
  [rename_blocks]
    type = RenameBlockGenerator
    input = two_blocks
    old_block = '1 2 3'
    new_block = 'pellet_hex_block clad_block pellet_prism_block'
  []
  [extrude]
    type = MeshExtruderGenerator
    input = rename_blocks
    extrusion_vector = '0 0 ${length}'
    num_layers = '${n_elems_axial}'
    bottom_sideset = 'bottom'
    top_sideset = 'top'
  []
  final_generator = extrude
[]