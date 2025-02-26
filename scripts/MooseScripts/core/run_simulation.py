#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
仿真运行器
--------
运行MOOSE仿真并监控进度

主要功能：
1. 发现仿真案例
2. 运行MOOSE模拟
3. 监控运行状态
4. 从检查点恢复
"""

import os
import sys
import glob
import argparse
import json
import time
import re
from datetime import datetime

# 导入自定义模块
from MooseScripts.core.path_manager import (
    create_path_config, ensure_path_exists, find_files_by_pattern
)
from MooseScripts.core.file_manager import (
    read_file, write_file, check_convergence, find_latest_checkpoint
)
from MooseScripts.core.command_executor import (
    run_moose_command, run_in_conda_env
)
from MooseScripts.utils.output_utils import (
    print_header, print_config, print_summary, print_progress, print_case_info
)

def parse_args():
    """解析命令行参数"""
    parser = argparse.ArgumentParser(description="MOOSE仿真运行器")
    
    # 路径配置
    parser.add_argument('--base-dir', default=None, 
                        help='基础目录路径，默认为当前脚本所在目录的父目录')
    parser.add_argument('--output-dir', default=None,
                        help='输出目录路径，默认为base-dir/parameter_studies')
    
    # MOOSE配置
    parser.add_argument('--moose-app', default=None,
                        help='MOOSE可执行文件路径，默认使用环境变量中的值')
    parser.add_argument('--mpi-processes', type=int, default=12,
                        help='MPI进程数')
    parser.add_argument('--timeout', type=int, default=3600,
                        help='单个案例超时时间（秒）')
    parser.add_argument('--conda-env', default='moose',
                        help='MOOSE环境名称')
    
    # 运行控制
    parser.add_argument('--resume', action='store_true',
                        help='从上次中断处恢复运行')
    parser.add_argument('--skip-completed', action='store_true',
                        help='跳过已经完成的案例')
    parser.add_argument('--max-cases', type=int, default=None,
                        help='最多运行的案例数量')
    parser.add_argument('--case-pattern', default=None,
                        help='案例名称匹配模式，用于只运行特定案例')
    
    return parser.parse_args()

def check_environment(moose_app, conda_env):
    """
    检查MOOSE环境和应用程序
    
    Args:
        moose_app: MOOSE可执行文件路径
        conda_env: MOOSE环境名称
        
    Returns:
        bool: 环境是否有效
    """
    print("检查MOOSE环境...")
    
    # 检查可执行文件是否存在
    if not os.path.exists(moose_app):
        print(f"❌ MOOSE可执行文件不存在: {moose_app}")
        return False
    
    # 检查是否有执行权限
    if not os.access(moose_app, os.X_OK):
        print(f"❌ MOOSE可执行文件无执行权限: {moose_app}")
        return False
    
    # 检查conda环境
    cmd = ['conda', 'info', '--envs']
    success, _, output = run_in_conda_env(None, cmd)
    
    if not success:
        print("❌ 无法获取conda环境列表")
        return False
    
    # 检查是否有moose环境
    if conda_env not in output:
        print(f"❌ 找不到conda环境: {conda_env}")
        return False
    
    print(f"✅ MOOSE环境检查通过: {conda_env}")
    return True

def find_input_files(output_dir, main_pattern="*.i", sub_pattern="*_sub_*.i"):
    """
    查找所有输入文件
    
    Args:
        output_dir: 输出目录
        main_pattern: 主输入文件匹配模式
        sub_pattern: 子输入文件匹配模式
        
    Returns:
        list: 找到的案例路径列表，每个元素为(案例目录, 输入文件, 是否为多程序模式, 标题)
    """
    result = []
    
    # 遍历所有子目录
    for item in os.listdir(output_dir):
        case_dir = os.path.join(output_dir, item)
        if not os.path.isdir(case_dir):
            continue
        
        # 查找主输入文件
        main_files = glob.glob(os.path.join(case_dir, main_pattern))
        if not main_files:
            continue
        
        # 找到第一个i文件作为主文件
        main_file = main_files[0]
        
        # 检查是否有子文件，判断是否为多程序模式
        sub_files = glob.glob(os.path.join(case_dir, sub_pattern))
        is_multiapp = len(sub_files) > 0
        
        # 读取输入文件中的注释获取参数组合信息
        title = extract_case_title(main_file)
        
        result.append((case_dir, main_file, is_multiapp, title))
    
    # 对结果进行排序（按照案例编号）
    result.sort(key=lambda x: get_case_number(x[0]))
    
    return result

def get_case_number(file_path):
    """
    从路径中提取case编号
    
    Args:
        file_path: 案例路径
        
    Returns:
        int: 案例编号
    """
    basename = os.path.basename(file_path)
    match = re.search(r'.*?(\d+)', basename)
    if match:
        return int(match.group(1))
    return 0

def extract_case_title(input_file):
    """
    从输入文件提取案例标题
    
    Args:
        input_file: 输入文件路径
        
    Returns:
        str: 案例标题
    """
    try:
        with open(input_file, 'r', encoding='utf-8') as f:
            lines = f.readlines()[:10]  # 只读取前10行
            
            params = {}
            for line in lines:
                if line.startswith('#') and ':' in line:
                    parts = line.strip('# \n').split(':', 1)
                    if len(parts) == 2:
                        params[parts[0].strip()] = parts[1].strip()
            
            if params:
                return ", ".join([f"{k}={v}" for k, v in params.items()])
    except Exception:
        pass
    
    return os.path.basename(input_file)

def save_progress(output_dir, progress_file, completed_cases):
    """
    保存进度到文件
    
    Args:
        output_dir: 输出目录
        progress_file: 进度文件名
        completed_cases: 已完成案例列表
    """
    progress_path = os.path.join(output_dir, progress_file)
    try:
        with open(progress_path, 'w') as f:
            json.dump(completed_cases, f)
    except Exception as e:
        print(f"❌ 保存进度失败: {e}")

def load_progress(output_dir, progress_file):
    """
    从文件加载进度
    
    Args:
        output_dir: 输出目录
        progress_file: 进度文件名
        
    Returns:
        list: 已完成案例列表
    """
    progress_path = os.path.join(output_dir, progress_file)
    if os.path.exists(progress_path):
        try:
            with open(progress_path, 'r') as f:
                return json.load(f)
        except Exception as e:
            print(f"⚠️ 加载进度失败: {e}")
    return []

def run_case(input_path, moose_app, mpi_processes, log_file, sub_pattern, is_first_case=False):
    """
    运行单个案例
    
    Args:
        input_path: 输入文件路径
        moose_app: MOOSE可执行文件路径
        mpi_processes: MPI进程数
        log_file: 日志文件路径
        sub_pattern: 子文件匹配模式
        is_first_case: 是否为第一个案例
        
    Returns:
        bool: 是否成功运行
    """
    case_dir = os.path.dirname(input_path)
    
    # 检查是否有检查点文件
    checkpoint = find_latest_checkpoint(case_dir)
    from_checkpoint = checkpoint is not None
    
    # 构建命令参数
    args = []
    
    # 如果有检查点并且不是第一个案例（避免首次运行时尝试恢复）
    if from_checkpoint and not is_first_case:
        cp_basename = os.path.basename(checkpoint)
        args.extend(['--recover', cp_basename])
    
    # 添加输入文件
    args.append('-i')
    args.append(os.path.basename(input_path))
    
    # 运行命令
    success, return_code, output = run_moose_command(
        moose_app, args, 
        mpi_processes=mpi_processes,
        cwd=case_dir,
        log_file=log_file
    )
    
    # 检查子应用程序是否需要单独运行
    if success and not from_checkpoint:
        sub_files = glob.glob(os.path.join(case_dir, sub_pattern))
        if sub_files:
            print("  运行子应用程序...")
            for sub_file in sub_files:
                sub_args = ['-i', os.path.basename(sub_file)]
                sub_success, sub_return_code, sub_output = run_moose_command(
                    moose_app, sub_args,
                    mpi_processes=mpi_processes,
                    cwd=case_dir,
                    log_file=log_file
                )
                if not sub_success:
                    print(f"  ❌ 子应用程序运行失败: {os.path.basename(sub_file)}")
                    success = False
    
    # 检查运行结果
    if success:
        # 读取日志内容，检查是否收敛
        if os.path.exists(log_file):
            with open(log_file, 'r', encoding='utf-8', errors='ignore') as f:
                log_content = f.read()
            
            converged, reason = check_convergence(log_content)
            if not converged:
                print(f"  ⚠️ 仿真未收敛，原因: {reason}")
                success = False
    
    return success

def run_simulation(args):
    """
    运行所有仿真案例
    
    Args:
        args: 命令行参数
        
    Returns:
        tuple: (成功案例数, 失败案例数, 跳过案例数)
    """
    # 创建路径配置
    path_config = create_path_config(args)
    output_dir = path_config['output_dir']
    moose_app = path_config['moose_app']
    
    # 确保输出目录存在
    if not os.path.exists(output_dir):
        print(f"❌ 输出目录不存在: {output_dir}")
        return 0, 0, 0
    
    # 检查环境
    if not check_environment(moose_app, args.conda_env):
        print("❌ 环境检查未通过，无法继续")
        return 0, 0, 0
    
    # 查找输入文件
    cases = find_input_files(output_dir)
    if not cases:
        print(f"❌ 未找到有效的仿真输入文件: {output_dir}")
        return 0, 0, 0
    
    # 过滤案例（如果有匹配模式）
    if args.case_pattern:
        pattern = re.compile(args.case_pattern)
        cases = [case for case in cases if pattern.search(os.path.basename(case[0]))]
        if not cases:
            print(f"❌ 没有匹配模式的案例: {args.case_pattern}")
            return 0, 0, 0
    
    # 限制案例数量
    if args.max_cases and len(cases) > args.max_cases:
        cases = cases[:args.max_cases]
    
    # 加载进度
    completed_cases = []
    if args.resume or args.skip_completed:
        completed_cases = load_progress(output_dir, "progress.json")
        print(f"已完成案例数: {len(completed_cases)}")
    
    # 统计计数
    total_cases = len(cases)
    success_count = 0
    failed_count = 0
    skipped_count = 0
    
    # 打印配置信息
    config = {
        'output_dir': output_dir,
        'moose_app': moose_app,
        'mpi_processes': args.mpi_processes,
        'timeout': args.timeout,
        'conda_env': args.conda_env,
        'total_cases': total_cases,
    }
    print_config(config, "仿真运行配置")
    
    # 运行所有案例
    start_time = time.time()
    
    for i, (case_dir, input_file, is_multiapp, title) in enumerate(cases, 1):
        case_name = os.path.basename(case_dir)
        
        # 检查是否已完成
        if case_name in completed_cases and args.skip_completed:
            print(f"跳过已完成案例 ({i}/{total_cases}): {case_name}")
            skipped_count += 1
            continue
        
        # 打印案例信息
        print_case_info(i, total_cases, case_name, title)
        
        # 创建日志文件
        log_file = os.path.join(case_dir, "run.log")
        
        # 运行案例
        success = run_case(
            input_file, moose_app, args.mpi_processes, 
            log_file, "*_sub_*.i", is_first_case=(i==1)
        )
        
        # 记录结果
        if success:
            print(f"✅ 案例运行成功: {case_name}")
            success_count += 1
            if case_name not in completed_cases:
                completed_cases.append(case_name)
                save_progress(output_dir, "progress.json", completed_cases)
        else:
            print(f"❌ 案例运行失败: {case_name}")
            failed_count += 1
        
        # 更新进度
        print_progress(i, total_cases, prefix='总进度:', suffix=f'({i}/{total_cases})', length=40)
    
    # 计算总耗时
    elapsed_time = time.time() - start_time
    
    # 打印总结
    print_summary(success_count, failed_count, skipped_count, elapsed_time)
    
    return success_count, failed_count, skipped_count

def main():
    """主函数"""
    start_time = time.time()
    args = parse_args()
    
    # 运行仿真
    success_count, failed_count, skipped_count = run_simulation(args)
    
    # 计算总运行时间
    elapsed_time = time.time() - start_time
    hours = int(elapsed_time // 3600)
    minutes = int((elapsed_time % 3600) // 60)
    seconds = int(elapsed_time % 60)
    
    print(f"\n===== 仿真运行器已完成 =====")
    print(f"总共案例: {success_count + failed_count + skipped_count}")
    print(f"成功案例: {success_count}")
    print(f"失败案例: {failed_count}")
    print(f"跳过案例: {skipped_count}")
    print(f"总运行时间: {hours}小时 {minutes}分钟 {seconds}秒")
    print(f"当前时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")

if __name__ == "__main__":
    main() 