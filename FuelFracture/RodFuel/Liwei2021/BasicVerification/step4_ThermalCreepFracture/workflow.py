#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
RACCOON燃料断裂研究工作流脚本
-------------------------------
这个脚本整合了整个仿真分析流程，包括：
1. 网格生成和参数研究配置
2. 运行仿真
3. 分析结果
4. ParaView后处理
"""

import os
import sys
import argparse
import subprocess
import json
import glob
from datetime import datetime

# 固定路径配置
MOOSE_APP_PATH = "/home/yp/projects/raccoon/raccoon-opt"
SCRIPTS_PATH = "/home/yp/projects/fuel_rods/FuelFracture/Scripts"
SCRIPTS_PY_DIR = os.path.join(SCRIPTS_PATH, '.py')
SCRIPTS_SH_DIR = os.path.join(SCRIPTS_PATH, '.sh')

def parse_args():
    """解析命令行参数"""
    parser = argparse.ArgumentParser(description="RACCOON燃料断裂研究工作流")
    
    # 工作流步骤控制
    parser.add_argument('--steps', default='all', 
                        choices=['all', 'mesh', 'run', 'analyze', 'visualize'],
                        help='要执行的工作流步骤，默认执行所有步骤')
    
    # 基本配置
    parser.add_argument('--base-dir', default=None,
                        help='项目基础目录，默认为脚本所在目录')
    parser.add_argument('--template-main', default=None,
                        help='主模板文件路径')
    parser.add_argument('--template-sub', default=None,
                        help='子模板文件路径')
    parser.add_argument('--output-dir', default=None,
                        help='输出目录路径')
    
    # 网格生成与参数研究配置
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
    
    # 运行配置
    parser.add_argument('--moose-app', default=MOOSE_APP_PATH,
                        help='MOOSE可执行文件路径')
    parser.add_argument('--mpi-processes', type=int, default=12,
                        help='MPI进程数')
    parser.add_argument('--timeout', type=int, default=3600,
                        help='单个案例超时时间（秒）')
    parser.add_argument('--conda-env', default='moose',
                        help='MOOSE环境名称')
    
    # ParaView配置
    parser.add_argument('--paraview-env', default='paraview_post',
                        help='ParaView环境名称')
    parser.add_argument('--force-rebuild-env', action='store_true',
                        help='强制重建ParaView环境')
    parser.add_argument('--target-times', default='4.0 5.0 6.0',
                        help='可视化的目标时间点，空格分隔')
    
    return parser.parse_args()

def ensure_path(path):
    """确保目录存在"""
    if path and not os.path.exists(path):
        os.makedirs(path, exist_ok=True)
    return path

def run_command(cmd, cwd=None, shell=False):
    """运行命令并实时输出"""
    print(f"\n执行命令: {' '.join(cmd) if isinstance(cmd, list) else cmd}")
    try:
        process = subprocess.Popen(
            cmd,
            cwd=cwd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            shell=shell,
            universal_newlines=True,
            bufsize=1
        )
        
        # 实时输出
        for line in iter(process.stdout.readline, ''):
            print(line.rstrip())
        
        # 等待进程结束
        process.wait()
        
        if process.returncode != 0:
            print(f"命令执行失败，返回码: {process.returncode}")
            return False
        return True
    except Exception as e:
        print(f"命令执行出错: {str(e)}")
        return False

def find_template_files(directory):
    """在指定目录中查找模板文件
    
    返回: (main_template, sub_template) 元组。如果没有找到相应文件，对应值为None。
    """
    # 查找所有.i文件
    i_files = glob.glob(os.path.join(directory, '*.i'))
    
    if not i_files:
        return None, None
    
    # 查找包含"_Sub"的文件作为子模板
    sub_templates = [f for f in i_files if '_Sub' in os.path.basename(f)]
    main_templates = [f for f in i_files if '_Sub' not in os.path.basename(f)]
    
    # 返回找到的模板文件
    main_template = main_templates[0] if main_templates else None
    sub_template = sub_templates[0] if sub_templates else None
    
    return main_template, sub_template

def check_scripts_path():
    """检查脚本路径是否存在，不存在则尝试创建软链接"""
    if not os.path.exists(SCRIPTS_PATH):
        print(f"警告: 脚本路径 {SCRIPTS_PATH} 不存在")
        return False
    
    if not os.path.exists(SCRIPTS_PY_DIR) or not os.path.exists(SCRIPTS_SH_DIR):
        print(f"警告: 脚本子目录不存在: {SCRIPTS_PY_DIR} 或 {SCRIPTS_SH_DIR}")
        return False
    
    return True

def get_script_directory():
    """获取当前脚本所在目录的绝对路径"""
    return os.path.dirname(os.path.abspath(__file__))

def main():
    """主函数"""
    args = parse_args()
    
    # 检查脚本路径
    if not check_scripts_path():
        print("错误: 无法找到必要的脚本目录。请确保以下路径存在:")
        print(f"- 脚本目录: {SCRIPTS_PATH}")
        print(f"- Python脚本目录: {SCRIPTS_PY_DIR}")
        print(f"- Shell脚本目录: {SCRIPTS_SH_DIR}")
        return
    
    # 获取脚本所在目录作为基础目录，而不是当前工作目录
    script_dir = get_script_directory()
    
    # 设置基础目录
    if args.base_dir is None:
        # 使用脚本所在目录而不是当前工作目录
        base_dir = script_dir
    else:
        # 如果提供了相对路径，也是相对于脚本所在目录解析
        if not os.path.isabs(args.base_dir):
            base_dir = os.path.abspath(os.path.join(script_dir, args.base_dir))
        else:
            base_dir = os.path.abspath(args.base_dir)
    
    # 准备输出目录 - 与workflow.py脚本所在目录绑定
    if args.output_dir is None:
        output_dir = os.path.join(base_dir, 'parameter_studies')
    else:
        # 如果提供了相对路径，相对于脚本所在目录解析
        if not os.path.isabs(args.output_dir):
            output_dir = os.path.join(base_dir, args.output_dir)
        else:
            output_dir = args.output_dir
    
    # 确保输出目录存在
    ensure_path(output_dir)
    
    # 自动查找模板文件，如果未通过命令行参数指定
    template_main = args.template_main
    template_sub = args.template_sub
    
    if template_main is None or template_sub is None:
        auto_main, auto_sub = find_template_files(base_dir)
        
        if template_main is None:
            if auto_main:
                template_main = auto_main
                print(f"自动检测到主模板文件: {os.path.basename(template_main)}")
            else:
                print("未找到主模板文件，请输入主模板文件路径:")
                user_input = input("> ")
                if user_input and os.path.exists(user_input):
                    template_main = os.path.abspath(user_input)
                else:
                    print("无效的文件路径，脚本将退出")
                    return
        
        if template_sub is None:
            if auto_sub:
                template_sub = auto_sub
                print(f"自动检测到子模板文件: {os.path.basename(template_sub)}")
            else:
                # 如果没有子模板，使用主模板作为子模板
                template_sub = template_main
                print("未找到子模板文件，将使用主模板作为子模板")
    
    # 解析JSON参数
    try:
        parameter_matrix = json.loads(args.parameter_matrix)
        exclude_combinations = json.loads(args.exclude_combinations)
    except json.JSONDecodeError as e:
        print(f"错误：无法解析JSON参数：{e}")
        return
    
    # 打印配置信息
    print("===== 工作流配置 =====")
    print(f"脚本所在目录: {script_dir}")
    print(f"基础目录: {base_dir}")
    print(f"脚本目录: {SCRIPTS_PATH}")
    print(f"输出目录: {output_dir}")
    print(f"主模板文件: {template_main}")
    print(f"子模板文件: {template_sub}")
    print(f"MOOSE可执行文件: {MOOSE_APP_PATH}")
    print(f"参数矩阵: {json.dumps(parameter_matrix, indent=2)}")
    print(f"排除组合: {json.dumps(exclude_combinations, indent=2)}")
    print("=====================")
    
    # 步骤1: 网格生成和参数研究配置
    if args.steps in ['all', 'mesh']:
        print("\n===== 步骤1: 网格生成和参数研究配置 =====")
        mesh_cmd = [
            'python', 
            os.path.join(SCRIPTS_PY_DIR, 'mesh_generator.py'),
            '--base-dir', base_dir,
            '--template-main', template_main,
            '--template-sub', template_sub,
            '--output-dir', output_dir,
            '--checkpoint-interval', str(args.checkpoint_interval),
            '--checkpoint-files', str(args.checkpoint_files),
            '--checkpoint-time', str(args.checkpoint_time),
            '--parameter-matrix', args.parameter_matrix,
            '--exclude-combinations', args.exclude_combinations
        ]
        
        if not run_command(mesh_cmd):
            print("网格生成失败，停止工作流")
            return
    
    # 步骤2: 运行仿真
    if args.steps in ['all', 'run']:
        print("\n===== 步骤2: 运行仿真 =====")
        run_cmd = [
            'python', 
            os.path.join(SCRIPTS_PY_DIR, 'run_simulation.py'),
            '--base-dir', base_dir,
            '--output-dir', output_dir,
            '--moose-app', MOOSE_APP_PATH,
            '--mpi-processes', str(args.mpi_processes),
            '--timeout', str(args.timeout),
            '--conda-env', args.conda_env
        ]
        
        if not run_command(run_cmd):
            print("仿真运行失败，但继续执行下一步")
    
    # 步骤3: 分析结果
    if args.steps in ['all', 'analyze']:
        print("\n===== 步骤3: 分析结果 =====")
        analyze_cmd = [
            'python', 
            os.path.join(SCRIPTS_PY_DIR, 'analyze_results.py'),
            '--base-dir', base_dir,
            '--studies-dir', output_dir
        ]
        
        if not run_command(analyze_cmd):
            print("结果分析失败，但继续执行下一步")
    
    # 步骤4: ParaView后处理
    if args.steps in ['all', 'visualize']:
        print("\n===== 步骤4: ParaView后处理 =====")
        # 构建命令行参数
        paraview_cmd = [
            'bash',
            os.path.join(SCRIPTS_SH_DIR, 'setup_paraview.sh')
        ]
        
        # 添加参数
        if args.force_rebuild_env:
            paraview_cmd.append('--force')
        
        paraview_cmd.extend([
            '--env-name', args.paraview_env,
            '--studies-dir', output_dir,
            '--base-dir', base_dir,
            '--target-times', args.target_times
        ])
        
        if not run_command(paraview_cmd):
            print("可视化后处理失败")
    
    print("\n===== 工作流已完成 =====")
    print(f"当前时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"结果目录: {output_dir}")
    if args.steps in ['all', 'analyze']:
        print(f"报告文件: {os.path.join(output_dir, 'convergence_report.csv')}")
    if args.steps in ['all', 'visualize']:
        print(f"图像目录: {os.path.join(output_dir, '*/post_results/*_images')}")

if __name__ == "__main__":
    main() 