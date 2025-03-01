# 陶瓷片热冲击实验 - 热弹性模拟部分
[GlobalParams]
  displacements = 'disp_x disp_y'
[]

# 陶瓷材料参数
E_ceramic = 370e9       # 陶瓷杨氏模量 (Pa)
nu_ceramic = 0.3       # 陶瓷泊松比
alpha_ceramic = 7.5e-6    # 陶瓷热膨胀系数 (1/°C)
k_ceramic = 31          # 陶瓷导热系数 (W/m·K)
cp_ceramic = 880        # 比热容 (J/kg·K)
rho_ceramic = 3980      # 密度 (kg/m³)
K = '${fparse E_ceramic/3/(1-2*nu_ceramic)}'
G = '${fparse E_ceramic/2/(1+nu_ceramic)}'

# 断裂参数
Gc = 42.47               # 断裂能 (J/m^2)
l = 0.04e-3                # 相场正则化长度 (m)
ft = 180e6                # 抗拉强度 (Pa)
a1 = '${fparse 4*E_ceramic*Gc/ft/ft/3.14159/l}' 

[Mesh]
  [gmg]
    type = GeneratedMeshGenerator
    dim = 2
    nx = 250            # 25mm / 0.05mm = 500
    ny = 100            # 5mm / 0.05mm = 100
    xmax = 25e-3
    ymax = 10e-3
  []
[]

[Variables]
  [disp_x]
  []
  [disp_y]
  []
  [temp]
    initial_condition = 573.15  # 初始温度300°C
  []
[]

[AuxVariables]
  [d]                         # 相场变量
  []
  [psie_active]               # 有效应变能密度
    order = CONSTANT
    family = MONOMIAL
  []
  [MaxPrincipal]
    order = CONSTANT
    family = MONOMIAL
  []
[]

[Kernels]
  # 力学平衡
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
  
  # 热传导
  [heat_conduction]
    type = ADHeatConduction
    variable = temp
  []
  [heat_dt]
    type = ADHeatConductionTimeDerivative
    variable = temp
  []
[]

[AuxKernels]
  [psie_active]
    type = ADMaterialRealAux
    variable = psie_active
    property = psie_active
  []
  [MaxPrincipalStress]
    type = ADRankTwoScalarAux
    variable = MaxPrincipal
    rank_two_tensor = stress
    scalar_type = MaxPrincipal
    execute_on = 'TIMESTEP_END'
  []
[]

[BCs]
  # 力学边界条件 - 右侧对称面
  [symm_x]
    type = DirichletBC
    variable = disp_x
    boundary = left
    value = 0
  []
  [symm_y]
    type = DirichletBC
    variable = disp_y
    boundary = bottom
    value = 0
  []
  
  # 热边界条件
  [left_temp]
    type = DirichletBC
    variable = temp
    boundary = 'top right bottom'
    value = 298.15  # 水淬温度20°C
  []
  # 右侧为绝热边界 - 不需要额外的边界条件
[]

[Materials]
  # 热物理属性
  [thermal]
    type = ADGenericConstantMaterial
    prop_names = 'thermal_conductivity specific_heat density'
    prop_values = '${k_ceramic} ${cp_ceramic} ${rho_ceramic}'
  []
  
  # 断裂属性
  [bulk_properties]
    type = ADGenericConstantMaterial
    prop_names = 'K G l a1 ft Gc'
    prop_values = '${K} ${G} ${l} ${a1} ${ft} ${Gc}'
  []
  
  # 相场断裂模型材料
  [crack_geometric]
    type = CrackGeometricFunction
    property_name = alpha
    expression = '2*d-d*d'
    phase_field = d
  []
  
  [degradation]
    type = RationalDegradationFunction
    property_name = g
    expression = (1-d)^p/((1-d)^p+a1*d*(1+a2*d+a3*d^2))*(1-eta)+eta
    phase_field = d
    material_property_names = 'a1'
    parameter_names = 'p a2 a3 eta'
    parameter_values = '2 -0.5 0 1e-6'
  []
  
  [eigenstrain]
    type = ADComputeThermalExpansionEigenstrain
    eigenstrain_name = thermal_eigenstrain
    stress_free_temperature = 573.15  # 应力自由温度为初始温度
    thermal_expansion_coeff = ${alpha_ceramic}
    temperature = temp
  []
  
  [strain]
    type = ADComputeSmallStrain
    eigenstrain_names = thermal_eigenstrain
  []
  
  # [elasticity]
  #   type = SmallDeformationHBasedElasticity
  #   youngs_modulus = E
  #   poissons_ratio = nu
  #   tensile_strength = ft
  #   fracture_energy = Gc
  #   phase_field = d
  #   degradation_function = g
  # []
  [elasticity]
    type = SmallDeformationIsotropicElasticity
    bulk_modulus = K
    shear_modulus = G
    phase_field = d
    degradation_function = g
    decomposition = SPECTRAL
  []


  
  [stress]
    type = ComputeSmallDeformationStress
    elasticity_model = elasticity
  []
[]

[MultiApps]
  [fracture]
    type = TransientMultiApp
    input_files = ceramic_fracture_sub.i
    cli_args = 'Gc=${Gc};a1=${a1};l=${l}'
    execute_on = 'TIMESTEP_END'
  []
[]

[Transfers]
  [from_d]
    type = MultiAppGeneralFieldShapeEvaluationTransfer
    from_multi_app = 'fracture'
    variable = d
    source_variable = d
  []
  [to_psie_active]
    type = MultiAppGeneralFieldShapeEvaluationTransfer
    to_multi_app = 'fracture'
    variable = psie_active
    source_variable = psie_active
  []
[]

[Executioner]
  type = Transient
  
  solve_type = 'NEWTON'
  petsc_options_iname = '-ksp_gmres_restart -pc_type -pc_hypre_type'
  petsc_options_value = '201                hypre    boomeramg'
  automatic_scaling = true
  
  nl_rel_tol = 1e-7
  nl_abs_tol = 1e-8
  
  # 时间步长设置
  dt = 0.1e-3  # 小的时间步长以捕捉快速的温度变化
  end_time = 20e-3  # 总模拟时间
  
  fixed_point_max_its = 4
  fixed_point_rel_tol = 1e-5
  fixed_point_abs_tol = 1e-6
  accept_on_max_fixed_point_iteration = true
[]

[Outputs]
  exodus = true
  print_linear_residuals = false
[]