# MooseScripts/config/default_config.py

"""
默认配置
-------
MooseScripts的默认配置值
"""

import os

# MOOSE应用配置
MOOSE_APP_PATH = "/home/yp/projects/raccoon/raccoon-opt"
CONDA_ENV = "moose"
PARAVIEW_ENV = "paraview_post"

# 仿真配置
MPI_PROCESSES = 12
CHECKPOINT_INTERVAL = 5
CHECKPOINT_FILES = 4
CHECKPOINT_TIME = 600

# 参数研究默认值
DEFAULT_PARAMETER_MATRIX = {
    "Gf": [8, 10],
    "length_scale_paramete": [5e-5, 10e-5],
    "power_factor_mod": [1, 2, 3]
}

# 排除组合
DEFAULT_EXCLUDE_COMBINATIONS = [
    ["Gf", 8, "length_scale_paramete", 10e-5, "power_factor_mod", 3],
    ["Gf", 10, "length_scale_paramete", 5e-5]
]

# 可视化设置
TARGET_TIMES = [4.0, 5.0, 6.0]

# 路径配置
SCRIPT_ROOT = "/home/yp/projects/fuel_rods/scripts"