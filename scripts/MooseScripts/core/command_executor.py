#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
命令执行模块
-----------
集中处理所有命令执行、输出捕获和错误处理

主要功能：
1. 执行命令并处理输出
2. 超时控制和中断处理
3. 日志记录
4. 环境变量管理
"""

import os
import subprocess
import time
import sys
import signal
from datetime import datetime

def run_command(cmd, cwd=None, shell=False, timeout=None, env=None, log_file=None):
    """
    运行命令并实时输出
    
    Args:
        cmd: 命令（字符串或列表）
        cwd: 工作目录
        shell: 是否使用shell执行
        timeout: 超时时间（秒）
        env: 环境变量字典
        log_file: 日志文件路径
        
    Returns:
        tuple: (成功标志, 返回码, 输出文本)
    """
    cmd_str = ' '.join(cmd) if isinstance(cmd, list) else cmd
    print(f"\n执行命令: {cmd_str}")
    
    start_time = time.time()
    output_text = []
    
    # 准备环境变量
    current_env = os.environ.copy()
    if env:
        current_env.update(env)
    
    # 准备日志文件
    log_handle = None
    if log_file:
        log_dir = os.path.dirname(log_file)
        if log_dir and not os.path.exists(log_dir):
            os.makedirs(log_dir, exist_ok=True)
        log_handle = open(log_file, 'w', encoding='utf-8')
        
        # 写入命令和时间信息
        log_handle.write(f"命令: {cmd_str}\n")
        log_handle.write(f"开始时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        log_handle.write("-" * 50 + "\n")
        log_handle.flush()
    
    try:
        process = subprocess.Popen(
            cmd,
            cwd=cwd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            shell=shell,
            universal_newlines=True,
            bufsize=1,
            env=current_env
        )
        
        # 处理超时
        elapsed = 0
        while process.poll() is None:
            # 读取输出
            for line in iter(process.stdout.readline, ''):
                line = line.rstrip()
                print(line)
                output_text.append(line)
                
                if log_handle:
                    log_handle.write(line + '\n')
                    log_handle.flush()
            
            # 检查超时
            if timeout and elapsed > timeout:
                print(f"命令执行超时（{timeout}秒）")
                if log_handle:
                    log_handle.write(f"\n命令执行超时（{timeout}秒）\n")
                
                # 终止进程
                process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                
                if log_handle:
                    log_handle.write(f"返回码: -1 (超时终止)\n")
                    log_handle.write(f"结束时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
                    log_handle.close()
                
                return False, -1, "\n".join(output_text)
            
            # 增加等待时间
            time.sleep(0.1)
            elapsed += 0.1
        
        # 进程已结束，捕获剩余输出
        for line in iter(process.stdout.readline, ''):
            line = line.rstrip()
            print(line)
            output_text.append(line)
            
            if log_handle:
                log_handle.write(line + '\n')
                log_handle.flush()
        
        # 记录返回码
        rc = process.returncode
        success = (rc == 0)
        
        if log_handle:
            log_handle.write(f"\n返回码: {rc}\n")
            log_handle.write(f"结束时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
            log_handle.write(f"总耗时: {time.time() - start_time:.2f}秒\n")
            log_handle.close()
        
        print(f"命令完成，返回码: {rc}")
        return success, rc, "\n".join(output_text)
    
    except Exception as e:
        error_msg = f"命令执行出错: {str(e)}"
        print(error_msg)
        output_text.append(error_msg)
        
        if log_handle:
            log_handle.write(f"\n{error_msg}\n")
            log_handle.write(f"结束时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
            log_handle.close()
        
        return False, -2, "\n".join(output_text)

def run_in_conda_env(env_name, cmd, cwd=None, timeout=None, log_file=None):
    """
    在指定的conda环境中运行命令
    
    Args:
        env_name: conda环境名称
        cmd: 要执行的命令（字符串或列表）
        cwd: 工作目录
        timeout: 超时时间（秒）
        log_file: 日志文件路径
        
    Returns:
        tuple: (成功标志, 返回码, 输出文本)
    """
    # 将命令转换为字符串，如果是列表
    if isinstance(cmd, list):
        cmd_str = ' '.join(cmd)
    else:
        cmd_str = cmd
    
    # 构建在conda环境中运行的命令
    conda_cmd = f"source $(conda info --base)/etc/profile.d/conda.sh && conda activate {env_name} && {cmd_str}"
    
    return run_command(conda_cmd, cwd=cwd, shell=True, timeout=timeout, log_file=log_file)

def run_moose_command(moose_app, args, mpi_processes=1, cwd=None, timeout=None, log_file=None):
    """
    运行MOOSE命令
    
    Args:
        moose_app: MOOSE应用程序路径
        args: 命令行参数（列表或字符串）
        mpi_processes: MPI进程数
        cwd: 工作目录
        timeout: 超时时间（秒）
        log_file: 日志文件路径
        
    Returns:
        tuple: (成功标志, 返回码, 输出文本)
    """
    # 将参数转换为列表，如果是字符串
    if isinstance(args, str):
        args = args.split()
    
    # 构建命令
    if mpi_processes > 1:
        cmd = ['mpiexec', '-n', str(mpi_processes), moose_app] + args
    else:
        cmd = [moose_app] + args
    
    return run_command(cmd, cwd=cwd, timeout=timeout, log_file=log_file)

def parallel_commands(cmd_list, max_parallel=4, timeout=None):
    """
    并行执行多个命令
    
    Args:
        cmd_list: 命令列表，每项格式为 (cmd, cwd, shell)
        max_parallel: 最大并行数
        timeout: 每个命令的超时时间（秒）
        
    Returns:
        list: 每个命令的执行结果
    """
    results = []
    active_processes = []
    
    for i, (cmd, cwd, shell) in enumerate(cmd_list):
        # 等待，如果已经达到最大并行数
        while len(active_processes) >= max_parallel:
            for j, process_info in enumerate(active_processes):
                process, start_time, cmd_idx = process_info
                
                # 检查进程是否结束
                if process.poll() is not None:
                    # 进程已结束，获取输出
                    output, _ = process.communicate()
                    rc = process.returncode
                    success = (rc == 0)
                    results.append((cmd_idx, success, rc, output))
                    # 移除已结束的进程
                    active_processes.pop(j)
                    break
                
                # 检查超时
                if timeout and (time.time() - start_time > timeout):
                    print(f"命令超时: {cmd_list[cmd_idx][0]}")
                    process.terminate()
                    try:
                        process.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        process.kill()
                    
                    results.append((cmd_idx, False, -1, "超时终止"))
                    # 移除已超时的进程
                    active_processes.pop(j)
                    break
            
            # 短暂等待，避免CPU占用过高
            time.sleep(0.1)
        
        # 启动新进程
        try:
            process = subprocess.Popen(
                cmd,
                cwd=cwd,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                shell=shell,
                universal_newlines=True
            )
            active_processes.append((process, time.time(), i))
        except Exception as e:
            print(f"启动命令失败: {cmd}, 错误: {str(e)}")
            results.append((i, False, -2, str(e)))
    
    # 等待所有剩余进程完成
    for process, start_time, cmd_idx in active_processes:
        try:
            output, _ = process.communicate(timeout=timeout)
            rc = process.returncode
            success = (rc == 0)
            results.append((cmd_idx, success, rc, output))
        except subprocess.TimeoutExpired:
            print(f"命令超时: {cmd_list[cmd_idx][0]}")
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
            
            results.append((cmd_idx, False, -1, "超时终止"))
    
    # 按照原始顺序排序结果
    results.sort(key=lambda x: x[0])
    return [(success, rc, output) for _, success, rc, output in results] 