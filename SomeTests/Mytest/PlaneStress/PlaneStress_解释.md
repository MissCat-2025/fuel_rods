# PlaneStress 目录：平面应力算例（Physics 写法 vs. 展开写法）

本目录聚焦 **平面应力（Plane Stress）** 下的陶瓷板热冲击问题，核心是：

- 用 SolidMechanics Physics 写一个精简的平面应力输入文件；
- 再给出一个“展开版”输入文件，把 Physics 自动生成的内容全部手写出来，便于学习。

主要输入文件：

- Physics 写法：[PlaneStressCeramic_physics.i](PlaneStressCeramic_physics.i)
- 展开写法（从 Physics 展开）：[PlaneStressCeramic.i](PlaneStressCeramic.i)

对应输出：

- Physics 写法结果：`PlaneStressCeramic_physics_out.e`、`PlaneStressCeramic_physics_post.csv`
- 展开写法结果：`PlaneStressCeramic_out.e`、`PlaneStressCeramic_post.csv`
- 针对 Physics 写法的详细说明文档：[PlaneStress_Physics_解释.md](PlaneStress_Physics_解释.md)

## 1. PlaneStressCeramic_physics.i：Physics 平面应力写法

**目标**：用少量参数描述“平面应力 + 热膨胀 + 小应变”，其余由 SolidMechanics/QuasiStatic Physics 自动生成。

典型的 Physics 块（详细解释见 PlaneStress_Physics_解释.md）：

```text
[Physics]
  [SolidMechanics]
    [QuasiStatic]
      [plane_stress]
        planar_formulation = WEAK_PLANE_STRESS
        strain = SMALL
        generate_output = 'stress_xx stress_xy stress_yy stress_zz strain_xx strain_xy strain_yy'
        eigenstrain_names = eigenstrain
      []
    []
  []
[]
```

要点：

- `planar_formulation = WEAK_PLANE_STRESS`
  - 选择弱式平面应力（Weak Plane Stress）公式；
  - 利用面外应变自由度（例如 `strain_zz`）弱方式 enforce `σ_zz = 0`。
- `strain = SMALL`
  - 使用小应变理论，对应 `ADComputePlaneSmallStrain`。
- `eigenstrain_names = eigenstrain`
  - 要求在 Materials 中提供同名本征应变张量属性（例如热膨胀本征应变）。
- `generate_output = 'stress_xx ... strain_yy'`
  - 自动创建对应的 AuxVariables 和 `ADRankTwoAux`，从应力/应变张量中抽取分量输出。

这个文件对使用 Physics 建模的“入口感”更好，适合日常建模。

## 2. PlaneStressCeramic.i：从 Physics 展开的传统写法

**目标**：把 PlaneStressCeramic_physics.i 中 Physics 块自动做的事情，全部展开成显式的块，方便逐行理解。

与 Physics 版相比：

- 网格、材料参数、边界条件、时间步控制基本一致；
- 差别在于：
  - 手写 `ADStressDivergenceTensors`、`ADWeakPlaneStress` 等 Kernels；
  - 手写 `ADComputePlaneSmallStrain`、`ADComputeLinearElasticStress` 等 Materials；
  - 手写所有 `AuxVariables` 与 `ADRankTwoAux`，对应 `generate_output` 的自动输出。

例如：

- `planar_formulation = WEAK_PLANE_STRESS`  
  展开为：
  - 一个面外应变变量（如 `strain_zz`），通过 `out_of_plane_strain` 参数挂到 GlobalParams；
  - 一个 `ADWeakPlaneStress` 类型的 Kernel，对应面外应变自由度；
- `generate_output = 'stress_xx ...'`  
  展开为：
  - 对应的 AuxVariables：`stress_xx, stress_yy, ...`  
  - 对应的 AuxKernels：`ADRankTwoAux`，从应力/应变张量中抽取分量写入这些 AuxVariables。

如果你结合 PlaneStress_Physics_解释.md 中的对照表阅读，会发现：

- Physics 写法中的每一行，在展开版中都能找到对应的小块；
- 通过对照这两个输入文件，你可以掌握：
  - 平面应力条件是如何在 MOOSE 中实现的；
  - 本征应变、输出分量是如何挂接到力学模块上的。

## 3. 这两个文件的使用场景

- 想快速搭建平面应力模型：  
  - 直接用 PlaneStressCeramic_physics.i。
- 想深入理解各个 Kernel / Material 的作用：  
  - 对照阅读 PlaneStressCeramic_physics.i 与 PlaneStressCeramic.i；
  - 再结合 PlaneStress_Physics_解释.md 中的逐行解释。

