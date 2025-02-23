# 这第一步就是为生成网格文件Granite.e
# 语法要求：仅仅为了生成网格文件：Run with --mesh-only:
#https://mooseframework.inl.gov/source/meshgenerators/PolygonConcentricCircleMeshGenerator.html
#《[1] WEI LI, KOROUSH SHIRVAN. Multiphysics phase-field modeling of quasi-static cracking in urania ceramic nuclear fuel[J/OL]. Ceramics International, 2021, 47(1): 793-810. DOI:10.1016/j.ceramint.2020.08.191.

# mpirun -n 10 ../../fuel_rods-opt -i step1Mesh.i --mesh-only Granite.e

[Mesh]
  final_generator = hole
  
  [square]
    type = GeneratedMeshGenerator
    dim = 2
    nx = 30
    ny = 30
    xmin = -7.5
    xmax = 7.5
    ymin = -7.5
    ymax = 7.5
  []
  
  [hole]
    type = AnnularMeshGenerator
    input = square
    rmin = 0.5    # 内圆半径
    rmax = 0.6    # 外圆半径
    nt = 16       # 角向网格数
  []
[]

[Outputs]
  exodus = true
[]