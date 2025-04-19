#!/usr/bin/env python3
"""
MOOSE网格生成器启动脚本

此脚本是MOOSE参数研究系统的主要入口点，提供以下功能：
1. 连接基础代码库（/home/yp/projects/fuel_rods/scripts）
2. 设置正确的Python路径
3. 启动网格生成器
4. 智能检测MOOSE输入文件(支持两种使用模式)
   - 直接输入文件路径模式
   - 脚本目录下文件选择模式
5. 确保parameter_studies目录在主模板文件所在目录下生成

这个脚本设计为可在任意位置运行，完全独立于基础代码库的位置。
"""

import os
import sys
import argparse
import traceback
import re
from typing import List, Optional, Dict, Any, Tuple

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
# 导入必要的函数和配置
# ============================
try:
    from MooseScripts.config import MESSAGES, MOOSE_INPUT_EXTENSION
    from MooseScripts.step1_MeshGenerator import main, parse_arguments
    from MooseScripts.utils.path_utils import detect_moose_input_files, find_sub_file_for_main, list_files
    from MooseScripts.utils.path_utils import extract_input_files_from_multiapps, select_main_file
except ImportError as e:
    print(f"错误: 无法导入必要的模块: {str(e)}")
    print(f"请确认基础脚本路径 {base_scripts_path} 是否正确，并且包含所需的模块。")
    sys.exit(1)

# ============================
# 常量定义
# ============================
VERSION = "1.6.0"

# ============================
# 工具函数
# ============================
def print_directory_info(directory: str) -> Dict[str, Any]:
    """
    分析并打印目录信息和MOOSE输入文件
    
    Args:
        directory: 要分析的目录路径
        
    Returns:
        Dict[str, Any]: 检测结果字典
    """
    print(MESSAGES['directory_analysis_header'].format(directory))
    
    # 验证目录存在
    if not os.path.isdir(directory):
        print(MESSAGES.get('directory_not_exist', '错误: 目录不存在 ({})').format(directory))
        return {"error": "directory_not_exist"}
    
    # 使用高级检测功能
    result = detect_moose_input_files(directory)
    
    # 结果已经包含了所有必要的文件信息和分类
    # detect_moose_input_files函数会自动打印文件列表和数量
    
    return result

def has_moose_input_files(directory: str) -> bool:
    """
    检查目录中是否存在MOOSE输入文件
    
    Args:
        directory: 要检查的目录路径
        
    Returns:
        bool: 是否存在MOOSE输入文件
    """
    if not os.path.isdir(directory):
        return False
    
    for file in os.listdir(directory):
        if file.endswith(MOOSE_INPUT_EXTENSION):
            return True
    return False

def extract_multiapps_info(file_path: str) -> Dict[str, Any]:
    """
    分析文件中的MultiApps信息
    
    Args:
        file_path: 要分析的文件路径
        
    Returns:
        Dict[str, Any]: 包含MultiApps信息的字典
    """
    info = {
        "has_multiapps": False,
        "sub_files": [],
        "type": "单文件"
    }
    
    try:
        with open(file_path, 'r') as f:
            content = f.read()
            
            # 检查是否包含非注释的[MultiApps]块
            multiapps_blocks = re.findall(r'\[MultiApps\]', content)
            commented_blocks = re.findall(r'#.*\[MultiApps\]', content) 
            valid_blocks = len(multiapps_blocks) - len(commented_blocks)
            
            if valid_blocks > 0:
                info["has_multiapps"] = True
                info["type"] = "复合文件"
                
                # 提取引用的子文件
                info["sub_files"] = extract_input_files_from_multiapps(content)
    except Exception as e:
        print(f"分析文件时出错: {str(e)}")
    
    return info

def check_specific_file(file_path: str) -> Tuple[bool, Optional[str]]:
    """
    检查指定的文件是否是MOOSE输入文件，并尝试找到对应的子文件
    
    Args:
        file_path: 要检查的文件路径
        
    Returns:
        Tuple[bool, Optional[str]]: (是否为MOOSE输入文件, 子文件路径)
    """
    # 验证文件存在
    if not os.path.isfile(file_path):
        print(MESSAGES.get('file_not_exist', '错误: 文件不存在 ({})').format(file_path))
        return False, None
    
    # 验证文件扩展名
    if not file_path.endswith(MOOSE_INPUT_EXTENSION):
        print(MESSAGES.get('not_moose_input', '错误: 不是有效的MOOSE输入文件 ({})').format(file_path))
        return False, None
    
    # 分析文件的MultiApps信息
    info = extract_multiapps_info(file_path)
    
    # 显示检测结果
    if info["has_multiapps"]:
        print(MESSAGES.get('main_file_detected', '检测到复合文件(含MultiApps): {}').format(os.path.basename(file_path)))
    else:
        print(MESSAGES.get('single_file_detected', '检测到单文件: {}').format(os.path.basename(file_path)))
    
    # 如果是复合文件，寻找子文件
    sub_file = None
    if info["has_multiapps"] and info["sub_files"]:
        directory = os.path.dirname(file_path)
        for sub_name in info["sub_files"]:
            sub_path = os.path.join(directory, sub_name)
            if os.path.exists(sub_path):
                sub_file = sub_path
                break
    
    return True, sub_file

