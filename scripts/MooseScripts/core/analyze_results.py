#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
仿真结果分析器
-----------
分析MOOSE仿真结果并生成汇总报告

主要功能：
1. 扫描结果目录
2. 解析日志文件
3. 汇总参数和运行结果
4. 生成CSV报告
"""

import os
import re
import csv
import argparse
import time
from datetime import datetime
import json
from collections import defaultdict

# 导入自定义模块
from MooseScripts.core.path_manager import (
    create_path_config, ensure_path_exists
)
from MooseScripts.core.file_manager import (
    read_file, check_convergence
)
from MooseScripts.utils.output_utils import (
    print_header, print_config, print_summary, print_progress
)

def parse_args():
    """解析命令行参数"""
    parser = argparse.ArgumentParser(description="结果分析与汇总工具")
    
    # 基本路径参数
    parser.add_argument('--base-dir', default=None, 
                        help='基础目录路径，默认为当前脚本所在目录的父目录')
    parser.add_argument('--studies-dir', default=None,
                        help='参数研究目录路径，默认为base-dir/parameter_studies')
    parser.add_argument('--output-file', default=None,
                        help='输出文件名，默认为studies-dir/convergence_report.csv')
    
    return parser.parse_args()

def natural_sort_key(s):
    """用于自然排序的键函数"""
    return [int(t) if t.isdigit() else t.lower() for t in re.split(r'(\d+)', s)]

def get_param_names_from_template(studies_dir):
    """
    从输入文件的注释中获取参数的完整名称
    
    Args:
        studies_dir: 研究目录路径
        
    Returns:
        dict: 参数名称映射字典
    """
    # 遍历目录找到第一个输入文件
    for case_dir in os.listdir(studies_dir):
        case_path = os.path.join(studies_dir, case_dir)
        if not os.path.isdir(case_path):
            continue
        
        # 查找输入文件
        input_files = []
        for file in os.listdir(case_path):
            if file.endswith('.i'):
                input_files.append(os.path.join(case_path, file))
        
        if not input_files:
            continue
            
        # 读取第一个输入文件
        content = read_file(input_files[0])
        if not content:
            continue
        
        # 解析文件内容，提取参数名称
        param_dict = {}
        param_pattern = re.compile(r'#\s*(\w+):\s*([\d\.eE+-]+)')
        
        for match in param_pattern.finditer(content):
            param_name = match.group(1)
            
            # 识别参数简写名称
            if param_name == 'Gf':
                short_name = 'gf'
            elif param_name == 'length_scale_paramete':
                short_name = 'le'
            elif param_name == 'power_factor_mod':
                short_name = 'po'
            else:
                # 如果没有找到匹配的简写，使用原名称的前两个字符
                short_name = param_name[:2].lower()
            
            param_dict[short_name] = param_name
        
        if param_dict:
            print(f"找到参数映射: {param_dict}")
            return param_dict
            
    return {}

def parse_parameters_from_case_name(case_name):
    """
    从案例名称中解析参数
    
    Args:
        case_name: 案例名称
        
    Returns:
        dict: 参数字典
    """
    params = {}
    # 匹配形如 _gf10_le5_00e-5_po2 的参数格式
    param_pattern = re.compile(r'_(gf|le|po)(\d+(?:_\d+)*(?:[eE][+-]?\d+)?)')
    
    for match in param_pattern.finditer(case_name):
        name = match.group(1).lower()
        value = match.group(2)
        
        # 将值格式化（例如：将 5_00e-5 转换为 5.00e-5）
        if '_' in value:
            parts = value.split('_', 1)
            value = f"{parts[0]}.{parts[1].replace('_', '')}"
        
        params[name] = value
    
    return params

def analyze_logs(studies_dir, output_path):
    """
    分析仿真日志并生成报告
    
    Args:
        studies_dir: 研究目录路径
        output_path: 输出文件路径
        
    Returns:
        int: 分析的案例数量
    """
    # 获取参数的完整名称
    param_names = get_param_names_from_template(studies_dir)
    print(f"参数名称映射: {param_names}")
    
    # 收集所有案例
    case_list = []
    all_params = set()
    
    # 遍历研究目录
    for case_dir in sorted(os.listdir(studies_dir), key=natural_sort_key):
        case_path = os.path.join(studies_dir, case_dir)
        if not os.path.isdir(case_path):
            continue
        
        # 从案例名称中提取参数
        params = parse_parameters_from_case_name(case_dir)
        all_params.update(params.keys())
        
        case_list.append((case_dir, case_path, params))
    
    # 如果未找到案例，直接返回
    if not case_list:
        print(f"未找到有效案例: {studies_dir}")
        return 0
    
    # 优先级排序参数
    priority_order = ['gf', 'le', 'po']
    sorted_params = sorted(
        all_params,
        key=lambda x: (priority_order.index(x) if x in priority_order else len(priority_order), x)
    )
    
    # 准备结果列表
    results = []
    start_time = time.time()
    total_cases = len(case_list)
    
    # 处理每个案例
    for i, (case_name, case_path, params) in enumerate(case_list, 1):
        # 创建结果记录
        result = {
            'Case': case_name,
            'converged': 'False',
            'end_time': '0',
            'return_code': '1',
            'errors': 'None',
            'error': '',
        }
        
        # 添加参数（使用完整名称）
        for param_short in sorted_params:
            param_full = param_names.get(param_short, param_short)
            result[param_full] = params.get(param_short, '')
        
        # 解析日志文件
        log_path = os.path.join(case_path, 'run.log')
        if not os.path.exists(log_path):
            result['error'] = 'Missing log'
            results.append(result)
            continue
        
        # 读取日志内容
        log_content = read_file(log_path)
        if not log_content:
            result['error'] = 'Empty log'
            results.append(result)
            continue
        
        # 提取返回码
        rc_match = re.search(r'返回码: (\d+)', log_content)
        if rc_match:
            result['return_code'] = rc_match.group(1)
            result['converged'] = 'True' if rc_match.group(1) == '0' else 'False'
        
        # 提取最终时间
        time_steps = re.findall(r'Time Step \d+, time = ([\d\.e+]+)', log_content)
        if time_steps:
            result['end_time'] = time_steps[-1]
        
        # 提取错误信息
        converged, reason = check_convergence(log_content)
        if not converged:
            result['errors'] = reason
        
        # 添加到结果列表
        results.append(result)
        
        # 更新进度
        print_progress(i, total_cases, prefix='分析进度:', suffix=f'({i}/{total_cases})', length=40)
    
    # 生成CSV报告
    # 创建表头：先是案例名，然后是参数，最后是仿真结果
    headers = ['Case'] + [param_names.get(p, p) for p in sorted_params] + [
        'converged', 'end_time', 'return_code', 'errors', 'error'
    ]
    
    # 确保输出目录存在
    output_dir = os.path.dirname(output_path)
    ensure_path_exists(output_dir)
    
    # 写入CSV
    with open(output_path, 'w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=headers)
        writer.writeheader()
        writer.writerows(results)
    
    # 计算耗时
    elapsed_time = time.time() - start_time
    
    # 打印摘要
    print("\n===== 分析完成 =====")
    print(f"总共分析: {len(results)} 个案例")
    print(f"报告路径: {output_path}")
    print(f"总运行时间: {elapsed_time:.2f} 秒")
    
    return len(results)

def main():
    """主函数"""
    start_time = time.time()
    args = parse_args()
    
    # 创建路径配置
    path_config = create_path_config(args)
    base_dir = path_config['base_dir']
    
    # 如果未指定studies_dir，使用默认值
    if args.studies_dir is None:
        studies_dir = path_config['output_dir']
    else:
        studies_dir = args.studies_dir
    
    # 确保studies_dir存在
    if not os.path.exists(studies_dir):
        print(f"错误：参数研究目录不存在: {studies_dir}")
        return
    
    # 如果未指定output_file，使用默认值
    if args.output_file is None:
        output_path = os.path.join(studies_dir, 'convergence_report.csv')
    else:
        # 若提供了相对路径，相对于studies_dir解析
        if not os.path.isabs(args.output_file):
            output_path = os.path.join(studies_dir, args.output_file)
        else:
            output_path = args.output_file
    
    # 打印配置信息
    config = {
        'studies_dir': studies_dir,
        'output_path': output_path,
    }
    print_config(config, "结果分析配置")
    
    # 分析日志文件
    try:
        case_count = analyze_logs(studies_dir, output_path)
        
        # 计算总运行时间
        elapsed_time = time.time() - start_time
        hours = int(elapsed_time // 3600)
        minutes = int((elapsed_time % 3600) // 60)
        seconds = int(elapsed_time % 60)
        
        print(f"\n===== 结果分析器已完成 =====")
        print(f"总共案例: {case_count}")
        print(f"总运行时间: {hours}小时 {minutes}分钟 {seconds}秒")
        print(f"当前时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"报告文件: {output_path}")
        
    except Exception as e:
        print(f"分析过程中出错: {str(e)}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    main() 