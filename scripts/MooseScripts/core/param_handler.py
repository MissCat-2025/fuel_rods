#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
参数处理模块
-----------
处理参数矩阵、参数组合和特殊值的格式化

主要功能：
1. 解析JSON参数
2. 生成所有参数组合（笛卡尔积）
3. 过滤无效参数组合
4. 格式化科学计数法
"""

import json
import itertools
import re
from datetime import datetime

from ..utils.error_handler import ParameterError

def parse_json_parameter(json_str, default_value=None):
    """
    解析JSON参数字符串
    
    Args:
        json_str (str): JSON格式的字符串
        default_value: 解析失败时的默认值
        
    Returns:
        解析后的Python对象
    """
    try:
        return json.loads(json_str)
    except json.JSONDecodeError as e:
        raise ParameterError(f"无法解析JSON参数：{e}") from e

def format_scientific(value):
    """
    将数值格式化为科学计数法字符串
    
    Args:
        value: 需要格式化的数值
        
    Returns:
        str: 科学计数法格式的字符串
    """
    if isinstance(value, float) and (abs(value) >= 1e4 or abs(value) < 1e-3):
        return f"{value:.4e}".replace('e-0', 'e-').replace('e+0', 'e+')
    return str(value)

def generate_parameter_combinations(params_dict, exclude_combinations=None):
    """
    生成所有参数的笛卡尔积组合，排除不可运行的组合
    
    Args:
        params_dict (dict): 参数字典，格式为 {参数名: [值1, 值2, ...]}
        exclude_combinations (list, optional): 排除的组合列表
        
    Returns:
        list: 有效参数组合的列表
    """
    if exclude_combinations is None:
        exclude_combinations = []
    
    # 生成笛卡尔积
    keys = list(params_dict.keys())
    values = list(params_dict.values())
    
    if not keys or not values:
        raise ParameterError("参数矩阵不能为空")
    
    all_combinations = [dict(zip(keys, combo)) for combo in itertools.product(*values)]
    
    # 过滤掉排除列表中的组合
    valid_combinations = [
        combo for combo in all_combinations 
        if not should_exclude_combination(combo, exclude_combinations)
    ]
    
    return valid_combinations

def should_exclude_combination(params, exclude_combinations):
    """
    检查参数组合是否在排除列表中
    
    Args:
        params (dict): 要检查的参数组合
        exclude_combinations (list): 排除的组合列表
        
    Returns:
        bool: 是否应该排除
    """
    if not exclude_combinations:
        return False
        
    for exclude_combo in exclude_combinations:
        # 将排除组合转换为字典进行比较
        exclude_dict = {}
        for i in range(0, len(exclude_combo), 2):
            if i + 1 < len(exclude_combo):  # 确保有配对的值
                param_name = exclude_combo[i]
                param_value = exclude_combo[i+1]
                exclude_dict[param_name] = param_value
        
        # 检查所有排除参数是否匹配
        match = True
        for param_name, param_value in exclude_dict.items():
            if param_name not in params:
                match = False
                break
                
            # 检查数值是否相等（考虑浮点误差）
            if isinstance(params[param_name], (int, float)) and isinstance(param_value, (int, float)):
                if abs(params[param_name] - param_value) > 1e-10:
                    match = False
                    break
            elif params[param_name] != param_value:
                match = False
                break
        
        if match:
            return True
    
    return False

def generate_case_name(params):
    """
    生成包含所有参数的短名称
    
    Args:
        params (dict): 参数字典
        
    Returns:
        str: 包含参数的短名称
    """
    # 参数排序，确保名称稳定
    sorted_params = sorted(params.items())
    return '_'.join([f"{k[:2]}{format_scientific(v).replace('.','_')}" 
                    for k, v in sorted_params])

def replace_parameters(content, params):
    """
    在文本内容中替换参数
    
    Args:
        content (str): 要处理的文本内容
        params (dict): 参数字典
        
    Returns:
        str: 替换后的文本内容
    """
    # 先处理常规参数
    for param, value in params.items():
        pattern = rf'(\s*){param}\s*=\s*[\d\.eE+-]+(.*?)(\n)'
        replacement = f'\\1{param} = {format_scientific(value)}\\2\\3'
        content = re.sub(pattern, replacement, content, flags=re.MULTILINE)
    
    # 特殊处理MultiApp的input_files参数
    subapp_filename = f"sub_{generate_case_name(params)}.i"
    content = re.sub(
        r'(input_files\s*=\s*)\'\S+\.i\'',
        f"\\1'{subapp_filename}'", 
        content
    )
    
    return content

def generate_header(params, end_time=None):
    """
    生成包含参数信息的注释头
    
    Args:
        params (dict): 参数字典
        end_time (float, optional): 仿真结束时间
        
    Returns:
        str: 注释头文本
    """
    header = "# === 参数研究案例 ===\n"
    
    # 添加end_time
    if end_time is not None:
        header += f"# end_time = {format_scientific(end_time)}\n"
    
    # 添加参数
    for k, v in sorted(params.items()):
        header += f"# {k}: {format_scientific(v)}\n"
    
    # 添加生成时间
    header += f"# 生成时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n"
    
    return header

def print_parameter_info(parameter_matrix, exclude_combinations):
    """
    打印参数矩阵和排除组合的信息
    
    Args:
        parameter_matrix: 参数矩阵字典
        exclude_combinations: 排除的组合列表
    """
    # 计算所有组合数量
    total_combinations = len(list(itertools.product(*parameter_matrix.values())))
    
    # 计算有效组合数量
    valid_combinations = generate_parameter_combinations(parameter_matrix, exclude_combinations)
    valid_count = len(valid_combinations)
    
    # 排除的组合数量
    excluded_count = total_combinations - valid_count
    
    print("\n===== 参数矩阵信息 =====")
    print(f"参数数量: {len(parameter_matrix)}")
    print(f"可能的组合数: {total_combinations}")
    print(f"排除的组合数: {excluded_count}")
    print(f"有效组合数: {valid_count}")
    
    print("\n参数取值范围:")
    for param, values in parameter_matrix.items():
        print(f"  {param}: {[format_scientific(v) for v in values]}")
    
    if exclude_combinations:
        print("\n排除的组合:")
        for combo in exclude_combinations:
            params_str = ", ".join(f"{combo[i]}={format_scientific(combo[i+1])}" for i in range(0, len(combo), 2))
            print(f"  - {params_str}")
    
    print("========================") 