def run_from_file(input_file: str) -> int:
    """
    基于指定的输入文件运行网格生成器
    
    此函数处理直接指定输入文件路径的情况。
    它会自动检测文件是否为复合文件，并相应地设置子文件。
    
    Args:
        input_file: MOOSE输入文件路径
        
    Returns:
        int: 进程退出码
    """
    # 检查文件并查找可能的子文件
    is_valid, sub_file = check_specific_file(input_file)
    if not is_valid:
        return 1
    
    # 获取文件所在目录作为工作目录
    work_dir = os.path.dirname(input_file)
    
    # 创建新的命令行参数
    sys_argv = [sys.argv[0]]  # 只保留脚本名称
    sys_argv.extend(['--base-dir', work_dir])
    sys_argv.extend(['--main-template', input_file])
    
    # 如果找到子文件，添加到参数
    if sub_file:
        print(MESSAGES.get('sub_file_detected', '检测到对应的子文件: {}').format(os.path.basename(sub_file)))
        sys_argv.extend(['--sub-template', sub_file])
    else:
        print(MESSAGES.get('no_sub_file', '未检测到子文件，将作为单文件处理'))
    
    # 设置新的argv并运行
    old_argv = sys.argv
    sys.argv = sys_argv
    
    try:
        print(MESSAGES['mesh_generator_start'])
        print(MESSAGES['parameter_studies_note'])
        return main()
    except Exception as e:
        print(f"\n执行过程中出现错误: {str(e)}")
        if not os.environ.get('PRODUCTION'):  # 非生产环境显示详细错误
            traceback.print_exc()
        return 1
    finally:
        # 恢复argv
        sys.argv = old_argv

