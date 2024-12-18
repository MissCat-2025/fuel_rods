[GlobalParams]
  displacements = 'disp_x disp_y disp_z'
  origin = '0 0 2'
  direction = '0 0 1'
  polar_moment_of_inertia = pmi
  factor = t
[]

[Mesh]
  [pellet]  # 生成芯块网格
    type = AnnularMeshGenerator
    nr = 8     # 径向网格数
    nt = 20     # 周向网格数
    rmin = 0    # 芯块内径(实心圆柱)
    rmax = 4.1  # 芯块外径(mm)
    dmin = 0
    dmax = 360
    growth_r = 0.75
    boundary_id_offset = 0  # 添加这行
    boundary_name_prefix = 'pellet_'  # 添加这行，给芯块的边界添加前缀
  []
  [cladding]  # 生成包壳网格 
    type = AnnularMeshGenerator
    nr = 2
    nt = 20  
    rmin = 4.15  # 包壳内径(mm)
    rmax = 4.75  # 包壳外径(mm)
    dmin = 0
    dmax = 360
    growth_r = 1.0
    boundary_id_offset = 10  # 添加这行，确保与芯块的边界ID不重叠
    boundary_name_prefix = 'clad_'  # 添加这行，给包壳的边界添加前缀
  []
  [two_blocks]
    type = MeshCollectionGenerator
    inputs = 'pellet cladding'
  []
  [extrude]
    type = MeshExtruderGenerator
    input = two_blocks
    extrusion_vector = '0 0 10'  # 高度方向
    num_layers = 10
    bottom_sideset = 'bottom'
    top_sideset = 'top'
  []
[]

[AuxVariables]
  [alpha_var]
  []
  [shear_stress_var]
    order = CONSTANT
    family = MONOMIAL
  []
[]

[AuxKernels]
  [alpha]
    type = RotationAngle
    variable = alpha_var
  []
  [shear_stress]
    type = ParsedAux
    variable = shear_stress_var
    coupled_variables = 'stress_yz stress_xz'
    expression = 'sqrt(stress_yz^2 + stress_xz^2)'
  []
[]

[BCs]
  # fix bottom
  [fix_x]
    type = DirichletBC
    boundary = bottom
    variable = disp_x
    value = 0
  []
  [fix_y]
    type = DirichletBC
    boundary = bottom
    variable = disp_y
    value = 0
  []
  [fix_z]
    type = DirichletBC
    boundary = bottom
    variable = disp_z
    value = 0
  []

  # twist top
  [twist_x]
    type = Torque
    boundary = top
    variable = disp_x
  []
  [twist_y]
    type = Torque
    boundary = top
    variable = disp_y
  []
  [twist_z]
    type = Torque
    boundary = top
    variable = disp_z
  []
[]

[Physics/SolidMechanics/QuasiStatic]
  [all]
    add_variables = true
    strain = SMALL
    generate_output = 'vonmises_stress stress_yz stress_xz'
  []
[]

[Postprocessors]
  [pmi]
    type = PolarMomentOfInertia
    boundary = top
    # execute_on = 'INITIAL NONLINEAR'
    execute_on = 'INITIAL'
  []
  [alpha]
    type = SideAverageValue
    variable = alpha_var
    boundary = top
  []
  [shear_stress]
    type = ElementAverageValue
    variable = shear_stress_var
  []
[]

[Materials]
  [stress]
    type = ComputeLinearElasticStress
  []
  [elastic]
    type = ComputeIsotropicElasticityTensor
    youngs_modulus = 0.3
    shear_modulus = 100
  []
[]

[Executioner]
  # type = Steady
  type = Transient
  num_steps = 1
  solve_type = PJFNK
  petsc_options_iname = '-pctype'
  petsc_options_value = 'lu'
  nl_max_its = 150
[]

[Outputs]
  exodus = true
  print_linear_residuals = false
  # perf_graph = true
[]
