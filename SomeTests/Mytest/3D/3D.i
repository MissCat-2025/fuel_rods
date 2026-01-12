# 陶瓷片热冲击实验 - 热弹性模拟部分
# conda activate moose &&dos2unix 3D.i&& mpirun -n 8 /home/yp/projects/fuel_rods/fuel_rods-opt -i 3D.i

[GlobalParams]
  displacements = 'disp_x disp_y disp_z'
[]

# 陶瓷材料参数
E_ceramic = 370e9       # 陶瓷杨氏模量 (Pa)
nu_ceramic = 0.3       # 陶瓷泊松比
alpha_ceramic = 7.5e-6    # 陶瓷热膨胀系数 (1/°C)
k_ceramic = 310          # 陶瓷导热系数 (W/m·K)
cp_ceramic = 8800        # 比热容 (J/kg·K)
rho_ceramic = 3980      # 密度 (kg/m³)
[Mesh]
  [gmg]
    type = GeneratedMeshGenerator
    dim = 3
    nx = 50            # 25mm / 0.05mm = 500
    ny = 10            # 5mm / 0.05mm = 100
    nz = 1            # 5mm / 0.05mm = 100
    xmax = 25e-3
    ymax = 5e-3
    zmax = 0.5e-3
  []
      [center_point]
    type = ExtraNodesetGenerator
    input = gmg
    coord = '0 0 0'
    new_boundary  = 'center_point'
  []
[]
[Variables]
  [disp_x]
  []
  [disp_y]
  []
  [disp_z]
  []
  [temp]
    initial_condition = 293.15
  []
[]

[AuxVariables]
  [MaxPrincipal]
    order = CONSTANT
    family = MONOMIAL
  []
[]

[Kernels]
  # 力学平衡（平面应变）
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
  [solid_z]
    type = ADStressDivergenceTensors
    variable = disp_z
    component = 2
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
    boundary = center_point
    value = 0
  []
  [symm_y]
    type = DirichletBC
    variable = disp_y
    boundary = center_point
    value = 0
  []
  [symm_z]
    type = DirichletBC
    variable = disp_z
    boundary = center_point
    value = 0
  []
  # # 热边界条件
  [left_temp]
    type = DirichletBC
    variable = temp
    boundary = 'left'
    value = 293.15  # 水淬温度20°C
  []
  [right_temp]
    type = DirichletBC
    variable = temp
    boundary = 'right'
    value = 1293.15  # 水淬温度20°C
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
  [elastic_tensor]
    type = ADComputeIsotropicElasticityTensor
    poissons_ratio = ${nu_ceramic}
    youngs_modulus = ${E_ceramic}
  []
  [eigenstrain]
    type = ADComputeThermalExpansionEigenstrain
    eigenstrain_name = thermal_eigenstrain
    stress_free_temperature = 293.15  # 应力自由温度为初始温度
    thermal_expansion_coeff = ${alpha_ceramic}
    temperature = temp
  []
  [strain]
    type = ADComputeSmallStrain
    eigenstrain_names = thermal_eigenstrain
  []
  [stress]
    type = ADComputeLinearElasticStress
  []
[]
[Postprocessors]
  [avg_temp]
    type = ElementAverageValue
    variable = temp
  []
  [max_MaxPrincipal]
    type = ElementExtremeValue
    variable = MaxPrincipal
    value_type = max
  []
[]

[Executioner]
  type = Transient

  solve_type = PJFNK
  line_search = BT

# controls for linear iterations
  l_max_its = 300
  l_tol = 1e-10

# controls for nonlinear iterations
  nl_max_its = 20
  nl_rel_tol = 1e-10
  nl_abs_tol = 1e-9

# time control
  start_time = 0.0
  dt = 0.1
  end_time = 1
[]

[Outputs]
  exodus = true
  print_linear_residuals = false
    [csv]
    type = CSV
    file_base = '3D'
  []
[]