def run_from_directory(target_dir: str) -> int:
    """
    从指定目录运行网格生成器
    
    此函数处理在包含输入文件的目录中运行脚本的情况。
    它会分析目录中的MOOSE输入文件，并在有多个文件时提供选择界面。
    
    Args:
        target_dir: 目标目录路径
        
    Returns:
        int: 进程退出码
    """
    # 检查目录是否存在
    if not os.path.isdir(target_dir):
        print(MESSAGES.get('directory_not_exist', '警告: 指定的目录不存在 ({})').format(target_dir))
        print("请使用 --target-dir 指定有效的目录，或使用 --input-file 直接指定输入文件")
        return 1
    
    # 分析目录中的MOOSE输入文件
    print(MESSAGES.get('directory_analysis_header', '\n=== 分析目录 ({}) ===').format(target_dir))
    
    # 使用高级检测功能
    result = detect_moose_input_files(target_dir)
    
    # 检查目录中是否有任何输入文件
    if not result.get("input_files"):
        print(MESSAGES.get('no_input_files', '在目录 ({}) 中未找到MOOSE输入文件(.i文件)').format(target_dir))
        print("您可以使用以下选项:")
        print("1. 指定包含.i文件的目录: --target-dir /path/to/input/files")
        print("2. 直接指定输入文件路径: --input-file /path/to/file.i")
        return 1
    
    # 创建新的命令行参数
    sys_argv = [sys.argv[0]]  # 只保留脚本名称
    sys_argv.extend(['--base-dir', target_dir])
    
    # 如果有复合文件，让用户选择
    main_template_path = None
    sub_template_path = None
    
    # 检查是否有复合文件和单文件，按优先级处理
    has_choice = False
    files_to_choose = []
    
    # 首先处理复合文件
    if result.get("main_files") and len(result.get("main_files")) > 0:
        if len(result.get("main_files")) == 1:
            # 只有一个复合文件，直接使用
            main_template_path = result.get("main_files")[0]
            
            # 查找对应的子文件
            for pair in result.get("main_sub_pairs", []):
                if pair["main"] == main_template_path:
                    sub_template_path = pair["sub"]
                    break
        else:
            # 多个复合文件，让用户选择
            has_choice = True
            files_to_choose = result.get("main_files")
    
    # 如果没有复合文件，处理单文件
    elif result.get("standalone_files") and len(result.get("standalone_files")) > 0:
        if len(result.get("standalone_files")) == 1:
            # 只有一个单文件，直接使用
            main_template_path = result.get("standalone_files")[0]
        else:
            # 多个单文件，让用户选择
            has_choice = True
            files_to_choose = result.get("standalone_files")
    
    # 如果需要用户选择
    if has_choice:
        chosen_file = select_main_file(files_to_choose)
        if chosen_file:
            main_template_path = chosen_file
            
            # 如果选择的是复合文件，查找对应的子文件
            if chosen_file in result.get("main_files", []):
                for pair in result.get("main_sub_pairs", []):
                    if pair["main"] == chosen_file:
                        sub_template_path = pair["sub"]
                        break
    
    # 如果没有选择文件，返回
    if not main_template_path:
        print("未选择任何文件，操作取消")
        return 1
    
    # 添加模板文件路径到参数
    sys_argv.extend(['--main-template', main_template_path])
    if sub_template_path:
        sys_argv.extend(['--sub-template', sub_template_path])
    
    # 过滤掉特定参数
    skip_args = ['--show-files', '--target-dir', '--input-file']
    for arg in sys.argv[1:]:
        if not any(arg.startswith(skip) for skip in skip_args):
            sys_argv.append(arg)
    
    # 设置新的argv
    old_argv = sys.argv
    sys.argv = sys_argv
    
    try:
        print(MESSAGES['mesh_generator_start'])
        print(MESSAGES['parameter_studies_note'])
        
        if main_template_path:
            print(f"\n使用主模板文件: {os.path.basename(main_template_path)}")
            if sub_template_path:
                print(f"使用子模板文件: {os.path.basename(sub_template_path)}")
        
        return main()
    except KeyboardInterrupt:
        print("\n操作被用户取消")
        return 1
    except Exception as e:
        print(f"\n执行过程中出现错误: {str(e)}")
        print("排查建议:")
        print("1. 确认目录中包含正确的MOOSE输入文件(.i文件)")
        print("2. 检查文件格式是否符合MOOSE要求")
        print("3. 确保有足够的权限访问文件和目录")
        # 如果有详细错误信息，打印出来
        if not os.environ.get('PRODUCTION'):  # 非生产环境显示详细错误
            traceback.print_exc()
        return 1
    finally:
        # 恢复argv
        sys.argv = old_argv

# ============================
# 主函数
# ============================
def main_entry():
    """主入口函数"""
    # 命令行参数处理
    parser = argparse.ArgumentParser(description='MOOSE网格生成器启动工具')
    parser.add_argument('--target-dir', type=str, default=None,
                        help='要处理的目标目录，默认为脚本所在目录')
    parser.add_argument('--input-file', type=str, default=None,
                        help='直接指定MOOSE输入文件路径，优先级高于目标目录')
    parser.add_argument('--show-files', action='store_true',
                        help='显示目录中的文件列表')
    parser.add_argument('--version', action='store_true',
                        help='显示版本信息')
    
    args, unknown = parser.parse_known_args()
    
    # 显示版本信息
    if args.version:
        print(f"MOOSE网格生成器启动工具 v{VERSION}")
        return 0
    
    # ============================
    # 确定运行模式和目标
    # ============================
    # 优先使用指定的输入文件（直接文件模式）
    if args.input_file:
        input_file = os.path.abspath(args.input_file)
        print(MESSAGES.get('file_mode_header', '\n===== 运行模式: 直接文件模式 ====='))
        print(f"指定的输入文件: {input_file}")
        return run_from_file(input_file)
    
    # 处理目录模式
    # 如果未指定目标目录，则使用脚本所在目录
    target_dir = os.path.abspath(args.target_dir or os.getcwd())
    
    # 检查目标目录中是否有MOOSE输入文件
    has_input_files = has_moose_input_files(target_dir)
    
    # ============================
    # 显示路径信息
    # ============================
    print(MESSAGES.get('path_info_header', '\n===== 路径信息 ====='))
    print(f"1. 脚本位置: {script_dir}")
    print(f"2. 基础代码库: {base_scripts_path}")
    print(f"3. 工作目录: {target_dir}" + (" (存在MOOSE输入文件)" if has_input_files else " (未检测到MOOSE输入文件)"))
    
    # ============================
    # 执行目录模式
    # ============================
    print(MESSAGES.get('directory_mode_header', '\n===== 运行模式: 目录模式 ====='))
    return run_from_directory(target_dir)

if __name__ == '__main__':
    sys.exit(main_entry()) 