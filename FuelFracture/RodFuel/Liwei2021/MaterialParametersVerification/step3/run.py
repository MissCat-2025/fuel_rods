import os
import glob
import subprocess
import time
from datetime import datetime

# 基础配置
base_dir = '/home/yp/projects/raccoon/FuelFracture/RodFuel/Liwei2021/MaterialParametersVerification/step3/MultiApp'
output_dir = os.path.join(base_dir, 'parameter_studies')
moose_app = "/home/yp/projects/raccoon/raccoon-opt"
mpi_processes = 12  # MPI进程数
timeout = 3600      # 单个案例超时时间（秒）

def find_main_files():
    """查找所有主程序文件"""
    pattern = os.path.join(output_dir, "case_*/main_*.i")
    return sorted(glob.glob(pattern))

def run_case(main_path):
    """执行单个案例"""
    case_dir = os.path.dirname(main_path)
    input_name = os.path.basename(main_path)
    
    # 预检查（保持原有）
    print(f"\n🔍 预检查案例目录: {case_dir}")
    print(f"   输入文件存在: {os.path.exists(os.path.join(case_dir, input_name))}")
    print(f"   子程序存在: {os.path.exists(os.path.join(case_dir, 'sub_*.i'))}")
    print(f"   MOOSE可执行文件权限: {oct(os.stat(moose_app).st_mode)[-3:]}")

    cmd = [
        "mpirun", "-n", str(mpi_processes),
        moose_app,
        "-i", input_name,
        "--n-threads=1"
    ]
    
    log_path = os.path.join(case_dir, "run.log")
    print(f"\n▶ 开始执行案例: {os.path.relpath(main_path, base_dir)}")
    
    try:
        with open(log_path, 'w') as log_file:
            # 初始化日志头
            log_file.write(f"=== 执行日志 {datetime.now().isoformat()} ===\n")
            log_file.write(f"命令: {' '.join(cmd)}\n")
            log_file.write(f"工作目录: {case_dir}\n\n")
            log_file.flush()

            start_time = time.time()
            process = subprocess.Popen(
                cmd,
                cwd=case_dir,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,  # 合并输出流
                text=True,
                bufsize=1,
                universal_newlines=True
            )

            # 实时处理输出
            while True:
                output = process.stdout.readline()
                if output:
                    # 同时输出到控制台和日志
                    print(f"[{datetime.now().strftime('%H:%M:%S')}] {output.strip()}")
                    log_file.write(f"[{datetime.now().isoformat()}] {output}")
                    log_file.flush()
                
                if process.poll() is not None and output == '':
                    break

            # 记录结束状态
            elapsed = time.time() - start_time
            log_file.write(f"\n=== 运行结束 ===\n")
            log_file.write(f"返回码: {process.returncode}\n")
            log_file.write(f"耗时: {elapsed:.1f}s\n")
            
            return {
                'status': 'success' if process.returncode == 0 else 'failed',
                'time': round(elapsed, 1),
                'log': log_path
            }
            
    except Exception as e:
        error_msg = f"严重错误: {str(e)}"
        print(error_msg)
        return {
            'status': 'error',
            'error': error_msg,
            'log': log_path
        }

def main():
    cases = find_main_files()
    if not cases:
        print("未找到可执行案例！")
        return
    
    print(f"找到 {len(cases)} 个待执行案例")
    
    results = []
    for idx, case in enumerate(cases, 1):
        print(f"\n=== 进度 [{idx}/{len(cases)}] ===")
        result = run_case(case)
        results.append(result)
        
        if result['status'] == 'success':
            print(f"✔ 成功完成！耗时 {result['time']} 秒")
        else:
            print(f"✖ 执行失败！日志路径: {result['log']}")
    
    # 生成汇总报告
    success_count = sum(1 for r in results if r['status'] == 'success')
    print(f"\n执行完成：成功 {success_count}/{len(cases)} 个案例")
    print(f"详细日志请查看各案例目录下的 run.log 文件")

if __name__ == '__main__':
    main()