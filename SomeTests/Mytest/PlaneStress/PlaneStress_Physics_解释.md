# PlaneStress 的 Physics 写法：用法与展开版对照

本目录里有两份等价目标的输入文件：

- Physics 写法：[PlaneStressCeramic_physics.i](SomeTests/Mytest/PlaneStress/PlaneStressCeramic_physics.i)
- 展开写法（传统块、显式 Kernels/AuxKernels）：[PlaneStressCeramic_expanded_from_physics.i](SomeTests/Mytest/PlaneStress/PlaneStressCeramic_expanded_from_physics.i)

Physics 写法的核心价值是：用少量参数自动生成 TensorMechanics/固体力学所需的变量、Kernel、Material、输出等“样板代码”；展开写法的核心价值是：每一步都显式写出，便于精细改动与排查。

## 1. 你给的 Physics 块到底做了什么

Physics 块如下（原样保留）：

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

逐行对照（把 L15-26 每一行直接映射到传统写法的小块）：

| Physics 语句 | 传统写法对应的小块（展开版） |
|---|---|
| `[Physics]` | 这是“汇总入口”，展开后落到：[Kernels](SomeTests/Mytest/PlaneStress/PlaneStressCeramic_expanded_from_physics.i#L67-L87)、[Materials](SomeTests/Mytest/PlaneStress/PlaneStressCeramic_expanded_from_physics.i#L176-L205)、以及输出用的 [AuxVariables/AuxKernels](SomeTests/Mytest/PlaneStress/PlaneStressCeramic_expanded_from_physics.i#L36-L147) |
| `[SolidMechanics]` | 对应“固体力学整套链条”：力平衡 [Kernels:solid_x/solid_y](SomeTests/Mytest/PlaneStress/PlaneStressCeramic_expanded_from_physics.i#L67-L77) + 应变/应力 [Materials:strain/stress](SomeTests/Mytest/PlaneStress/PlaneStressCeramic_expanded_from_physics.i#L197-L205) |
| `[QuasiStatic]` | 对应“准静力平衡方程”（没有位移的时间导数 Kernel）：[Kernels:ADStressDivergenceTensors](SomeTests/Mytest/PlaneStress/PlaneStressCeramic_expanded_from_physics.i#L67-L77) |
| `[plane_stress]` | 对应“平面应力+面外应变自由度”：`out_of_plane_strain` 参数 [GlobalParams](SomeTests/Mytest/PlaneStress/PlaneStressCeramic_expanded_from_physics.i#L1-L4) + `strain_zz` 变量 [Variables](SomeTests/Mytest/PlaneStress/PlaneStressCeramic_expanded_from_physics.i#L24-L34) + 约束方程 [Kernels:solid_z](SomeTests/Mytest/PlaneStress/PlaneStressCeramic_expanded_from_physics.i#L78-L81) |
| `planar_formulation = WEAK_PLANE_STRESS` | 直接对应 `ADWeakPlaneStress`： [Kernels:solid_z](SomeTests/Mytest/PlaneStress/PlaneStressCeramic_expanded_from_physics.i#L78-L81)（并依赖 `out_of_plane_strain = strain_zz`：[GlobalParams](SomeTests/Mytest/PlaneStress/PlaneStressCeramic_expanded_from_physics.i#L1-L4)） |
| `strain = SMALL` | 直接对应小应变应变计算材料： [Materials:strain (ADComputePlaneSmallStrain)](SomeTests/Mytest/PlaneStress/PlaneStressCeramic_expanded_from_physics.i#L197-L200) |
| `generate_output = 'stress_xx ... strain_yy'` | 展开后就是“手动建输出场 + 从张量抽分量”： [AuxVariables](SomeTests/Mytest/PlaneStress/PlaneStressCeramic_expanded_from_physics.i#L36-L65) + [AuxKernels (ADRankTwoAux)](SomeTests/Mytest/PlaneStress/PlaneStressCeramic_expanded_from_physics.i#L89-L147) |
| `eigenstrain_names = eigenstrain` | 需要提供同名本征应变张量属性： [Materials:eigenstrain](SomeTests/Mytest/PlaneStress/PlaneStressCeramic_expanded_from_physics.i#L189-L195)，并在应变材料里挂上它： [Materials:strain eigenstrain_names](SomeTests/Mytest/PlaneStress/PlaneStressCeramic_expanded_from_physics.i#L197-L200) |

## 2. WEAK_PLANE_STRESS 为什么需要 strain_zz（面外应变变量）

弱式平面应力的思路是：在 2D 网格上，仍然保留一个“面外应变自由度”`ε_zz`，通过额外方程（弱式约束）求得它，使 `σ_zz = 0` 成立。

所以通常会有两件事：

- 定义一个变量存放 `ε_zz`（本目录用的是 `strain_zz`）
- 把它告诉力学模块（本目录通过 `GlobalParams` 的 `out_of_plane_strain = strain_zz`）

对应 Physics 文件位置：

- `out_of_plane_strain = strain_zz`：[PlaneStressCeramic_physics.i:L1-L4](SomeTests/Mytest/PlaneStress/PlaneStressCeramic_physics.i#L1-L4)
- `strain_zz` 变量定义：[PlaneStressCeramic_physics.i:L18-L26](SomeTests/Mytest/PlaneStress/PlaneStressCeramic_physics.i#L18-L26)

## 3. eigenstrain_names = eigenstrain 要如何配套写 Materials

Physics 块里写了：

```text
eigenstrain_names = eigenstrain
```

它的意思是：你需要在 `[Materials]` 里提供一个名为 `eigenstrain` 的“RankTwoTensor 类型材料属性”（本征应变张量）。

本目录给的是热膨胀本征应变：

- 材料块：[PlaneStressCeramic_physics.i:L79-L109](SomeTests/Mytest/PlaneStress/PlaneStressCeramic_physics.i#L79-L109)
- 关键行：`eigenstrain_name = eigenstrain`，确保名字对上 `eigenstrain_names`

## 4. generate_output 在展开写法里对应什么

Physics 写法里：

```text
generate_output = 'stress_xx stress_xy stress_yy stress_zz strain_xx strain_xy strain_yy'
```

如果不用 Physics 自动生成输出，那么常见的“展开写法”是：

1) 先建 AuxVariables：`stress_xx`、`strain_xx` 等  
2) 再用 `RankTwoAux`/`ADRankTwoAux` 从张量材料属性里取分量写入这些 AuxVariables

对应展开版文件里的实现区间：

- AuxVariables：[PlaneStressCeramic_expanded_from_physics.i:L36-L65](SomeTests/Mytest/PlaneStress/PlaneStressCeramic_expanded_from_physics.i#L36-L65)
- AuxKernels（应力/应变分量提取）：[PlaneStressCeramic_expanded_from_physics.i:L89-L147](SomeTests/Mytest/PlaneStress/PlaneStressCeramic_expanded_from_physics.i#L89-L147)

Physics 写法把这套“建变量 + 建提取器”的工作自动化了。

## 5. Physics 写法与展开写法的“对照表”

- `planar_formulation = WEAK_PLANE_STRESS`  
  - 展开：`ADWeakPlaneStress` Kernel + `out_of_plane_strain` 变量/参数组合  
  - 参考：[PlaneStressCeramic_expanded_from_physics.i:L67-L87](SomeTests/Mytest/PlaneStress/PlaneStressCeramic_expanded_from_physics.i#L67-L87)

- `strain = SMALL`  
  - 展开：`ADComputePlaneSmallStrain`（小应变）  
  - 参考：[PlaneStressCeramic_expanded_from_physics.i:L197-L205](SomeTests/Mytest/PlaneStress/PlaneStressCeramic_expanded_from_physics.i#L197-L205)

- `eigenstrain_names = eigenstrain`  
  - 展开：在应变计算材料里挂上 `eigenstrain_names`，并提供同名 `eigenstrain` 材料属性  
  - 参考：[PlaneStressCeramic_expanded_from_physics.i:L189-L200](SomeTests/Mytest/PlaneStress/PlaneStressCeramic_expanded_from_physics.i#L189-L200)

- `generate_output = ...`  
  - 展开：AuxVariables + `ADRankTwoAux` 抽取应力/应变分量  
  - 参考：[PlaneStressCeramic_expanded_from_physics.i:L36-L147](SomeTests/Mytest/PlaneStress/PlaneStressCeramic_expanded_from_physics.i#L36-L147)

## 6. 如何运行

Physics 版输入文件路径：

- [PlaneStressCeramic_physics.i](SomeTests/Mytest/PlaneStress/PlaneStressCeramic_physics.i)

如果你有已经编译好的 app 可执行文件（例如 `...-opt`），在该目录运行：

```bash
mpirun -n 4 /path/to/your-app-opt -i PlaneStressCeramic_physics.i
```

输出默认写到 exodus 文件（因为 `[Outputs] exodus = true`）。
