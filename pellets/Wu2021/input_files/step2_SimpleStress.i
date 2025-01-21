# 各种参数都取自[1]Multiphysics phase-field modeling of quasi-static cracking in urania ceramic nuclear fuel
#几何与网格参数
pellet_outer_radius = 4.1e-3#直径变半径，并且单位变mm
clad_inner_radius = 4.18e-3#直径变半径，并且单位变mm
clad_outer_radius = 4.78e-3#直径变半径，并且单位变mm
length = 11e-3 # 芯块长度17.78mm
n_elems_axial = 2 # 轴向网格数
n_elems_azimuthal = 100 # 周向网格数
n_elems_radial_clad = 4 # 包壳径向网格数
n_elems_radial_pellet = 20 # 芯块径向网格数
#材料参数

pellet_elastic_constants=2.2e11#Pa
pellet_nu = 0.345
#下一节的材料属性，提前先写上
# pellet_density=10431.0#10431.0*0.85#kg⋅m-3
# pellet_specific_heat=300
# pellet_thermal_conductivity = 5


clad_elastic_constants=7.52e10#Pa
clad_nu = 0.33
#下一节的材料属性，提前先写上
# clad_density=6.59e3#kg⋅m-3
# clad_specific_heat=264.5
# clad_thermal_conductivity = 16
# clad_thermal_expansion_coef=5.0e-6#K-1



[Mesh]
    [pellet_clad_gap]
      type = ConcentricCircleMeshGenerator
      num_sectors = '${n_elems_azimuthal}'  # 周向网格数
      radii = '${pellet_outer_radius} ${clad_inner_radius} ${clad_outer_radius}'
      rings = '${n_elems_radial_pellet} 1 ${n_elems_radial_clad}'
      has_outer_square = false
      preserve_volumes = true
      portion = top_right # 生成四分之一计算域
      smoothing_max_it=10 # 平滑迭代次数
    []
    [rename_pellet_outer_bdy]
      type = SideSetsBetweenSubdomainsGenerator
      input = pellet_clad_gap
      primary_block = 1
      paired_block = 2
      new_boundary = 'pellet_outer' #将block1与block2之间的边界命名为pellet_outer
    []
    [rename_clad_inner_bdy]
      type = SideSetsBetweenSubdomainsGenerator
      input = rename_pellet_outer_bdy
      primary_block = 3
      paired_block = 2
      new_boundary = 'clad_inner' #将block3与block2之间的边界命名为clad_inner
    []

    [2d_mesh]
      type = BlockDeletionGenerator
      input = rename_clad_inner_bdy
      block = 2 # 删除block2
    []
    [rename]
      type = RenameBoundaryGenerator
      input = 2d_mesh
      old_boundary = 'bottom left outer'
      new_boundary = 'yplane xplane clad_outer' # 将边界命名为yplane xplane clad_outer

    []
  [extrude]
    type = MeshExtruderGenerator
    input = rename
    extrusion_vector = '0 0 ${length}' # 轴向长度
    num_layers = '${n_elems_axial}' # 轴向网格数
    bottom_sideset = 'bottom' # 命名为底面
    top_sideset = 'top' # 命名为顶面
  []
  [rename2]
    type = RenameBlockGenerator
    input = extrude
    old_block  = '1 3'
    new_block  = 'pellet clad' # 将block1和block3分别命名为pellet和clad
  []
[]
#以上是生成几何与网格
# 以下是定义变量、控制方程、边界条件、材料属性的详细内容与解释
# 咱们得控制方程就一个：∇·σ + f = 0  (在域Ω内)，# 边界条件：σ·n = t  (在域Ω的边界Γ上)
# 应力与应变的关系离散化后σ = Dε  (在域Ω内)，加上应变与位移的关系离散化后ε = Bu,D是弹性矩阵.u为位移
# 所以控制方程的离散格式最终可以化为：KU - F=0(K为刚度矩阵K=B^T*D*B，U为位移向量，F为载荷向量)，
# 以上是原理部分，记住(B^T*D*B)U - F=0就好（具体推导我放在了代码最后面）


