#这一步的目的是计算燃料棒的应力分布
#根据前一步生成的网格文件Oconee_Rod_15309.e，现在给包壳与芯块内外一个压力，计算燃料棒的应力分布

# F_density=10412.0#10960.0*0.95#kg⋅m-3
F_elastic_constants=2.2e11#Pa
F_nu = 0.345

# C_density=6.59e3#kg⋅m-3
# C_elastic_constants=7.52e10#Pa
# C_nu = 0.33

[Mesh]
    file = 'Oconee_Rod_15309.e'

[GlobalParams]
    displacements = 'disp_x disp_y disp_z'

[Variables]
    [disp_x]
    []
    [disp_y]
    []
    [disp_z]
    []

[Kernels]
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
[]
[BCs]
  [x_zero_on_y_axis]
    type = DirichletBC
    variable = disp_y
    boundary = 'yplane'
    value = 0
  []
  [y_zero_on_x_axis]
    type = DirichletBC
    variable = disp_x
    boundary = 'xplane'
    value = 0
  []

#  # 修改冷却剂压力边界条件
#   [colden_pressure_fuel_x]
#     type = Pressure
#     variable = disp_x
#     boundary = clad_outer
#     factor = 15.5e6    # 2.5 MPa 转换为 Pa
#     use_displaced_mesh = true
#   []
#   [colden_pressure_fuel_y]
#     type = Pressure
#     variable = disp_y
#     boundary = clad_outer
#     factor = 15.5e6    # 2.5 MPa 转换为 Pa
#     use_displaced_mesh = true
#   []

#   # 修改间隙压力边界条件
#   [gap_pressure_fuel_x]
#     type = Pressure
#     variable = disp_x
#     boundary = 'pellet_outer clad_inner'
#     factor = 2.5e6    # 2.5 MPa 转换为 Pa
#     use_displaced_mesh = true
#   []
#   [gap_pressure_fuel_y]
#     type = Pressure
#     variable = disp_y
#     boundary = 'pellet_outer clad_inner'
#     factor = 2.5e6   # 2.5 MPa 转换为 Pa
#     use_displaced_mesh = true
#   []
[]
[Materials]
    [strain_clad]
        type = ADComputeSmallStrain 
    []
    [elasticity_tensor]
        type = ADComputeIsotropicElasticityTensor
        youngs_modulus = ${F_elastic_constants}
        poissons_ratio = ${F_nu}
    []
    [stress]
        type = ADComputeLinearElasticStress
    []
[]

[Executioner]
    type = Steady
    solve_type = 'NEWTON'
  []
[Outputs]
  exodus = true
[]