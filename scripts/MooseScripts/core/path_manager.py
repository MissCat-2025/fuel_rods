#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
路径管理模块
-----------
集中管理所有仿真工作流涉及的路径，确保路径一致性和正确性

主要功能：
1. 解析和验证各种路径
2. 提供一致的路径管理接口
3. 自动处理相对路径和绝对路径
4. 管理模板文件查找
"""

import os
import sys
import glob
import re
from pathlib import Path

# 定义默认路径常量
DEFAULT_MOOSE_APP_PATH = "/home/yp/projects/raccoon/raccoon-opt"
DEFAULT_BASE_DIR = "/home/yp/projects/fuel_rods/FuelFracture"
DEFAULT_SCRIPTS_PATH = "/home/yp/projects/fuel_rods/scripts/MooseScripts"
DEFAULT_OUTPUT_DIR = os.path.join(DEFAULT_BASE_DIR, "parameter_studies")

def get_script_directory():
    """获取当前执行脚本所在目录的绝对路径"""
    return os.path.dirname(os.path.abspath(sys.argv[0]))

def resolve_base_dir(base_dir=None):
    """
    解析基础目录路径
    
    Args:
        base_dir: 指定的基础目录，可以是None或相对路径
        
    Returns:
        str: 完整的绝对路径
    """
    if base_dir is None:
        # 使用默认基础目录
        return DEFAULT_BASE_DIR
    else:
        # 如果提供了相对路径，相对于脚本所在目录解析
        if not os.path.isabs(base_dir):
            return os.path.abspath(os.path.join(get_script_directory(), base_dir))
        else:
            return os.path.abspath(base_dir)

def resolve_output_dir(output_dir=None, base_dir=None):
    """
    解析输出目录路径
    
    Args:
        output_dir: 指定的输出目录，可以是None或相对路径
        base_dir: 基础目录，如果为None则使用默认值
        
    Returns:
        str: 完整的绝对路径
    """
    if base_dir is None:
        base_dir = resolve_base_dir()
        
    if output_dir is None:
        # 默认输出目录是基础目录下的parameter_studies
        return os.path.join(base_dir, "parameter_studies")
    else:
        # 如果提供了相对路径，相对于基础目录解析
        if not os.path.isabs(output_dir):
            return os.path.join(base_dir, output_dir)
        else:
            return output_dir

def ensure_path_exists(path):
    """
    确保目录存在，如果不存在则创建
    
    Args:
        path: 需要确保存在的目录路径
        
    Returns:
        str: 确认存在的目录路径
    """
    if path and not os.path.exists(path):
        os.makedirs(path, exist_ok=True)
    return path

def find_template_files(directory):
    """
    在指定目录中查找所有可能的模板文件组合
    
    Args:
        directory: 要搜索的目录
        
    Returns:
        list: 格式为 [(main_template, sub_template, description), ...] 的列表
    """
    # 查找所有.i文件
    i_files = glob.glob(os.path.join(directory, '*.i'))
    
    if not i_files:
        return []
    
    # 查找包含"_Sub"的文件作为子模板
    sub_templates = [f for f in i_files if '_Sub' in os.path.basename(f)]
    main_templates = [f for f in i_files if '_Sub' not in os.path.basename(f)]
    
    # 生成所有可能的组合
    result = []
    
    # 多程序模式：主模板 + 子模板
    for main in main_templates:
        for sub in sub_templates:
            main_name = os.path.basename(main)
            sub_name = os.path.basename(sub)
            # 检查是否这对文件名（除了_Sub后缀）是匹配的
            main_base = os.path.splitext(main_name)[0]
            sub_base = os.path.splitext(sub_name)[0].replace('_Sub', '')
            
            if main_base == sub_base:
                result.append((main, sub, f"多程序模式: {main_name} + {sub_name}"))
    
    # 单程序模式：只有主模板
    for main in main_templates:
        main_name = os.path.basename(main)
        result.append((main, main, f"单程序模式: {main_name}"))
    
    return result

def find_files_by_pattern(directory, pattern):
    """
    在目录中查找匹配指定模式的文件
    
    Args:
        directory: 要搜索的目录
        pattern: 文件名模式（可以是正则表达式或glob模式）
        
    Returns:
        list: 匹配文件的完整路径列表
    """
    result = []
    
    # 支持glob模式
    if '*' in pattern or '?' in pattern:
        result = glob.glob(os.path.join(directory, pattern))
    else:
        # 支持正则表达式模式
        regex = re.compile(pattern)
        for root, _, files in os.walk(directory):
            for file in files:
                if regex.search(file):
                    result.append(os.path.join(root, file))
    
    return result

def get_moose_app_path(custom_path=None):
    """
    获取MOOSE应用程序路径
    
    Args:
        custom_path: 自定义的MOOSE路径
        
    Returns:
        str: MOOSE可执行文件的完整路径
    """
    return custom_path or DEFAULT_MOOSE_APP_PATH

def get_scripts_path():
    """
    获取脚本基础路径
    
    Returns:
        str: 脚本目录的绝对路径
    """
    return DEFAULT_SCRIPTS_PATH

def create_path_config(args=None):
    """
    创建完整的路径配置字典
    
    Args:
        args: 命令行参数对象，包含base_dir、output_dir等字段
        
    Returns:
        dict: 包含所有路径信息的字典
    """
    # 创建空参数对象，以防args为None
    class EmptyArgs:
        pass
    
    if args is None:
        args = EmptyArgs()
        args.base_dir = None
        args.output_dir = None
        args.template_main = None
        args.template_sub = None
        args.moose_app = None
    
    # 获取脚本目录
    script_dir = get_script_directory()
    
    # 解析基础目录
    base_dir = resolve_base_dir(getattr(args, 'base_dir', None))
    
    # 解析输出目录
    output_dir = resolve_output_dir(getattr(args, 'output_dir', None), base_dir)
    
    # 确保输出目录存在
    ensure_path_exists(output_dir)
    
    # 创建配置字典
    path_config = {
        "script_dir": script_dir,
        "base_dir": base_dir,
        "output_dir": output_dir,
        "scripts_path": get_scripts_path(),
        "moose_app": get_moose_app_path(getattr(args, 'moose_app', None))
    }
    
    # 添加模板文件路径，如果存在
    if hasattr(args, 'template_main') and args.template_main:
        path_config["template_main"] = args.template_main
    
    if hasattr(args, 'template_sub') and args.template_sub:
        path_config["template_sub"] = args.template_sub
    
    return path_config 