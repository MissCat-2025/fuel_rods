import os
import subprocess
import glob
import time
import csv
import json
from datetime import datetime
import re

# 基础配置
base_dir = "/home/yp/projects/raccoon/FuelFracture/Annular/Liwei2022/MeshVerification/step4_ThermalCreepFracture/MultiApp"
moose_app = "/home/yp/projects/raccoon/raccoon-opt"  # MOOSE可执行文件路径
mpi_processes = 12  # 根据集群配置调整
timeout = 3600  # 单个任务超时时间（秒）

def find_case_files():
    """自动发现所有网格研究案例"""
    pattern = os.path.join(
        base_dir,
        "mesh_independence_study/case_*/main_rad*_azi*_grid*.i"
    )
    return sorted(glob.glob(pattern))

def capture_process_output(process, case_dir):
    """实时捕获输出并写入日志文件"""
    log_path = os.path.join(case_dir, "run_output.log")
    output_buffer = []
    
    with open(log_path, 'w') as log_file:
        while True:
            output = process.stdout.readline()
            if output == '' and process.poll() is not None:
                break
            if output:
                # 实时显示并记录
                cleaned = output.strip()
                print(cleaned)
                log_file.write(f"{datetime.now().isoformat()} | {cleaned}\n")
                log_file.flush()  # 确保立即写入
                output_buffer.append(cleaned)
                
    return "\n".join(output_buffer)

def save_run_metadata(case_dir, metadata):
    """保存元数据并关联日志文件"""
    metadata["log_file"] = "run_output.log"  # 固定日志文件名
    json_path = os.path.join(case_dir, "run_metadata.json")
    
    # 保留现有元数据
    existing_data = {}
    if os.path.exists(json_path):
        with open(json_path, 'r') as f:
            existing_data = json.load(f)
    
    # 合并数据
    existing_data.update(metadata)
    
    with open(json_path, 'w') as f:
        json.dump(existing_data, f, indent=2)

def execute_case(input_path, case_data):
    """执行单个案例并保存完整日志"""
    case_dir = os.path.dirname(input_path)
    input_name = os.path.basename(input_path)
    
    # 使用正则表达式提取参数（更健壮的方式）
    pattern = r'rad(\d+)_azi(\d+)_grid([\d\.e-]+)\.i'
    match = re.search(pattern, input_name)
    if not match:
        raise ValueError(f"文件名格式错误: {input_name}，应匹配模式'main_radXX_aziXX_gridX.XXe-XX.i'")
    
    try:
        n_rad = int(match.group(1))
        n_azi = int(match.group(2))
        grid_size = float(match.group(3).replace('e-', 'e-'))  # 保持科学计数法
    except ValueError as e:
        raise ValueError(f"参数提取错误: {input_name} - {str(e)}")

    total_elements = n_rad * n_azi
    
    cmd = [
        "mpirun", "-n", str(mpi_processes),
        moose_app,
        "-i", input_name,
        "--n-threads=1"
    ]
    
    print(f"\n▶ 开始案例：{os.path.relpath(input_path, base_dir)}")
    print(f"  网格参数：径向 {n_rad}，周向 {n_azi}，总数 {total_elements:,}")
    
    # 准备元数据
    metadata = {
        "case_name": input_name,
        "command": " ".join(cmd),
        "start_time": datetime.now().isoformat(),
        "parameters": {
            "n_radial": n_rad,
            "n_azimuthal": n_azi,
            "grid_size": grid_size,
            "total_elements": total_elements
        },
        "output": ""
    }
    
    start_time = time.time()
    try:
        process = subprocess.Popen(
            cmd,
            cwd=case_dir,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1,
            universal_newlines=True
        )
        
        # 实时捕获输出
        full_output = capture_process_output(process, case_dir)
        return_code = process.poll()
        
        elapsed = time.time() - start_time
        metadata.update({
            "end_time": datetime.now().isoformat(),
            "duration_sec": round(elapsed, 1),
            "exit_code": return_code,
            "status": "success" if return_code == 0 else "failed",
            "output": full_output
        })
        
        if return_code == 0:
            print(f"✔ 成功完成！耗时 {elapsed:.1f} 秒")
            case_data.append({
                'case': input_name,
                'status': 'success',
                'time_sec': elapsed
            })
        else:
            print(f"✖ 运行失败！退出码 {return_code}")
            case_data.append({
                'case': input_name,
                'status': 'failed',
                'time_sec': elapsed
            })
        
        return return_code == 0
        
    except Exception as e:
        elapsed = time.time() - start_time
        print(f"⚡ 发生异常：{str(e)}")
        metadata.update({
            "end_time": datetime.now().isoformat(),
            "duration_sec": round(elapsed, 1),
            "exit_code": -1,
            "status": "error",
            "error": str(e)
        })
        case_data.append({
            'case': input_name,
            'status': 'error',
            'time_sec': elapsed
        })
        return False
    finally:
        # 始终保存元数据
        save_run_metadata(case_dir, metadata)

def main():
    cases = find_case_files()
    print(f"找到 {len(cases)} 个待执行案例")
    
    success_count = 0
    case_data = []
    for idx, case in enumerate(cases, 1):
        print(f"\n=== 进度 [{idx}/{len(cases)}] ===")
        if execute_case(case, case_data):
            success_count += 1
        else:
            print("⚠ 检测到失败案例，停止后续执行")
            break
    
    print(f"\n执行完成：成功 {success_count}/{len(cases)} 个案例")

if __name__ == "__main__":
    main()