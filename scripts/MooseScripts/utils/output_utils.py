#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
输出工具模块
-----------
处理配置信息的打印和格式化

主要功能：
1. 打印配置信息
2. 格式化输出
3. 输出不同类型的信息
"""

import json
import os
from datetime import datetime

def print_separator(char='=', length=50):
    """
    打印分隔线
    
    Args:
        char: 分隔符字符
        length: 分隔线长度
    """
    print(char * length)

def print_header(title, char='=', length=50):
    """
    打印标题头
    
    Args:
        title: 标题文本
        char: 分隔符字符
        length: 分隔线长度
    """
    print(f"\n{char * length}")
    print(f"{title.center(length)}")
    print(f"{char * length}")

def print_config(config_dict, title="配置信息"):
    """
    打印配置字典
    
    Args:
        config_dict: 配置字典
        title: 配置标题
    """
    print_header(title)
    for key, value in config_dict.items():
        if isinstance(value, dict):
            print(f"{key}:")
            for sub_key, sub_value in value.items():
                print(f"  {sub_key}: {sub_value}")
        elif isinstance(value, list) and len(value) > 10:
            print(f"{key}: [列表包含{len(value)}项]")
        elif isinstance(value, list) and all(isinstance(item, dict) for item in value):
            print(f"{key}: [包含{len(value)}个字典]")
        else:
            print(f"{key}: {value}")
    print_separator()

def print_workflow_config(path_config, param_config=None, run_config=None):
    """
    打印工作流配置信息
    
    Args:
        path_config: 路径配置字典
        param_config: 参数配置字典
        run_config: 运行配置字典
    """
    print_header("工作流配置")
    
    # 打印路径配置
    print("=== 路径配置 ===")
    for key, value in path_config.items():
        print(f"{key}: {value}")
    
    # 打印参数配置（如果有）
    if param_config:
        print("\n=== 参数配置 ===")
        if 'parameter_matrix' in param_config:
            print(f"参数矩阵: {json.dumps(param_config['parameter_matrix'], indent=2)}")
        if 'exclude_combinations' in param_config:
            print(f"排除组合: {json.dumps(param_config['exclude_combinations'], indent=2)}")
    
    # 打印运行配置（如果有）
    if run_config:
        print("\n=== 运行配置 ===")
        for key, value in run_config.items():
            print(f"{key}: {value}")
    
    print("=====================")

def print_step_header(step_name, step_number=None, total_steps=None):
    """
    打印步骤标题
    
    Args:
        step_name: 步骤名称
        step_number: 步骤编号（可选）
        total_steps: 总步骤数（可选）
    """
    if step_number and total_steps:
        header = f"步骤 {step_number}/{total_steps}: {step_name}"
    else:
        header = f"步骤: {step_name}"
    
    print_header(header, '=')

def print_case_info(case_index, total_cases, case_name, case_dir):
    """
    打印案例信息
    
    Args:
        case_index: 案例索引
        total_cases: 总案例数
        case_name: 案例名称
        case_dir: 案例目录
    """
    print(f"\n处理案例 {case_index}/{total_cases}: {case_name}")
    print(f"目录: {case_dir}")
    print('-' * 50)

def print_summary(success_count, failed_count, skipped_count=0, total_time=None):
    """
    打印处理摘要
    
    Args:
        success_count: 成功案例数
        failed_count: 失败案例数
        skipped_count: 跳过案例数
        total_time: 总耗时（秒）
    """
    total_count = success_count + failed_count + skipped_count
    
    print_header("处理摘要")
    print(f"总案例数: {total_count}")
    print(f"成功案例: {success_count} ({success_count/total_count*100:.1f}%)")
    print(f"失败案例: {failed_count} ({failed_count/total_count*100:.1f}%)")
    
    if skipped_count > 0:
        print(f"跳过案例: {skipped_count} ({skipped_count/total_count*100:.1f}%)")
    
    if total_time:
        hours = int(total_time // 3600)
        minutes = int((total_time % 3600) // 60)
        seconds = int(total_time % 60)
        print(f"总耗时: {hours}小时 {minutes}分钟 {seconds}秒")
    
    print(f"当前时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print_separator()

def print_file_list(file_list, title="文件列表", max_files=10):
    """
    打印文件列表
    
    Args:
        file_list: 文件路径列表
        title: 列表标题
        max_files: 最大显示文件数
    """
    print(f"\n=== {title} ===")
    
    if not file_list:
        print("未找到文件")
        return
    
    if len(file_list) > max_files:
        # 只显示部分文件
        for i, file_path in enumerate(file_list[:max_files], 1):
            print(f"{i}. {os.path.basename(file_path)}")
        print(f"... 以及其他 {len(file_list) - max_files} 个文件")
    else:
        # 显示所有文件
        for i, file_path in enumerate(file_list, 1):
            print(f"{i}. {os.path.basename(file_path)}")
    
    print(f"总计: {len(file_list)}个文件")

def print_progress(current, total, prefix='进度:', suffix='', length=50, fill='█'):
    """
    打印进度条
    
    Args:
        current: 当前进度
        total: 总数
        prefix: 前缀
        suffix: 后缀
        length: 进度条长度
        fill: 填充字符
    """
    percent = f"{100 * (current / float(total)):.1f}%"
    filled_length = int(length * current // total)
    bar = fill * filled_length + '-' * (length - filled_length)
    print(f'\r{prefix} |{bar}| {percent} {suffix}', end='\r')
    
    # 如果完成，打印换行符
    if current == total:
        print() 