#》》》》》》》》》》》》》》》》》》》》》》》》》》》》》》》》》》
#》》》》》》》》》》》》》》》》》》》》》》》》》》》》》》》》》》》
# 以下是MOOSE代码与原理的对应关系（不分顺序）

#有限元模拟本质就是求微分方程(控制方程)
# MOOSE将控制方程区分为变量[Variables](即U)，材料属性[Materials](即D、B)，以及变量与材料属性的组合方式[Kernels]
# 定义控制方程[Kernels]：
  # MOOSE中是将[Kernels]一项一项((B^T*D*B)U即为一项，-F为另一项)写开，
  # Kernels不同项使用不同函数的根本原因，是》》》变量与材料参数的组合方式不同《《《
  # 本文的问题中，无体力，所以F=0，所以[Kernels]只有一项，即(B^T*D*B)U，具体在[Kernels/solid_x]中，
# 定义变量与初始条件[Variables]：我们求解的变量，即位移向量U，本文研究三维问题，所以U是三维的，即U = [u_x, u_y, u_z]，对应[disp_x, disp_y, disp_z]
# 定义材料属性[Materials]：材料属性，即控制方程中的D、B(严格来说B不能完全叫做材料属性，但目前可以这么理解)
  # 一般来讲[Materials]中都是已知变量，如根据杨氏模量、泊松比算出D
# 3.定义边界条件[BCs]：边界条件，这里使用Pressure边界条件与位移Dirichlet边界条件
# 5.定义求解器[Executioner]：求解器，即求解KU - F=0，分为线性求解器与非线性求解器，具体解释在本代码最后


[GlobalParams]
    displacements = 'disp_x disp_y disp_z' #全局变量，简化输入文件，如果没有这个，那么有许多地方就需要单独写上这个
[]


[Variables]
  #定义变量
    [disp_x]
      family = LAGRANGE #意思是使用拉格朗日插值法，常数插值法MONOMIAL，当明显我们的变量是连续的，所以使用拉格朗日插值法
      order = FIRST #order=1，表示使用一阶插值法，由于我们的网格是HEX8（8节点六面体），所以使用一阶插值法
                    # order=2，表示使用二阶插值法，对应网格也需要是HEX20（20节点六面体）  
    []
    [disp_y]
    []
    [disp_z]
    []
[]
[Kernels]
  # 定义应力平衡方程
  # 应力平衡方程：σ_ij,j + f_i = 0
  # 其中，σ_ij是应力张量，f_i是体力（如重力），j是空间坐标。
  # 在有限元中，应力平衡方程通过将应力张量与位移梯度（即应变）联系起来，并考虑边界条件和载荷来求解。
  # 应力平衡方程在每个节点上建立，形成一个线性方程组，通过求解这个方程组可以得到节点的位移。
  # 应力平衡方程是结构分析中的基本方程，用于描述材料在受力作用下的变形和应力分布。
    [solid_x]
        type = ADStressDivergenceTensors
        variable = disp_x #variable=disp_x，表示x方向的位移
        component = 0 #component=0，表示x方向的应力平衡方程
    []
    [solid_y]
        type = ADStressDivergenceTensors
        variable = disp_y #variable=disp_y，表示y方向的位移
        component = 1 #component=1，表示y方向的应力平衡方程
    []
    [solid_z]
        type = ADStressDivergenceTensors
        variable = disp_z #variable=disp_z，表示z方向的位移
        component = 2 #component=2，表示z方向的应力平衡方程
    []
[]

