# MOOSE燃料棒断裂仿真工作流框架

## 项目简介

这个框架提供了一组用于MOOSE燃料棒断裂仿真的工具和模块，采用模块化设计，提高代码的可维护性和可扩展性。主要功能包括：

1. 网格生成和参数研究配置
2. 运行仿真
3. 分析结果
4. ParaView后处理

## 架构设计

整个框架采用分层架构，将功能分解为基础模块和工具模块：

### 核心模块 (`core/`)

* `path_manager.py` - 路径管理模块，处理所有与路径相关的操作
* `command_executor.py` - 命令执行模块，处理命令执行和输出捕获
* `param_handler.py` - 参数处理模块，处理参数矩阵和组合生成
* `file_manager.py` - 文件操作模块，处理模板文件和文件替换
* `env_manager.py` - 环境管理模块，管理conda环境和MOOSE环境

### 工具模块 (`utils/`)

* `output_utils.py` - 输出工具模块，处理配置信息的打印和格式化

### 主工作流脚本

* `workflow.py` - 整合所有功能的主工作流脚本

## 使用方法

可以通过执行主脚本运行完整工作流：

```bash
python /home/yp/projects/fuel_rods/scripts/run_fuel_fracture.py
```

或者指定特定步骤：

```bash
python /home/yp/projects/fuel_rods/scripts/run_fuel_fracture.py --steps mesh
```

### 支持的步骤

* `mesh` - 生成网格和配置参数研究
* `run` - 运行仿真
* `analyze` - 分析结果
* `visualize` - ParaView后处理
* `all` - 执行所有步骤（默认）

### 主要参数

* `--base-dir` - 项目基础目录
* `--output-dir` - 输出目录
* `--template-main` - 主模板文件
* `--template-sub` - 子模板文件
* `--parameter-matrix` - 参数矩阵（JSON格式）
* `--exclude-combinations` - 排除的参数组合（JSON格式）
* `--moose-app` - MOOSE应用程序路径
* `--mpi-processes` - MPI进程数
* `--timeout` - 超时时间（秒）
* `--conda-env` - MOOSE环境名称
* `--paraview-env` - ParaView环境名称
* `--target-times` - 可视化目标时间点

## 代码重构优势

1. **模块化设计**：功能被拆分为独立的模块，每个模块有明确的职责
2. **代码复用**：通用功能被抽象为可重用的函数
3. **可扩展性**：易于添加新功能或修改现有功能
4. **可维护性**：结构清晰，便于理解和维护
5. **统一接口**：提供一致的接口，简化使用

## 目录结构

```
MooseScripts/
├── core/                   # 核心功能模块
│   ├── __init__.py
│   ├── path_manager.py     # 路径管理
│   ├── command_executor.py # 命令执行
│   ├── param_handler.py    # 参数处理
│   ├── file_manager.py     # 文件操作
│   └── env_manager.py      # 环境管理
├── utils/                  # 实用工具
│   ├── __init__.py
│   └── output_utils.py     # 输出工具
├── __init__.py
├── workflow.py             # 主工作流脚本
└── README.md               # 文档
``` 