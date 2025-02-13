import os
import subprocess
import glob
import re
import time
import signal
from datetime import datetime

# 定义输入文件目录
input_dir = 'InputFiles'

# 获取所有的 .i 文件
input_files = glob.glob(os.path.join(input_dir, '*.i'))

# MOOSE可执行文件的相对路径
moose_exe = '../../../fuel_rods-opt'

# 设置时间限制（秒）
TIME_LIMIT = 600  # 10分钟

# 创建结果文件
timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
result_file = f'solver_timing_results_{timestamp}.txt'

# 创建结果文件头部
with open(result_file, 'w', encoding='utf-8') as f:
    f.write("求解器性能测试结果\n")
    f.write("=" * 50 + "\n")
    f.write(f"测试开始时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
    f.write(f"单个程序时间限制: {TIME_LIMIT} 秒\n")
    f.write("=" * 50 + "\n\n")

def kill_process_tree(pid):
    try:
        # 在Linux系统中终止进程及其子进程
        subprocess.run(['pkill', '-TERM', '-P', str(pid)], check=False)
    except:
        pass

# 运行所有输入文件
for input_file in sorted(input_files):
    print(f"\n正在运行: {os.path.basename(input_file)}")
    print("="*50)
    
    start_time = time.time()
    
    # 构建命令
    cmd = [
        'mpiexec',
        '-n',
        '7',
        moose_exe,
        '-i', input_file,
        '--n-threads=2',
        '--timing'
    ]
    
    try:
        # 运行命令并实时输出结果
        process = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            universal_newlines=True,
            preexec_fn=os.setsid
        )
        
        # 用于存储性能表格信息
        performance_table = []
        is_capturing_table = False
        
        # 实时输出结果
        while True:
            try:
                # 设置读取超时
                output = process.stdout.readline()
                if output == '' and process.poll() is not None:
                    break
                if output:
                    print(output.strip())
                    
                    # 开始捕获性能表格
                    if "Performance Graph:" in output:
                        is_capturing_table = True
                        performance_table = ["Performance Graph:"]
                    elif is_capturing_table:
                        if "Finished Executing" in output:
                            performance_table.append(output.strip())
                            is_capturing_table = False
                        else:
                            performance_table.append(output.strip())
                
                # 检查是否超时
                if time.time() - start_time > TIME_LIMIT:
                    print(f"\n⚠️ 程序运行超过 {TIME_LIMIT} 秒，强制终止")
                    kill_process_tree(process.pid)
                    raise TimeoutError(f"程序运行超过 {TIME_LIMIT} 秒")
                    
            except TimeoutError as e:
                raise e
        
        # 等待进程完成
        process.wait()
        
        end_time = time.time()
        total_time = end_time - start_time
        
        # 准备当前运行的结果
        current_result = {
            'file': os.path.basename(input_file),
            'total_time': total_time,
            'performance_table': performance_table,
            'status': 'success' if process.returncode == 0 else 'failed'
        }
        
        if process.returncode == 0:
            print(f"\n✅ {os.path.basename(input_file)} 运行成功")
        else:
            print(f"\n❌ {os.path.basename(input_file)} 运行失败")
            
    except TimeoutError as e:
        print(f"\n⚠️ {os.path.basename(input_file)} {str(e)}")
        current_result = {
            'file': os.path.basename(input_file),
            'total_time': TIME_LIMIT,
            'performance_table': [],
            'status': f'timeout: {TIME_LIMIT}秒'
        }
    except Exception as e:
        print(f"\n❌ 运行 {os.path.basename(input_file)} 时发生错误: {str(e)}")
        current_result = {
            'file': os.path.basename(input_file),
            'total_time': time.time() - start_time,
            'performance_table': [],
            'status': f'error: {str(e)}'
        }
    
    # 立即将当前结果写入文件
    with open(result_file, 'a', encoding='utf-8') as f:
        f.write(f"输入文件: {current_result['file']}\n")
        f.write(f"运行状态: {current_result['status']}\n")
        f.write(f"总运行时间: {current_result['total_time']:.2f} 秒\n\n")
        
        # 输出性能表格
        if current_result['performance_table']:
            for line in current_result['performance_table']:
                f.write(line + "\n")
            f.write("\n")
        
        f.write("-" * 50 + "\n\n")

# 记录测试结束时间
with open(result_file, 'a', encoding='utf-8') as f:
    f.write("=" * 50 + "\n")
    f.write(f"测试结束时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
    f.write("=" * 50 + "\n")

print(f"\n所有测试运行完成！结果已保存到 {result_file}") 