"""
MOOSE并行测试优化版（零依赖）
保存为run_benchmark_compat.py，直接执行：python run_benchmark_compat.py
"""

import os
import time
import subprocess

# 检查是否在moose环境
if 'CONDA_PREFIX' not in os.environ or 'moose' not in os.environ['CONDA_PREFIX']:
    raise EnvironmentError("""
    请先激活 conda moose 环境！
    执行命令：
        conda activate moose
    """)

# 动态路径配置
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))  # 获取脚本所在目录
INPUT_DIR = os.path.join(SCRIPT_DIR, 'InputFiles')       # 输入文件目录
MOOSE_EXE = os.path.normpath(os.path.join(SCRIPT_DIR, '../../fuel_rods-opt'))  # 规范路径

# 配置参数（与您原始代码风格一致）
TIME_LIMIT = 600                      # 与原始测试脚本一致
RESULT_FILE = os.path.join(SCRIPT_DIR, 'benchmark_results.txt')  # 结果文件输出到脚本目录

# 新增线程配置参数
PROCS_CONFIG = [5,6,7,8,9,10] #测试不同核数
THREADS_CONFIG = [1, 2]  # 测试不同的线程数设置

def run_test(input_file, procs, threads):
    """增加线程参数"""
    cmd = [
        'mpiexec', '-n', str(procs),
        MOOSE_EXE, '-i', input_file,
        f'--n-threads={threads}',  # 动态配置线程数
        '--timing'
    ]
    
    start = time.time()
    try:
        process = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            universal_newlines=True
        )
        
        # 原始性能数据捕获逻辑
        performance = []
        capture = False
        
        while True:
            line = process.stdout.readline()
            if not line and process.poll() is not None:
                break
                
            print(line.strip())  # 保持实时输出
            
            if "Performance Graph:" in line:
                capture = True
                performance = ["Performance Graph:"]
            elif capture:
                if "Finished Executing" in line:
                    performance.append(line.strip())
                    capture = False
                else:
                    performance.append(line.strip())
                    
            # 保持原始超时处理
            if time.time() - start > TIME_LIMIT:
                process.terminate()
                return TIME_LIMIT, []
                
        return time.time()-start, performance
        
    except Exception as e:
        print(f"运行错误: {str(e)}")
        return 0, []

def main():
    # 获取输入文件列表（使用绝对路径）
    input_files = [os.path.join(INPUT_DIR, f) for f in os.listdir(INPUT_DIR) if f.endswith('.i')]
    
    # 创建结果文件（保持原始格式）
    with open(RESULT_FILE, 'w') as f:
        f.write("核心数,线程数,输入文件,总时间(s),状态\n")  # 修改表头
        
        for procs in PROCS_CONFIG:
            for threads in THREADS_CONFIG:  # 新增线程循环
                for input_file in input_files:
                    print(f"\n测试 {os.path.basename(input_file)} (进程: {procs}, 线程: {threads})...")
                    elapsed, perf_data = run_test(input_file, procs, threads)
                    status = "成功" if elapsed < TIME_LIMIT else "超时"
                    
                    # 保持原始结果写入方式
                    f.write(f"{procs}, {threads}, {os.path.basename(input_file)}, {elapsed:.1f}, {status}\n")
                    if perf_data:
                        f.write("\n".join(perf_data) + "\n")
                    f.flush()  # 实时写入

if __name__ == "__main__":
    # 添加路径验证
    if not os.path.exists(INPUT_DIR):
        raise FileNotFoundError(f"输入文件目录不存在: {INPUT_DIR}")
    
    if not os.path.isfile(MOOSE_EXE):
        raise FileNotFoundError(f"MOOSE可执行文件不存在: {MOOSE_EXE}")
    
    start = time.time()
    main()
    print(f"\n总耗时: {time.time()-start:.1f}秒")