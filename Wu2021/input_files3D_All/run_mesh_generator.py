#!/usr/bin/env python3
"""
MooseScripts网格生成器启动脚本

此脚本的主要功能是：
1. 连接基础代码库（/home/yp/projects/fuel_rods/scripts）
2. 设置正确的Python路径
3. 启动网格生成器
4. 自动检测MOOSE输入文件
5. 确保parameter_studies目录在主模板文件所在目录下生成

脚本可以在任意位置运行，与基础代码库位置无关。
"""

import os
import sys
import glob
import argparse

# ============================
# 路径设置部分
# ============================

# 获取当前脚本所在目录路径（可能在任何位置）
script_dir = os.path.dirname(os.path.abspath(__file__))

# 添加必要的路径到Python模块搜索路径
parent_dir = os.path.dirname(script_dir)
if parent_dir not in sys.path:
    sys.path.insert(0, parent_dir)
if script_dir not in sys.path:
    sys.path.insert(0, script_dir)

# 添加固定的基础脚本库路径到系统路径（这是所有代码库所在的位置）
base_scripts_path = '/home/yp/projects/fuel_rods/scripts'
if base_scripts_path not in sys.path:
    sys.path.insert(0, base_scripts_path)

# ============================
# 导入必要的函数
# ============================
from MooseScripts.step1_MeshGenerator import main, parse_arguments
from MooseScripts.utils.path_utils import detect_moose_input_files

# ============================
# 工具函数
# ============================
def print_directory_info(directory):
    """
    打印目录信息和MOOSE输入文件
    
    Args:
        directory: 要分析的目录路径
    """
    print(f"\n=== 目录内容分析 ({directory}) ===")
    
    # 列出目录中的所有文件
    all_files = os.listdir(directory)
    print(f"总共找到 {len(all_files)} 个文件/文件夹")
    
    # 查找所有.i文件
    i_files = [f for f in all_files if f.endswith('.i')]
    print(f"找到 {len(i_files)} 个MOOSE输入文件:")
    for i, file in enumerate(i_files, 1):
        file_path = os.path.join(directory, file)
        size = os.path.getsize(file_path) / 1024.0  # KB
        print(f"  {i}. {file} ({size:.1f} KB)")
    
    # 使用现有的检测函数
    result = detect_moose_input_files(directory)
    if result.get("main_file") and result.get("sub_file"):
        print("\n检测到主-子文件对:")
        print(f"  主文件: {os.path.basename(result['main_file'])}")
        print(f"  子文件: {os.path.basename(result['sub_file'])}")
    elif result.get("main_file"):
        print(f"\n检测到单个模板文件: {os.path.basename(result['main_file'])}")
    elif result.get("input_files"):
        print("\n未能确定主-子文件关系")
    else:
        print("\n未找到MOOSE输入文件！")
        # 尝试在父目录查找
        parent_dir = os.path.dirname(directory)
        print(f"尝试在父目录 {parent_dir} 中查找...")
        if parent_dir != directory:  # 防止到达根目录时无限循环
            print_directory_info(parent_dir)

def has_moose_input_files(directory):
    """
    检查目录中是否存在MOOSE输入文件
    
    Args:
        directory: 要检查的目录路径
        
    Returns:
        bool: 是否存在.i文件
    """
    if not os.path.isdir(directory):
        return False
    
    for file in os.listdir(directory):
        if file.endswith('.i'):
            return True
    return False

def run_from_directory(target_dir, show_files=False):
    """
    从指定目录运行网格生成器
    
    Args:
        target_dir: 目标目录路径，应包含MOOSE输入文件或在提示时指定
        show_files: 是否显示目录文件信息
        
    Returns:
        int: 进程退出码
    """
    # 先分析目录中的MOOSE输入文件
    if show_files or True:  # 始终显示文件信息便于用户了解
        print_directory_info(target_dir)
    
    # 创建新的命令行参数
    sys_argv = [sys.argv[0]]  # 只保留脚本名称
    
    # 添加base-dir参数（这是工作目录，用于初始检测输入文件）
    sys_argv.extend(['--base-dir', target_dir])
    
    # 过滤掉--show-files和--target-dir参数，避免传递给main函数
    for arg in sys.argv[1:]:
        if not arg.startswith('--show-files') and not arg.startswith('--target-dir'):
            sys_argv.append(arg)
    
    # 设置新的argv
    old_argv = sys.argv
    sys.argv = sys_argv
    
    try:
        print(f"\n开始执行网格生成器")
        print("注意: parameter_studies将创建在主模板文件所在目录下")
        return main()
    finally:
        # 恢复argv
        sys.argv = old_argv

if __name__ == '__main__':
    # ============================
    # 命令行参数处理
    # ============================
    parser = argparse.ArgumentParser(description='MOOSE网格生成器启动工具')
    parser.add_argument('--target-dir', type=str, default=None,
                        help='要处理的目标目录，默认为脚本所在目录')
    parser.add_argument('--show-files', action='store_true',
                        help='显示目录中的文件列表')
    
    args, unknown = parser.parse_known_args()
    
    # ============================
    # 确定目标目录（工作目录）
    # ============================
    # 如果未指定目标目录，则优先使用脚本所在目录
    target_dir = args.target_dir or script_dir
    
    # 检查目标目录中是否有MOOSE输入文件
    has_input_files = has_moose_input_files(target_dir)
    
    # ============================
    # 显示路径信息
    # ============================
    print(f"\n===== 路径信息 =====")
    print(f"1. 脚本位置: {script_dir}")
    print(f"2. 基础代码库: {base_scripts_path}")
    print(f"3. 目标目录: {target_dir}" + (" (存在MOOSE输入文件)" if has_input_files else ""))
    
    # 显示目录文件信息（如果请求）
    if args.show_files:
        print_directory_info(target_dir)
    
    # 从目标目录运行
    sys.exit(run_from_directory(target_dir, args.show_files)) 