# GeneralizedPaneStrain 目录：广义平面应变算例

本目录聚焦于“广义平面应变（Generalized Plane Strain）”假设，对比：

- 普通平面应变：ε_zz = 0
- 广义平面应变：ε_zz = 一个随求解变化的 **标量自由度**（scalar_strain_zz）

这里的算例都基于陶瓷板两侧加热实验。

当前主要输入文件：

- 无外压的广义平面应变算例（Physics）：[GPlaneStrainCeramic_Physics.i](GPlaneStrainCeramic_Physics.i)
- 叠加面外压力的广义平面应变算例（Physics）：[GPlaneStrainPressure.i](GPlaneStrainPressure.i)

以及对应的 Exodus/CSV 结果：

- GPlaneStrainCeramic_Physics 结果：[GPlaneStrainCeramic_Physics_out.e](GPlaneStrainCeramic_Physics_out.e)
- GPlaneStrainPressure 结果：[GPlaneStrainPressure_out.e](GPlaneStrainPressure_out.e)、[GPlaneStrainPressure.csv](GPlaneStrainPressure.csv)
- 对比/中间数据：如 [PaneStrainCeramic_physics_post.csv](PaneStrainCeramic_physics_post.csv)、[GPlaneStrainCeramic_out.e](GPlaneStrainCeramic_out.e) 等

## 1. GPlaneStrainCeramic_Physics.i：无外压的广义平面应变

**目标**：在 2D 网格上使用广义平面应变假设，自动求解“厚度方向平均应变 ε_zz”，只考虑热膨胀和边界约束，不加额外面外压力。

关键特征：

- 网格与变量：
  - 2D 网格（x–y 平面）：`dim = 2, nx = 50, ny = 10`
  - 位移：`disp_x, disp_y`
  - 温度：`temp`，初始值 293.15K
  - 标量面外应变：`scalar_strain_zz`（SCALAR, FIRST）
- SolidMechanics Physics：

```text
[Physics]
  [SolidMechanics]
    [QuasiStatic]
      [all_mech]
        strain = SMALL
        planar_formulation = GENERALIZED_PLANE_STRAIN
        scalar_out_of_plane_strain = scalar_strain_zz
        add_variables = false
        eigenstrain_names = 'thermal_eigenstrain'
        use_automatic_differentiation = false
      []
    []
  []
[]
```

含义：

- 使用小应变理论（SMALL）；
- 平面公式设置为广义平面应变（GENERALIZED_PLANE_STRAIN）；
- 把标量面外应变自由度指定为 `scalar_strain_zz`；
- 热膨胀通过 `thermal_eigenstrain` 进入固体力学。

热与材料：

- 热传导：`ADHeatConduction` + `ADHeatConductionTimeDerivative`
- 弹性材料：`ComputeIsotropicElasticityTensor`
- 热膨胀本征应变：`ComputeThermalExpansionEigenstrain`
- 应力计算：`ComputeLinearElasticStress`

边界条件：

- 力学：在 `center_point` 上对 `disp_x/disp_y` 施加对称约束（值为 0）
- 热：左 `293.15K`，右 `1293.15K`

广义平面应变要点：

- 经典平面应变：强行 ε_zz = 0；
- 这里：ε_zz = `scalar_strain_zz`，是一个 **未知标量**，由广义平面应变方程自动求得；
- 运行后可以在终端输出中看到 `scalar_strain_zz` 随时间变化的表格。

## 2. GPlaneStrainPressure.i：带面外压力的广义平面应变

**目标**：在广义平面应变的基础上，引入一个“厚度方向的面外压力”，模拟在 z 方向施加外载的情况。

与 GPlaneStrainCeramic_Physics.i 的共同点：

- 仍然是 2D 网格 + `disp_x, disp_y, temp, scalar_strain_zz`；
- 仍然使用：

```text
strain = SMALL
planar_formulation = GENERALIZED_PLANE_STRAIN
scalar_out_of_plane_strain = scalar_strain_zz
eigenstrain_names = 'thermal_eigenstrain'
```

因此 **平面应变假设本身完全一样**，都是广义平面应变。

关键差异在 SolidMechanics Physics 中多了两行：

```text
out_of_plane_pressure_function = traction_function
pressure_factor = 1e6
```

并在 `[Functions]` 中定义：

```text
[./traction_function]
  type = PiecewiseLinear
  x = '0  1'
  y = '1  1'
[../]
```

物理意义：

- 在 out-of-plane 标量平衡方程中，除了热膨胀导致的 σ_zz 外，再加入一个外部压力项；
- `traction_function` 给出时间变化（这里 0–1 秒恒为 1）；
- `pressure_factor = 1e6` 设定压力量级；
- 结果是：`scalar_strain_zz` 需要同时平衡“热膨胀”和“面外压力”。

总结区别：

- GPlaneStrainCeramic_Physics.i：**无外压**，ε_zz 完全由温差 + 边界约束决定；
- GPlaneStrainPressure.i：**有外压**，ε_zz 由“温差 + 外压 + 约束”共同决定，适合演示外载对厚度方向应变/应力的影响。

## 3. 使用建议

- 想理解“广义平面应变 vs 普通平面应变”：
  - 对比本目录的 GPlaneStrainCeramic_Physics 与 PaneStrain 目录中的 PlaneStrainCeramic/PlaneStrainCeramic_Physics；
  - 比较 `max_MaxPrincipal` 的时间演化。
- 想看“外压对广义平面应变的影响”：
  - 对比 GPlaneStrainCeramic_Physics 与 GPlaneStrainPressure 中的 `scalar_strain_zz` 和 `max_MaxPrincipal`。

