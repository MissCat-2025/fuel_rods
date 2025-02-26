#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
环境管理模块
-----------
管理conda环境和MOOSE环境

主要功能：
1. 检查环境是否存在
2. 创建或更新环境
3. 在指定环境中执行命令
"""

import os
import subprocess
import re
import sys
from .command_executor import run_command

def check_conda_installed():
    """
    检查conda是否已安装
    
    Returns:
        bool: conda是否已安装
    """
    try:
        result = subprocess.run(
            "conda --version", 
            shell=True, 
            stdout=subprocess.PIPE, 
            stderr=subprocess.PIPE, 
            universal_newlines=True
        )
        return result.returncode == 0
    except Exception:
        return False

def get_conda_path():
    """
    获取conda安装路径
    
    Returns:
        str: conda安装目录
    """
    try:
        result = subprocess.run(
            "conda info --base", 
            shell=True, 
            stdout=subprocess.PIPE, 
            stderr=subprocess.PIPE, 
            universal_newlines=True
        )
        if result.returncode == 0:
            return result.stdout.strip()
    except Exception:
        pass
    
    # 尝试默认路径
    home_dir = os.path.expanduser("~")
    possible_paths = [
        os.path.join(home_dir, "miniconda3"),
        os.path.join(home_dir, "anaconda3"),
        os.path.join(home_dir, "miniconda"),
        os.path.join(home_dir, "anaconda")
    ]
    
    for path in possible_paths:
        if os.path.exists(path):
            return path
    
    return None

def check_env_exists(env_name):
    """
    检查指定的conda环境是否存在
    
    Args:
        env_name: 环境名称
        
    Returns:
        bool: 环境是否存在
    """
    try:
        result = subprocess.run(
            f"conda env list | grep -w {env_name}", 
            shell=True, 
            stdout=subprocess.PIPE, 
            stderr=subprocess.PIPE, 
            universal_newlines=True
        )
        return result.returncode == 0 and env_name in result.stdout
    except Exception:
        return False

def create_conda_env(env_name, python_version="3.10", packages=None, channels=None):
    """
    创建新的conda环境
    
    Args:
        env_name: 环境名称
        python_version: Python版本
        packages: 安装的包列表
        channels: 使用的频道列表
        
    Returns:
        bool: 是否成功创建环境
    """
    if check_env_exists(env_name):
        print(f"环境 {env_name} 已存在")
        return True
    
    if packages is None:
        packages = []
    
    if channels is None:
        channels = []
    
    # 构建创建环境的命令
    channels_str = " ".join([f"-c {channel}" for channel in channels])
    
    create_cmd = f"conda create -y {channels_str} -n {env_name} python={python_version}"
    
    if packages:
        packages_str = " ".join(packages)
        create_cmd += f" {packages_str}"
    
    # 执行命令
    try:
        print(f"创建环境: {env_name}")
        result = subprocess.run(
            create_cmd, 
            shell=True, 
            stdout=subprocess.PIPE, 
            stderr=subprocess.STDOUT, 
            universal_newlines=True
        )
        success = result.returncode == 0
        
        if success:
            print(f"环境 {env_name} 创建成功")
        else:
            print(f"环境 {env_name} 创建失败")
            print(result.stdout)
        
        return success
    except Exception as e:
        print(f"创建环境出错: {str(e)}")
        return False

def install_packages(env_name, packages, channels=None):
    """
    在指定环境中安装包
    
    Args:
        env_name: 环境名称
        packages: 要安装的包列表
        channels: 使用的频道列表
        
    Returns:
        bool: 是否成功安装包
    """
    if not packages:
        return True
    
    if channels is None:
        channels = []
    
    # 构建安装命令
    channels_str = " ".join([f"-c {channel}" for channel in channels])
    packages_str = " ".join(packages)
    
    # 使用conda激活环境并安装包
    install_cmd = f"source $(conda info --base)/etc/profile.d/conda.sh && conda activate {env_name} && conda install -y {channels_str} {packages_str}"
    
    # 执行命令
    try:
        print(f"在环境 {env_name} 中安装包: {packages_str}")
        result = subprocess.run(
            install_cmd, 
            shell=True, 
            stdout=subprocess.PIPE, 
            stderr=subprocess.STDOUT, 
            universal_newlines=True
        )
        success = result.returncode == 0
        
        if success:
            print(f"包安装成功")
        else:
            print(f"包安装失败")
            print(result.stdout)
        
        return success
    except Exception as e:
        print(f"安装包出错: {str(e)}")
        return False

def setup_paraview_env(env_name="paraview_post", force_recreate=False):
    """
    设置ParaView环境
    
    Args:
        env_name: 环境名称
        force_recreate: 是否强制重建环境
        
    Returns:
        bool: 是否成功设置环境
    """
    # 检查conda
    if not check_conda_installed():
        print("错误: 未找到conda，请先安装Miniconda或Anaconda")
        return False
    
    # 获取conda路径
    conda_path = get_conda_path()
    if not conda_path:
        print("错误: 无法确定conda安装路径")
        return False
    
    # 如果需要强制重建
    if force_recreate and check_env_exists(env_name):
        print(f"强制重建环境: {env_name}")
        success, _, _ = run_command(f"conda env remove -y -n {env_name}", shell=True)
        if not success:
            print(f"删除环境 {env_name} 失败")
            return False
    
    # 检查环境是否已存在
    if check_env_exists(env_name):
        print(f"使用现有环境: {env_name}")
        return True
    
    # 创建新环境
    if not create_conda_env(env_name, python_version="3.10"):
        return False
    
    # 安装mamba加速器
    if not install_packages(env_name, ["mamba"], ["conda-forge"]):
        print("警告: mamba安装失败，将使用conda安装包（速度较慢）")
    
    # 安装ParaView和其他包
    packages = [
        "paraview=5.11.1",
        "vtk=9.2.5",
        "numpy=1.24.4",
        "matplotlib=3.7.1",
        "h5py=3.9.0",
        "pandas=1.5.3",
        "scipy=1.10.1"
    ]
    
    # 构建安装命令（使用mamba加速）
    install_cmd = f"source $(conda info --base)/etc/profile.d/conda.sh && conda activate {env_name} && mamba install -y -c conda-forge {' '.join(packages)}"
    
    # 执行命令
    success, _, _ = run_command(install_cmd, shell=True)
    
    if success:
        print(f"环境 {env_name} 配置成功")
    else:
        print(f"环境 {env_name} 配置失败")
    
    return success

def check_moose_env(moose_app_path, conda_env="moose"):
    """
    检查MOOSE环境
    
    Args:
        moose_app_path: MOOSE应用程序路径
        conda_env: MOOSE的conda环境名称
        
    Returns:
        bool: 环境是否正确配置
    """
    # 检查MOOSE可执行文件
    if not os.path.exists(moose_app_path) or not os.access(moose_app_path, os.X_OK):
        print(f"错误: MOOSE可执行文件不存在或不可执行: {moose_app_path}")
        return False
    
    # 检查conda环境
    if not check_env_exists(conda_env):
        print(f"错误: MOOSE conda环境 {conda_env} 不存在")
        return False
    
    # 简单测试MOOSE是否可运行
    test_cmd = f"source $(conda info --base)/etc/profile.d/conda.sh && conda activate {conda_env} && {moose_app_path} --version"
    
    try:
        result = subprocess.run(
            test_cmd, 
            shell=True, 
            stdout=subprocess.PIPE, 
            stderr=subprocess.STDOUT, 
            universal_newlines=True
        )
        
        if result.returncode != 0:
            print(f"警告: MOOSE应用程序可能无法正常运行")
            print(result.stdout)
            return False
        
        # 输出版本信息
        version_match = re.search(r'Version:\s+(\S+)', result.stdout)
        if version_match:
            print(f"MOOSE版本: {version_match.group(1)}")
        
        return True
    except Exception as e:
        print(f"测试MOOSE环境出错: {str(e)}")
        return False
        
def run_in_conda_env(env_name, command, cwd=None, shell=True):
    """
    在指定的conda环境中运行命令
    
    Args:
        env_name: conda环境名称
        command: 要执行的命令
        cwd: 工作目录
        shell: 是否使用shell执行
        
    Returns:
        tuple: (成功标志, 返回码, 输出文本)
    """
    # 构建激活环境的命令
    full_cmd = f"source $(conda info --base)/etc/profile.d/conda.sh && conda activate {env_name} && {command}"
    
    return run_command(full_cmd, cwd=cwd, shell=shell) 