[BCs]
  # 定义边界条件
  [y_zero_on_y_plane]
    #y平面上的y的位移为0
    type = DirichletBC
    variable = disp_y
    boundary = 'yplane'
    value = 0
  []
  [x_zero_on_x_plane]
    #x平面上的x的位移为0
    type = DirichletBC
    variable = disp_x
    boundary = 'xplane'
    value = 0
  []
  [z_zero_on_bottom]
    #底面上的z的位移为0
    type = DirichletBC
    variable = disp_z
    boundary = 'bottom'
    value = 0
  []
  [PressureOnBoundaryX]
    #芯块包壳间隙压力
    type = Pressure
    variable = disp_x
    boundary = 'pellet_outer'
    factor = 1e6 #压力大小
    use_displaced_mesh = true #是否使用变形网格
  []
  [PressureOnBoundaryY]
    #芯块包壳间隙压力
    type = Pressure
    variable = disp_y
    boundary = 'pellet_outer'
    factor = 1e6 #压力大小
    use_displaced_mesh = true #是否使用变形网格
  []
  [PressureOnBoundaryX2]
    #芯块包壳间隙压力
    type = Pressure
    variable = disp_x
    boundary = 'clad_inner'
    factor = 1e6 #压力大小
    use_displaced_mesh = true #是否使用变形网格
  []
  [PressureOnBoundaryY2]
    #芯块包壳间隙压力
    type = Pressure
    variable = disp_y
    boundary = 'clad_inner'
    factor = 1e6 #压力大小
    use_displaced_mesh = true #是否使用变形网格
  []
[]
#
[Materials]
  # 定义材料属性，注意没有先后顺序
  # 其实控制方程Kernel、边界条件BCs、材料属性Materials他们都是完全耦合的，

  # 把芯快包壳的材料属性定义在[Materials]中，
  # 定义弹性矩阵，弹性矩阵是材料属性的一部分，由于它需要输入杨氏模量与泊松比，而芯快包壳的不太一样，所以需要单独定义
    [pellet_elasticity_tensor]
        type = ADComputeIsotropicElasticityTensor #计算弹性矩阵
        youngs_modulus = ${pellet_elastic_constants} #杨氏模量
        poissons_ratio = ${pellet_nu} #泊松比
        block = pellet #block=pellet，表示在pellet这个block中使用这个材料属性
    []
    [clad_elasticity_tensor]
      type = ADComputeIsotropicElasticityTensor
      youngs_modulus = ${clad_elastic_constants}
      poissons_ratio = ${clad_nu}
      block = clad
    []
    #你会发现芯快包壳除了弹性矩阵不一样，其他都一样，所以可以定义一个通用的材料属性
    [strain]
        type = ADComputeSmallStrain #计算小应变
    []
    [stress]
        type = ADComputeLinearElasticStress
    []
[]

#求解器，solve_type与petsc_options_iname、petsc_options_value的设置决定了什么时候下班
  [Executioner]
      type = Steady #求解器，Steady是稳态求解器(没有时间步)，Transient是瞬态求解器(有时间步)
      solve_type = 'PJFNK' #求解器，PJFNK是预处理雅可比自由牛顿-克雷洛夫方法
      petsc_options_iname = '-pc_type'
      petsc_options_value = 'lu'       # LU分解，小问题效果好
  []
#PETSc求解器的参数设置，如下这个我不同清楚到底应该选哪个，可以分别都试一下
  #1.不完全LU分解（巨快）
    # petsc_options_iname = '-pc_type'
    # petsc_options_value = 'ilu'      # 不完全LU分解
  #2.直接求解器（巨快，和1差不多）
    # petsc_options_iname = '-pc_type'
    # petsc_options_value = 'lu'       # LU分解，小问题效果好
  #3.加速收敛，（最慢）中等规模
    # petsc_options_iname = '-pc_type -sub_pc_type -sub_pc_factor_shift_type'
    # petsc_options_value = 'asm lu NONZERO'  # 加速收敛
  #4.多重网格（比2慢，比3快）大规模
    # petsc_options_iname = '-pc_type -pc_hypre_type'
    # petsc_options_value = 'hypre boomeramg'  # 代数多重网格，大问题效果好
  #5.GMRES重启参数（比1,、2慢，比4快）大规模问题
    # petsc_options_iname = '-ksp_gmres_restart  -pc_type  -pc_hypre_type  -pc_hypre_boomeramg_max_iter'
    # petsc_options_value = '201                  hypre     boomeramg       4'
      # 参数解释：
        # 1. -ksp_gmres_restart = 201    
        # # GMRES重启参数
        # # 当达到201次迭代后重新开始
        # # 避免存储太多Krylov子空间向量

        # 2. -pc_type = hypre           
        # # 使用HYPRE预处理器
        # # 适合大规模并行计算

        # 3. -pc_hypre_type = boomeramg 
        # # 使用代数多重网格方法
        # # 对非线性问题效果好

        # 4. -pc_hypre_boomeramg_max_iter = 8
        # # BoomerAMG最大迭代次数
        # # 控制预处理的计算量




