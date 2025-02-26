# MooseScripts/config/user_config.py

"""
用户配置
-------
加载并管理用户自定义配置
"""

import os
import json
from .default_config import *

def load_user_config():
    """
    加载用户配置文件
    
    Returns:
        dict: 用户配置项
    """
    # 用户配置文件路径
    config_path = os.path.expanduser("~/.moosescripts.json")
    
    # 初始化为空字典
    user_config = {}
    
    # 尝试加载用户配置
    if os.path.exists(config_path):
        try:
            with open(config_path, 'r') as f:
                user_config = json.load(f)
            print(f"已加载用户配置: {config_path}")
        except Exception as e:
            print(f"警告: 无法加载用户配置: {e}")
    
    return user_config

# 加载用户配置并覆盖默认值
_user_config = load_user_config()

# 将用户配置应用到当前模块
for key, value in _user_config.items():
    if key.isupper():  # 仅更新全大写的配置项
        globals()[key] = value