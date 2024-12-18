[GlobalParams]
  displacements = 'disp_r disp_z'
[]

[Mesh]
  # coord_type = RZ
  [fmg]
    type = FileMeshGenerator
    file = 'IFA_432r1_quarter_2790.e'
  []
  coord_type = RZ
[]
  
# [Problem]
#   coord_type = RZ
# []

[Variables]
  [./disp_r]
  [../]
  [./disp_z]
  [../]
  [./T]
  [../]
[]
  

[BCs]
  #包壳外表面
  [coolant_bc]#对流边界条件
    type = ADConvectiveHeatFluxBC
    variable = T
    boundary = clad_outer_surface
    T_infinity = 530
    heat_transfer_coefficient =74e2#3.4e4 W·m-2 K-1
  []
  # [x_zero_on_y_axis]
  #   type = DirichletBC
  #   variable = disp_z
  #   boundary = y_plane
  #   value = 0
  # []
  # [y_zero_on_x_axis]
  #   type = DirichletBC
  #   variable = disp_x
  #   boundary = x_plane
  #   value = 0
  # []
  [disp_z_fixed]
    type = DirichletBC
    variable = disp_z
    boundary = z_plane
    value = 0
  []

 # 修改冷却剂压力边界条件
  [colden_pressure_fuel_x]
    type = Pressure
    variable = disp_r
    boundary = clad_outer_surface
    factor = 15.5e6    # 2.5 MPa 转换为 Pa
    use_displaced_mesh = true
  []

  # 修改间隙压力边界条件
  [gap_pressure_fuel_x]
    type = Pressure
    variable = disp_r
    boundary = fuel_outer_surface
    factor = 2.5e6    # 2.5 MPa 转换为 Pa
    function = gap_pressure
    use_displaced_mesh = true
  []

  [gap_pressure_clad_x]
    type = Pressure
    variable = disp_r
    boundary = clad_inner_surface
    factor = 2.5e6   # 2.5 MPa 转换为 Pa
    function = gap_pressure
    use_displaced_mesh = true
  []

[]




[Kernels]
  [./cx_elastic]
    type = StressDivergenceRZTensors
    variable = disp_r
    temperature = T
    eigenstrain_names = thermal_eigenstrain
    use_displaced_mesh = true
    component = 0
  [../]
  [./cz_elastic]
    type = StressDivergenceRZTensors
    variable = disp_z
    temperature = T
    eigenstrain_names = thermal_eigenstrain
    use_displaced_mesh = true
    component = 1
  [../]
    [heat_conduction]
      type = ADHeatConduction
      variable = T
    []
    [hcond_time]
      type = ADHeatConductionTimeDerivative
      variable = T
    []
    [Fheat_source]
      type = HeatSource
      variable = T
      function = power_history
      block = fuel
    []
[]
  
  [Materials]
      # 燃料芯块材料属性
    [fuel_thermal]
      type = ADGenericConstantMaterial
      prop_names = 'density thermal_conductivity specific_heat'
      prop_values = '10412 5 400'
    []
    [./elasticity_tensor]
      type = ComputeIsotropicElasticityTensor
      youngs_modulus = 2.2e11
      poissons_ratio = 0.25
    [../]
    [./strain]
      type = ComputeAxisymmetricRZSmallStrain
      eigenstrain_names = thermal_eigenstrain
    [../]
    [./thermal_expansion]
      type = ComputeThermalExpansionEigenstrain
      temperature = T
      thermal_expansion_coeff = 5.0e-6
      eigenstrain_name = thermal_eigenstrain
      stress_free_temperature = 0.0
    [../]
    [./admissible]
      type = ComputeLinearElasticStress
    [../]
  []
  [ThermalContact]
    [./thermal_contact]
      type = GapHeatTransfer
      variable = T
      primary = clad_inner_surface
      secondary = fuel_outer_surface
      emissivity_primary =1
      emissivity_secondary =1
      gap_conductivity = 61
      quadrature = true
      gap_geometry_type = CYLINDER
      cylinder_axis_point_1 = '0 0 0'
      cylinder_axis_point_2 = '0 1 0'
    [../]
  []
  [Executioner]
    type = Transient

    #Preconditioned JFNK (default)
    solve_type = 'PJFNK'
  
    petsc_options_iname = '-pc_type -pc_factor_mat_solver_package'
    petsc_options_value = 'lu       superlu_dist'
  
    dt = 1
    dtmin = 0.01
    end_time = 3
  
    nl_rel_tol = 1e-12
    nl_abs_tol = 1e-7
  []
  [Outputs]
    execute_on = 'INITIAL TIMESTEP_END'
    exodus = true
    print_linear_residuals = false
    checkpoint = false        
    file_base = 'outputs/pellet1'
  []