# 以下是后处理部分，用于导出应力数据
# 》》》》》》》》》》》
# 》》》》》》》》》》》
# 我们想看看压力边界条件在芯块包壳间隙中运用的对不对，主要是压力的大小与方向对不对
# 本文研究的是几何为圆柱体与圆环，因此我们导出应力的形式为：
# 径向应力σrr，周向应力σθθ，轴向应力σzz
#想要导出应力，需要定义[AuxVariables]与[AuxKernels]
[AuxVariables]
  [hoop_stress]
    order = CONSTANT
    family = MONOMIAL
  []
  [radial_stress]    # 径向应力，用于检查压力在径向的传递
    order = CONSTANT
    family = MONOMIAL
  []
  [axial_stress]
    order = CONSTANT
    family = MONOMIAL
  []
[]

[AuxKernels]
  [hoop_stressP]
    type = ADRankTwoScalarAux
    variable = hoop_stress
    rank_two_tensor = stress #这里的stress与材料属性中的ADComputeLinearElasticStress有关，它帮我们计算出来了stress
    scalar_type = HoopStress #关于其他应力的导出形式，请参考：https://mooseframework.inl.gov/source/utils/RankTwoScalarTools.html
    #point2-point1的向量就是轴的方向（x,y,z）。正负不影响结果，大小也不影响结果
    point1 = '0 0 0'
    point2 = '0 0 1'
    execute_on = 'TIMESTEP_END' #表示在每个时间步结束时执行，
    # execute_on还有INITIAL、LINEAR、NONLINEAR、TIMESTEP_BEGIN、FINAL等形式
  []
  [radial_stress]
    type = ADRankTwoScalarAux
    variable = radial_stress
    rank_two_tensor = stress
    scalar_type = RadialStress
    point1 = '0 0 0'
    point2 = '0 0 -1'
    execute_on = 'TIMESTEP_END'
  []
  [axial_stress]
    type = ADRankTwoScalarAux
    variable = axial_stress
    rank_two_tensor = stress
    scalar_type = AxialStress
    point1 = '0 0 0'
    point2 = '0 0 1'
    execute_on = 'TIMESTEP_END'
  []
[]


[Outputs]
  exodus = true #表示输出exodus格式文件
[]


















# 》》》》》》》》》》》》有限元相关的原理
# 1. 连续形式：
#    ∇·σ + f = 0  (在域Ω内)
#    σ·n = t       (在边界Γ上)

# 2. 本构关系和几何关系：
#    σ = Dε        (本构关系，D是弹性矩阵)
#    ε = Bu        (应变-位移关系，B是应变-位移矩阵)

# 3. 变分形式：
#    ∫Ω δεᵀσ dΩ = ∫Ω δuᵀf dΩ + ∫Γ δuᵀt dΓ

# 4. 离散化：
#    u ≈ uh = ∑(j=1 to n) uj·Nj(x) = NU        (位移插值，N是形函数矩阵)
#    δu ≈ δuh = ∑(i=1 to n) δui·Ni(x) = NδU
#    ε = Bu        (B是应变-位移矩阵)
#    δε = BδU

# 5. 代入变分形式：
#    ∫Ω (BδU)ᵀDBU dΩ = ∫Ω (NδU)ᵀf dΩ + ∫Γ (NδU)ᵀt dΓ

