# MooseScripts/config/__init__.py

"""
配置模块
-------
管理MooseScripts的配置项
"""

# 导入所有配置项
from .default_config import *
from .user_config import load_user_config

# 导出接口
__all__ = [
    'MOOSE_APP_PATH',
    'CONDA_ENV',
    'PARAVIEW_ENV',
    'MPI_PROCESSES',
    'CHECKPOINT_INTERVAL',
    'CHECKPOINT_FILES',
    'CHECKPOINT_TIME',
    'DEFAULT_PARAMETER_MATRIX',
    'DEFAULT_EXCLUDE_COMBINATIONS',
    'TARGET_TIMES',
    'SCRIPT_ROOT',
    'load_user_config'
]