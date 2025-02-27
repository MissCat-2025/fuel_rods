#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
网格与参数研究生成器
----------------
生成网格和参数研究配置文件

主要功能：
1. 解析模板文件
2. 生成参数组合
3. 创建参数研究案例目录
4. 根据参数替换模板文件
"""

import os
import sys
import argparse
import json
import time
import shutil
from datetime import datetime

# 导入基础层功能
from MooseScripts.core.path_manager import (
    resolve_base_dir, resolve_output_dir, ensure_path_exists,
    find_template_files
)
from MooseScripts.core.file_manager import (
    read_file, write_file, extract_end_time, add_checkpoint_to_outputs,
    rename_and_cleanup_files
)
from MooseScripts.core.param_handler import (
    parse_json_parameter, generate_parameter_combinations, generate_case_name,
    replace_parameters, generate_header, format_scientific
)
from MooseScripts.utils.output_utils import (
    print_header, print_config, print_summary, print_progress
)

def parse_args():
    """解析命令行参数"""
    parser = argparse.ArgumentParser(description="网格与参数研究生成器")
    
    # 基本路径参数
    parser.add_argument('--base-dir', default=None, 
                        help='基础目录路径，默认为当前脚本所在目录的父目录')
    parser.add_argument('--template-main', default=None,
                        help='主模板文件路径')
    parser.add_argument('--template-sub', default=None,
                        help='子模板文件路径，如果与主模板相同则为单程序模式')
    parser.add_argument('--output-dir', default=None,
                        help='输出目录名称')
    
    # Checkpoint配置参数
    parser.add_argument('--checkpoint-interval', type=int, default=5,
                        help='Checkpoint存储时间步间隔')
    parser.add_argument('--checkpoint-files', type=int, default=4,
                        help='Checkpoint保留文件数量')
    parser.add_argument('--checkpoint-time', type=int, default=600,
                        help='Checkpoint时间间隔(秒)')
    
    # 参数矩阵（用JSON字符串传递）
    parser.add_argument('--parameter-matrix', type=str, 
                        default='{"Gf":[8,10],"length_scale_paramete":[5e-5,10e-5],"power_factor_mod":[1,2,3]}',
                        help='参数矩阵定义，JSON格式')
    
    # 排除组合（用JSON字符串传递）
    parser.add_argument('--exclude-combinations', type=str,
                        default='[["Gf",8,"length_scale_paramete",10e-5,"power_factor_mod",3],["Gf",10,"length_scale_paramete",5e-5]]',
                        help='排除的参数组合，JSON格式')
    
    # 处理选项
    parser.add_argument('--clean-output', action='store_true',
                        help='清空输出目录')
    parser.add_argument('--verbose', action='store_true',
                        help='显示详细信息')
    
    return parser.parse_args()

def print_parameter_matrix_info(parameter_matrix, exclude_combinations):
    """
    打印参数矩阵和排除组合的详细信息
    
    Args:
        parameter_matrix: 参数矩阵字典
        exclude_combinations: 排除的组合列表
    """
    import itertools
    
    # 计算可能的组合总数
    total_combinations = 1
    for values in parameter_matrix.values():
        total_combinations *= len(values)
    
    valid_combinations = generate_parameter_combinations(parameter_matrix, exclude_combinations)
    valid_count = len(valid_combinations)
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
            if isinstance(combo, (list, tuple)) and len(combo) >= 2:
                if len(combo) % 2 == 0:  # 确保参数是成对的
                    params_str = ", ".join(f"{combo[i]}={format_scientific(combo[i+1])}" for i in range(0, len(combo), 2))
                    print(f"  - {params_str}")
                else:
                    print(f"  - {combo} (格式不正确)")
            else:
                print(f"  - {combo}")
    
    print("=" * 50)

def generate_study_cases(base_dir, template_main, template_sub, output_dir, 
                         parameter_matrix, exclude_combinations,
                         checkpoint_interval, checkpoint_files, checkpoint_time,
                         clean_output=False, verbose=False):
    """
    生成参数研究案例
    
    Args:
        base_dir: 基础目录
        template_main: 主模板文件
        template_sub: 子模板文件
        output_dir: 输出目录
        parameter_matrix: 参数矩阵
        exclude_combinations: 排除组合
        checkpoint_interval: 检查点间隔
        checkpoint_files: 检查点文件数
        checkpoint_time: 检查点时间
        clean_output: 是否清空输出目录
        verbose: 是否显示详细信息
        
    Returns:
        int: 生成的案例数
    """
    # 验证模板文件
    if not os.path.exists(template_main):
        raise FileNotFoundError(f"主模板文件不存在: {template_main}")
    
    # 判断是否为多程序模式
    is_multiapp = template_sub and os.path.exists(template_sub) and os.path.abspath(template_main) != os.path.abspath(template_sub)
    
    # 处理输出目录
    ensure_path_exists(output_dir)
    if clean_output and os.path.exists(output_dir) and os.listdir(output_dir):
        if verbose:
            print(f"清空输出目录: {output_dir}")
        shutil.rmtree(output_dir)
        os.makedirs(output_dir, exist_ok=True)
    
    # 读取模板文件内容
    main_content = read_file(template_main)
    if not main_content:
        raise IOError(f"无法读取主模板文件: {template_main}")
    
    # 如果是多程序模式，读取子模板文件
    if is_multiapp:
        sub_content = read_file(template_sub)
        if not sub_content:
            raise IOError(f"无法读取子模板文件: {template_sub}")
    
    # 提取end_time值
    end_time = extract_end_time(main_content)
    if end_time is None:
        print("⚠️ 未在模板中找到end_time值，将使用默认值10.0")
        end_time = 10.0
    
    # 生成有效参数组合
    valid_combinations = generate_parameter_combinations(parameter_matrix, exclude_combinations)
    if not valid_combinations:
        raise ValueError("没有有效的参数组合")
    
    # 打印生成信息
    case_count = len(valid_combinations)
    print(f"将生成 {case_count} 个参数研究案例")
    
    # 将checkpoint配置添加到主模板
    main_content_with_checkpoint = add_checkpoint_to_outputs(
        main_content, checkpoint_interval, checkpoint_files, checkpoint_time
    )
    
    # 计时
    start_time = time.time()
    created_cases = 0
    
    # 生成所有案例
    for i, params in enumerate(valid_combinations, 1):
        # 生成案例名称
        case_name = generate_case_name(params)
        case_dir = os.path.join(output_dir, f"case_{i:03d}_{case_name}")
        
        # 创建案例目录
        ensure_path_exists(case_dir)
        
        # 替换主模板参数并添加注释头
        main_replaced = replace_parameters(main_content_with_checkpoint, params)
        main_replaced = generate_header(params, end_time) + main_replaced
        
        # 写入主模板文件
        main_file_path = os.path.join(case_dir, f"main_{case_name}.i")
        success = write_file(main_file_path, main_replaced)
        if not success:
            print(f"❌ 写入主模板文件失败: {main_file_path}")
            continue
        
        # 处理子模板文件（多程序模式）
        if is_multiapp:
            sub_replaced = replace_parameters(sub_content, params)
            sub_replaced = generate_header(params, end_time) + sub_replaced
            
            sub_file_path = os.path.join(case_dir, f"sub_{case_name}.i")
            success = write_file(sub_file_path, sub_replaced)
            if not success:
                print(f"❌ 写入子模板文件失败: {sub_file_path}")
                continue
        
        # 重命名和清理文件
        rename_and_cleanup_files(case_dir, case_name, is_multiapp)
        
        # 记录案例信息
        if verbose:
            print(f"生成案例 {i:03d}: {case_name}")
            print(f"  路径: {case_dir}")
            print(f"  模式: {'MultiApp' if is_multiapp else 'SingleApp'}")
        
        created_cases += 1
        print_progress(i, case_count, prefix='生成进度:', suffix=f'({i}/{case_count})', length=50)
    
    # 计算耗时
    elapsed_time = time.time() - start_time
    
    return created_cases

def main():
    """主函数"""
    start_time = time.time()
    
    # 解析命令行参数
    args = parse_args()
    
    try:
        # 设置基础目录
        if args.base_dir is None:
            script_dir = os.path.dirname(os.path.abspath(__file__))
            base_dir = os.path.dirname(os.path.dirname(script_dir))
        else:
            base_dir = args.base_dir
        
        # 设置模板文件路径
        template_main = args.template_main
        template_sub = args.template_sub
        
        # 如果未提供模板文件，尝试在base_dir中查找
        if not template_main:
            print("未指定模板文件，尝试在base_dir中查找...")
            template_candidates = find_template_files(base_dir)
            if template_candidates:
                template_main, template_sub, desc = template_candidates[0]
                print(f"找到模板文件: {desc}")
            else:
                print("❌ 未找到模板文件，请指定--template-main参数")
                return
        
        # 如果只提供了主模板，尝试查找匹配的子模板
        if template_main and not template_sub:
            main_basename = os.path.basename(template_main)
            main_name, main_ext = os.path.splitext(main_basename)
            
            # 尝试两种常见的子模板命名格式
            sub_names = [
                f"{main_name}_Sub{main_ext}",
                f"sub_{main_name}{main_ext}"
            ]
            
            for sub_name in sub_names:
                sub_path = os.path.join(os.path.dirname(template_main), sub_name)
                if os.path.exists(sub_path):
                    print(f"找到匹配的子模板: {sub_name}")
                    template_sub = sub_path
                    break
            
            # 如果没找到子模板，使用主模板作为子模板（单程序模式）
            if not template_sub:
                print("未找到匹配的子模板，将使用单程序模式")
                template_sub = template_main
        
        # 设置输出目录
        if args.output_dir:
            if os.path.isabs(args.output_dir):
                output_dir = args.output_dir
            else:
                output_dir = os.path.join(base_dir, args.output_dir)
        else:
            output_dir = os.path.join(base_dir, "parameter_studies")
        
        # 解析参数矩阵和排除组合
        try:
            parameter_matrix = parse_json_parameter(args.parameter_matrix, {
                'Gf': [8, 10],
                'length_scale_paramete': [5e-5, 10e-5],
                'power_factor_mod': [1, 2, 3],
            })
            
            exclude_combinations = parse_json_parameter(args.exclude_combinations, [
                ['Gf', 8, 'length_scale_paramete', 10e-5, 'power_factor_mod', 3],
                ['Gf', 10, 'length_scale_paramete', 5e-5],
            ])
        except Exception as e:
            print(f"❌ 参数解析错误: {str(e)}")
            print("  使用默认参数")
            parameter_matrix = {
                'Gf': [8, 10],
                'length_scale_paramete': [5e-5, 10e-5],
                'power_factor_mod': [1, 2, 3],
            }
            exclude_combinations = [
                ['Gf', 8, 'length_scale_paramete', 10e-5, 'power_factor_mod', 3],
                ['Gf', 10, 'length_scale_paramete', 5e-5],
            ]
        
        # 打印配置信息
        print_config({
            '基础目录': base_dir,
            '主模板文件': template_main,
            '子模板文件': template_sub,
            '输出目录': output_dir,
            'Checkpoint间隔': args.checkpoint_interval,
            'Checkpoint文件数': args.checkpoint_files,
            'Checkpoint时间间隔': f"{args.checkpoint_time}秒 ({args.checkpoint_time//60}分钟)",
            '清空输出目录': args.clean_output,
            '详细模式': args.verbose
        }, "网格生成器配置")
        
        # 打印参数矩阵信息
        print_parameter_matrix_info(parameter_matrix, exclude_combinations)
        
        # 生成参数研究案例
        case_count = generate_study_cases(
            base_dir,
            template_main,
            template_sub,
            output_dir,
            parameter_matrix,
            exclude_combinations,
            args.checkpoint_interval,
            args.checkpoint_files,
            args.checkpoint_time,
            args.clean_output,
            args.verbose
        )
        
        # 计算总运行时间
        elapsed_time = time.time() - start_time
        hours = int(elapsed_time // 3600)
        minutes = int((elapsed_time % 3600) // 60)
        seconds = int(elapsed_time % 60)
        
        print_header("网格生成器已完成")
        print(f"总共生成: {case_count} 个参数研究案例")
        print(f"总运行时间: {hours}小时 {minutes}分钟 {seconds}秒")
        print(f"当前时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"结果目录: {output_dir}")
    
    except Exception as e:
        print(f"\n❌ 错误: {str(e)}")
        print("\n故障排查建议:")
        print("1. 检查模板文件路径是否正确")
        print("2. 确认参数名称与模板文件中的变量名完全一致")
        print("3. 验证参数值格式是否正确 (支持整型和浮点型)")
        print("4. 检查文件系统权限和磁盘空间")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    main()