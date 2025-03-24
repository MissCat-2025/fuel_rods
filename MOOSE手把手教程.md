# 第二章 MOOSE手把手教程

## 前言

这一小节的目的是看看实现moose的基础条件是否满足。

在进行这一章之前

如果你还无法回答接下来的问题，请先学习相关理论，再来运行你的模型

1，你要解的**偏微分方程**是？它对应的弱形式？有几个变量？

例如，我想实现的偏微分方程是上面的热力耦合问题，那必然有如下最少两个偏微分方程，变量分别是热传导对应的温度T，力平衡方程对应的位移u
热传导方程：

$$
\rho_0 c \frac{\partial T_p}{\partial t} = \nabla\cdot\left(k \nabla T_p \right) + \dot{Q}\left(\vec{x},t\right)
$$

力平衡方程

$$
\nabla\cdot\sigma+b=0
$$


由于MOOSE的控制方程对应的是弱形式，因此还需列出相应的弱形式，具体请看官网的推导[Step 4 Generate a Weak Form | MOOSE](https://mooseframework.inl.gov/getting_started/examples_and_tutorials/tutorial01_app_development/step04_weak_form.html)，

简单总结就是弱形式与强形式的区别是，正负号可能发生变化，具体是：

拉普拉斯算子（梯度的散度）需要变号， 

$$
例如【\nabla\cdot\left(k \nabla T_p \right)】会变成【-(\nabla\phi,k\nabla T_p)】，
$$

其余的不需要变号。

后将所有项其移到一边就是MOOSE需要的控制方程对应的是弱形式了。

如

$(\phi,\rho_0c\partial_tT_p)+(\nabla\phi,k\nabla T_p)-\dot{Q}\left(\vec{x},t\right)=0$

2，偏微分方程的**边界条件、初始条件**是？（查论文资料）

3，你要运行的模型的**几何与网格划分**是？（查论文资料）

4，偏微分方程中涉及的材料参数或模型的其他参数是？（如热导率、步长、运行总时间、固体力学中总应变中是否有本征应变、塑性应变、蠕变等）


以上任何不懂的地方，都可以通过与cursor中的claude3.7-sonnet-thinking,deepseek-r1等模型进行快速学习。

## 第一节 整体把握

如果你讲前言的有限元相关的知识学会了，接下来就能在MOOSE中实现各种模型了。

这一节的目的是对moose的整体有个把握，知道【调用MOOSE的模块（Makefile）】、【moose的输入文件】、【自定义的模型文件include与src】的关系

如果以前接触过其他有限元软件如abques、fluent、comsol等，其实MOOSE逻辑与它们都差不多，只是没有界面。

创建自己的app

商用有限元软件中，一开始需要在某个大模块内创建工作流workbench，例如在流体大模块创建你的workbench等，这样就能使用流体相关的各种模型与函数。MOOSE也是如此，我们一开始也是需创建自己的workbench，moose里面叫app，在app的Makefile中选择对应的各种大模块，如固体力学、反应堆等大模块，即可调用各种相关模型与函数。

具体操作是运行如下代码：
《cd ~/projects》


## 第二节 认识输入文件

汇总

[mesh]

## 第三节 模型文件include与src