# 6. 由于δU是任意的，得到：
#    (∫Ω BᵀDB dΩ)U = ∫Ω Nᵀf dΩ + ∫Γ Nᵀt dΓ

# 7. 最终形式：
#    KU = F
#    其中：
#    K = ∫Ω BᵀDB dΩ    (刚度矩阵)
#    F = ∫Ω Nᵀf dΩ + ∫Γ Nᵀt dΓ    (载荷向量)

# 8. 线性问题 (材料性质和几何都是线性的):
#    KU = F  
#    其中 K 和 F 都是常数（不依赖于 U）
   
#    直接求解：
#    - 使用 Krylov 子空间方法（如 GMRES）
#    - 求解 KU = F
#    - 一次求解即可得到结果

# 9. 非线性问题 (考虑材料非线性或几何非线性):
#    R(U) = K(U)U - F(U) = 0
#    其中：
#    - K(U) = ∫Ω BᵀD(U)B dΩ    (K 依赖于 U)
#    - F(U) 也可能依赖于 U
   
      #    Newton迭代求解：
            #    a) 展开 R(U) 在 Uᵏ 处的 Taylor 级数：
            #       R(Uᵏ) + J(Uᵏ)(Uᵏ⁺¹-Uᵏ) = 0
                  
            #    b) 雅可比矩阵：
            #       J(U) = ∂R/∂U = K(U) + ∂K(U)/∂U·U - ∂F(U)/∂U
              
            #    c) 每个 Newton 步求解线性系统：
            #       J(Uᵏ)δUᵏ = -R(Uᵏ)
                  
            #    d) 更新解：
      #       Uᵏ⁺¹ = Uᵏ + δUᵏ
      #    PJFNK  (Preconditioned Jacobian-Free Newton-Krylov) 求解过程：
            # 【非线性部分 - 外循环】 
            # 1. Newton迭代（外循环）要求解：
            #    J(Uᵏ)δUᵏ = -R(Uᵏ)
            # 【线性部分 - 内循环】
            # 2. 使用 GMRES 方法求解这个线性系统：
              
            #    a) 初始残差：
            #       r₀ = -R(Uᵏ) - J(Uᵏ)δUᵏ₀
            #       其中 δUᵏ₀ 是初始猜测
              
            #    b) 构建 Krylov 子空间：
            #       Km = span{r₀, Jr₀, J²r₀, ..., Jᵐ⁻¹r₀}
                  
            #       关键点：需要计算 Jv（其中v是子空间基向量）
            #       这时使用方向导数近似：
            #       Jv ≈ [R(U + εv) - R(U)]/ε

            # 3. 加入预处理改善收敛性（线性变换）：
              
            #    原系统：J(Uᵏ)δUᵏ = -R(Uᵏ)
            #    预处理后：M⁻¹J(Uᵏ)δUᵏ = -M⁻¹R(Uᵏ)

            #    具体算法步骤：
            #    ```
            #    GMRES with Preconditioning:
              
            #    1) 计算初始残差：
            #       r₀ = -M⁻¹R(Uᵏ) - M⁻¹J(Uᵏ)δUᵏ₀
            #       v₁ = r₀/||r₀||
              
            #    2) 对 j = 1,2,...,m：
            #       # 计算 M⁻¹Jvⱼ
            #       w = M⁻¹[R(U + εvⱼ) - R(U)]/ε
                  
            #       # Gram-Schmidt 正交化
            #       对 i = 1,...,j：
            #         hᵢⱼ = (w,vᵢ)
            #         w = w - hᵢⱼvᵢ
                  
            #       hⱼ₊₁,ⱼ = ||w||
            #       vⱼ₊₁ = w/hⱼ₊₁,ⱼ
              
            #    3) 求解最小二乘问题：
            #       min ||βe₁ - H̄ᵐy||
              
            #    4) 计算解：
            #       δUᵏ = V̄ᵐy