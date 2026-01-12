# PaneStrain 目录：平面应变算例（传统写法 vs. Physics 写法）

本目录用于演示 **平面应变（Plane Strain）** 下的陶瓷板热冲击问题，包括：

- 传统块级写法（显式 Kernels / Materials）
- Physics 写法（SolidMechanics/QuasiStatic 自动生成力学部分）

主要输入文件：

- 传统平面应变算例：[PlaneStrainCeramic.i](PlaneStrainCeramic.i)
- Physics 平面应变算例：[PlaneStrainCeramic_Physics.i](PlaneStrainCeramic_Physics.i)

对应输出：

- 传统写法输出：`PlaneStrainCeramic_out.e`、`PaneStrainCeramic_post.csv`
- Physics 写法输出：`PlaneStrainCeramic_Physics_out.e`、`PaneStrainCeramic_physics_post.csv`

## 1. PlaneStrainCeramic.i：传统块级平面应变写法

**目标**：在 2D 平面应变假设下，显式写出力学/热传导的 Kernels 与 Materials，便于理解每个模块的作用。

关键特征：

- 网格与变量：
  - 2D 网格：`dim = 2, nx = 50, ny = 10`
  - 位移：`disp_x, disp_y`
  - 温度：`temp`，初始 293.15K
- 力学 Kernels：

```text
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
  ...
[]
```

- 热 Kernels：
  - `ADHeatConduction` + `ADHeatConductionTimeDerivative`
- 材料：
  - 热物性：`ADGenericConstantMaterial`
  - 弹性张量：`ADComputeIsotropicElasticityTensor`
  - 热膨胀本征应变：`ADComputeThermalExpansionEigenstrain`
  - 平面小应变：`ADComputePlaneSmallStrain`
  - 线弹性应力：`ADComputeLinearElasticStress`
- 边界条件：
  - 力学：在 `center_point` 上约束 `disp_x/disp_y = 0`
  - 热：左 293.15K，右 1293.15K
- 后处理：
  - `avg_temp`（平均温度）
  - `max_MaxPrincipal`（最大主应力最大值）

平面应变含义：

- 通过 `ADComputePlaneSmallStrain` 的平面应变公式，将 ε_zz 约束为 0（经典 plane strain 假设）。

## 2. PlaneStrainCeramic_Physics.i：Physics 平面应变写法

**目标**：用 SolidMechanics Physics 自动生成平面应变所需的应力平衡、应变/应力材料等“样板代码”，只写少量参数。

关键特征：

- 仍然是 2D 网格 + `disp_x, disp_y, temp`；
- 线弹性与热膨胀通过 Materials 配置：
  - `ComputeIsotropicElasticityTensor`
  - `ComputeThermalExpansionEigenstrain`
  - `ComputeLinearElasticStress`
- 力学部分交给 Physics：

```text
[Physics]
  [SolidMechanics]
    [QuasiStatic]
      [all_mech]
        strain = SMALL
        add_variables = false
        eigenstrain_names = 'thermal_eigenstrain'
        planar_formulation = PLANE_STRAIN
      []
    []
  []
[]
```

说明：

- `strain = SMALL`：选择小应变理论；
- `planar_formulation = PLANE_STRAIN`：明确使用平面应变公式；
- `eigenstrain_names = 'thermal_eigenstrain'`：把热膨胀本征应变挂到力学模块中；
- `add_variables = false`：不自动添加位移变量，使用 GlobalParams 里提供的 `disp_x/disp_y`。

热传导部分：

- 采用标量热传导 Kernels：
  - `HeatConduction` + `HeatConductionTimeDerivative`

边界条件与后处理：

- 与传统版类似：同样的对称约束与左右温度加载；
- Postprocessors 中也包含 `avg_temp` 和 `max_MaxPrincipal`。

## 3. 两个输入文件的核心区别

可以简单理解为：

- **PlaneStrainCeramic.i（传统版）**
  - 手写所有力学/热核与材料块；
  - 更适合逐行学习每个 Kernel / Material 的具体作用；
  - 平面应变通过 `ADComputePlaneSmallStrain` 实现。

- **PlaneStrainCeramic_Physics.i（Physics 版）**
  - 用 `[Physics/SolidMechanics/QuasiStatic]` 一段来驱动生成应力平衡与应变/应力计算；
  - 平面应变通过 `planar_formulation = PLANE_STRAIN` 这个参数选择；
  - 更简洁、适合实际建模时快速搭结构。

如果你想对照学习：

- 先从 PlaneStrainCeramic.i 看清楚“完整写法”；
- 再看 PlaneStrainCeramic_Physics.i，理解 Physics 块如何把这些内容自动化掉。

