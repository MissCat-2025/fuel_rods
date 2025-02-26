import os
import glob
import subprocess
import time
import sys
import re
import json
import argparse
from datetime import datetime

# 定义固定路径常量
SCRIPTS_PATH = "/home/yp/projects/fuel_rods/FuelFracture/Scripts"
SCRIPTS_SH_DIR = os.path.join(SCRIPTS_PATH, ".sh")
SCRIPTS_PY_DIR = os.path.join(SCRIPTS_PATH, ".py")

def parse_args():
    """解析命令行参数"""
    parser = argparse.ArgumentParser(description="MOOSE仿真运行器")
    
    # 路径配置
    parser.add_argument('--base-dir', default=None, 
                        help='基础目录，默认为当前脚本所在目录的父目录')
    parser.add_argument('--output-dir', default=None,
                        help='参数研究输出目录')
    parser.add_argument('--moose-app', default=None,
                        help='MOOSE可执行文件路径')
    
    # 运行配置
    parser.add_argument('--mpi-processes', type=int, default=12,
                        help='MPI进程数')
    parser.add_argument('--timeout', type=int, default=3600,
                        help='单个案例超时时间（秒）')
    parser.add_argument('--conda-env', default='moose',
                        help='Conda环境名称')
    
    # 文件匹配模式
    parser.add_argument('--main-pattern', default="case_*/main_*.i",
                        help='主程序文件匹配模式')
    parser.add_argument('--single-pattern', default="case_*/[!main_]*.i",
                        help='单程序文件匹配模式')
    parser.add_argument('--sub-pattern', default="sub_*.i",
                        help='子程序文件匹配模式')
    
    # 输出配置
    parser.add_argument('--log-file', default='run.log',
                        help='运行日志文件名')
    parser.add_argument('--progress-file', default='.run_progress.json',
                        help='进度文件名')
    
    # 可视化配置
    parser.add_argument('--paraview-env', default='paraview_post',
                        help='ParaView环境名称')
    parser.add_argument('--target-times', default='4.0 5.0 6.0',
                        help='可视化的目标时间点，以空格分隔')
    parser.add_argument('--skip-visualization', action='store_true',
                        help='跳过可视化步骤')
    
    return parser.parse_args()

def activate_and_run(conda_env, script_path):
    """激活MOOSE环境并重新运行此脚本"""
    # 使用Shell脚本目录而不是脚本所在目录
    activate_script = os.path.join(SCRIPTS_SH_DIR, 'activate_moose.sh')
    
    if not os.path.exists(activate_script):
        # 确保目录存在
        os.makedirs(SCRIPTS_SH_DIR, exist_ok=True)
        
        with open(activate_script, 'w') as f:
            f.write(f'''#!/bin/bash
source $(conda info --base)/etc/profile.d/conda.sh
conda activate {conda_env}
if [ "$CONDA_DEFAULT_ENV" != "{conda_env}" ]; then
    echo "❌ MOOSE环境激活失败！"
    exit 1
fi
exec python "$@"
''')
        os.chmod(activate_script, 0o755)

    try:
        print("正在激活MOOSE环境...")
        os.execv('/bin/bash', ['/bin/bash', activate_script, script_path])
    except Exception as e:
        print(f"环境激活失败: {str(e)}")
        sys.exit(1)

def check_environment(moose_app, conda_env):
    """检查当前环境"""
    issues = []
    
    # 检查是否在MOOSE环境中
    current_env = os.environ.get('CONDA_DEFAULT_ENV', '')
    if current_env != conda_env:
        # 导入脚本自身并重新执行
        return ['need_activation']
    
    # 检查MOOSE可执行文件
    if not os.path.exists(moose_app):
        issues.append(f"⚠ MOOSE可执行文件不存在: {moose_app}")
    
    # 检查mpirun命令
    try:
        subprocess.run(['which', 'mpirun'], check=True, capture_output=True)
    except subprocess.CalledProcessError:
        issues.append("⚠ 未找到mpirun命令，请确保已安装MPI")
        issues.append("  Ubuntu/Debian: sudo apt-get install mpich")
        issues.append(f"  或在{conda_env}环境中: conda install mpich")
    
    return issues

def find_input_files(output_dir, main_pattern, single_pattern):
    """查找所有输入文件，支持单程序和多程序模式，并按case编号排序"""
    cases = []
    
    # 调试输出，显示实际的搜索路径和匹配模式
    print(f"\n搜索目录: {output_dir}")
    print(f"主程序匹配模式: {main_pattern}")
    print(f"单程序匹配模式: {single_pattern}")
    
    # 显示输出目录的内容，帮助诊断问题
    print(f"\n输出目录内容:")
    try:
        for item in os.listdir(output_dir):
            item_path = os.path.join(output_dir, item)
            if os.path.isdir(item_path):
                print(f"  目录: {item}")
                # 列出该案例目录下的所有内容（包括子目录）
                try:
                    subfiles = os.listdir(item_path)
                    i_files = [f for f in subfiles if f.endswith('.i')]
                    subfolders = [d for d in subfiles if os.path.isdir(os.path.join(item_path, d))]
                    
                    if i_files:
                        print(f"    .i文件: {', '.join(i_files)}")
                    
                    # 检查子目录中的.i文件
                    for subfolder in subfolders:
                        subfolder_path = os.path.join(item_path, subfolder)
                        sub_i_files = [f for f in os.listdir(subfolder_path) if f.endswith('.i')]
                        if sub_i_files:
                            print(f"    子目录 {subfolder} 中的.i文件: {', '.join(sub_i_files)}")
                except Exception as e:
                    print(f"    无法列出子目录内容: {str(e)}")
    except Exception as e:
        print(f"  无法列出目录内容: {str(e)}")
    
    # 方法1: 查找每个案例目录及其子目录中的所有.i文件
    print(f"\n正在搜索所有案例目录中的.i文件...")
    
    # 查找所有案例目录
    case_dirs = glob.glob(os.path.join(output_dir, "case_*"))
    print(f"找到 {len(case_dirs)} 个案例目录")
    
    for case_dir in case_dirs:
        if os.path.isdir(case_dir):
            # 1. 在案例目录直接查找.i文件
            case_i_files = glob.glob(os.path.join(case_dir, "*.i"))
            case_i_files = [f for f in case_i_files if not os.path.basename(f).startswith("sub_")]
            
            # 2. 在案例目录的子目录中查找.i文件（多一级递归）
            for item in os.listdir(case_dir):
                subitem_path = os.path.join(case_dir, item)
                if os.path.isdir(subitem_path):
                    sub_i_files = glob.glob(os.path.join(subitem_path, "*.i"))
                    sub_i_files = [f for f in sub_i_files if not os.path.basename(f).startswith("sub_")]
                    case_i_files.extend(sub_i_files)
            
            # 添加找到的.i文件到案例列表
            if case_i_files:
                # 对于同一个案例目录，只保留一个模板文件（优先保留非sub_开头的文件）
                main_file = None
                for f in case_i_files:
                    if main_file is None or not os.path.basename(f).startswith("sub_"):
                        main_file = f
                
                if main_file:
                    cases.append(main_file)
                    print(f"  案例 {os.path.basename(case_dir)}: 使用文件 {os.path.basename(main_file)}")
    
    # 如果仍然没找到文件，尝试使用原来的匹配模式
    if not cases:
        print("\n未找到案例文件，尝试使用原始匹配模式...")
        # 方法2: 使用原来的匹配模式
        main_files = glob.glob(os.path.join(output_dir, main_pattern))
        print(f"方法2 - 主程序文件: 找到 {len(main_files)} 个文件")
        
        single_files = [f for f in glob.glob(os.path.join(output_dir, single_pattern))
                       if not os.path.basename(f).startswith('sub_')]
        print(f"方法2 - 单程序文件: 找到 {len(single_files)} 个文件")
        
        cases.extend(main_files)
        cases.extend(single_files)
    
    # 如果仍然没找到文件，使用最广泛的搜索
    if not cases:
        print(f"\n仍未找到案例文件，使用最广泛的搜索...")
        # 递归搜索整个目录树
        for root, dirs, files in os.walk(output_dir):
            for file in files:
                if file.endswith('.i') and not file.startswith('sub_'):
                    file_path = os.path.join(root, file)
                    cases.append(file_path)
        print(f"最广泛搜索: 找到 {len(cases)} 个文件")
    
    # 按case编号排序
    def get_case_number(file_path):
        # 从路径中提取case编号
        match = re.search(r'case_(\d+)', file_path)
        return int(match.group(1)) if match else float('inf')
    
    sorted_cases = sorted(cases, key=get_case_number)
    
    if sorted_cases:
        print(f"\n已排序的案例文件:")
        for i, case in enumerate(sorted_cases[:5]):  # 只显示前5个
            print(f"  {i+1}. {case}")
        if len(sorted_cases) > 5:
            print(f"  ... 共 {len(sorted_cases)} 个文件")
    else:
        print("\n警告: 未找到任何案例文件!")
    
    return sorted_cases

def save_progress(output_dir, progress_file, completed_cases):
    """保存运行进度"""
    progress_file_path = os.path.join(output_dir, progress_file)
    try:
        os.makedirs(output_dir, exist_ok=True)
        with open(progress_file_path, 'w') as f:
            json.dump(completed_cases, f)
    except Exception as e:
        print(f"警告：无法保存进度信息: {str(e)}")

def load_progress(output_dir, progress_file):
    """加载运行进度"""
    progress_file_path = os.path.join(output_dir, progress_file)
    if os.path.exists(progress_file_path):
        try:
            with open(progress_file_path, 'r') as f:
                return json.load(f)
        except Exception as e:
            print(f"警告：无法加载进度信息: {str(e)}")
    return []

def check_convergence(log_path):
    """检查运行日志中是否有收敛问题"""
    try:
        with open(log_path, 'r') as f:
            content = f.read()
            # 检查是否有收敛失败的标志
            if "Solve Did NOT Converge!" in content or "Solve Failed!" in content:
                return False, "收敛失败"
            # 检查是否有其他严重错误
            if "*** ERROR ***" in content:
                return False, "运行错误"
            # 检查是否正常完成
            if "Finished Executing" in content:
                return True, "运行完成"
    except Exception as e:
        return None, f"无法读取日志: {str(e)}"
    return None, "状态未知"

def run_case(input_path, moose_app, mpi_processes, log_file, sub_pattern, is_first_case=False):
    """执行单个案例"""
    # 获取输入文件的目录和文件名
    case_dir = os.path.dirname(input_path)
    input_name = os.path.basename(input_path)
    
    # 检查输入文件是否位于案例目录或其子目录
    input_file_path = os.path.join(case_dir, input_name)
    if not os.path.exists(input_file_path):
        # 如果在当前目录找不到输入文件，检查是否它在子目录中
        parent_dir = os.path.dirname(case_dir)
        case_name = os.path.basename(case_dir)
        alt_file_path = os.path.join(parent_dir, case_name, input_name)
        if os.path.exists(alt_file_path):
            # 如果在子目录中找到，更新工作目录
            case_dir = os.path.join(parent_dir, case_name)
            input_file_path = alt_file_path
    
    log_path = os.path.join(case_dir, log_file)
    
    # 预检查
    print(f"\n🔍 预检查案例目录: {case_dir}")
    print(f"   输入文件路径: {input_file_path}")
    print(f"   输入文件存在: {os.path.exists(input_file_path)}")
    
    # 检查是否为多程序模式
    is_multiapp = input_name.startswith('main_')
    if is_multiapp:
        sub_pattern_path = os.path.join(case_dir, sub_pattern)
        has_sub = bool(glob.glob(sub_pattern_path))
        print(f"   模式: MultiApp (子程序{'存在' if has_sub else '不存在'})")
    else:
        print("   模式: SingleApp")
    print(f"   MOOSE可执行文件权限: {oct(os.stat(moose_app).st_mode)[-3:]}")

    # 检查上次运行状态
    if os.path.exists(log_path):
        converged, message = check_convergence(log_path)
        if converged is False:
            print(f"\n⚠ 上次运行{message}，跳过此案例")
            return {
                'status': 'skipped',
                'reason': message,
                'log': log_path
            }

    # 构建命令
    cmd = ["mpirun", "-n", str(mpi_processes), moose_app, "-i", input_name]
    
    # 如果是第一个案例，检查是否存在checkpoint文件夹
    if is_first_case:
        # 检查checkpoint文件夹
        checkpoint_pattern = os.path.join(case_dir, "*_my_checkpoint_cp")
        checkpoint_folders = glob.glob(checkpoint_pattern)
        if checkpoint_folders:
            cmd.append("--recover")
            print(f"\n💡 发现checkpoint文件夹: {os.path.basename(checkpoint_folders[0])}")
            print(f"   将从上次中断处恢复运行")
    
    print(f"\n▶ 开始执行案例: {os.path.relpath(input_path)}")
    print(f"   工作目录: {case_dir}")
    print(f"   命令: {' '.join(cmd)}")
    
    try:
        with open(log_path, 'a' if is_first_case else 'w') as log_file_handler:
            # 写入日志头
            log_file_handler.write(f"\n=== {'恢复' if is_first_case else '开始'}执行 {datetime.now().isoformat()} ===\n")
            log_file_handler.write(f"模式: {'MultiApp' if is_multiapp else 'SingleApp'}\n")
            log_file_handler.write(f"命令: {' '.join(cmd)}\n")
            log_file_handler.write(f"工作目录: {case_dir}\n\n")
            log_file_handler.flush()

            # 执行命令
            start_time = time.time()
            process = subprocess.Popen(
                cmd,
                cwd=case_dir,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                bufsize=1,
                universal_newlines=True
            )

            # 实时输出
            while True:
                output = process.stdout.readline()
                if output:
                    print(f"[{datetime.now().strftime('%H:%M:%S')}] {output.strip()}")
                    log_file_handler.write(f"[{datetime.now().isoformat()}] {output}")
                    log_file_handler.flush()
                if process.poll() is not None and output == '':
                    break

            # 记录结果
            elapsed = time.time() - start_time
            log_file_handler.write(f"\n=== 运行结束 ===\n")
            log_file_handler.write(f"返回码: {process.returncode}\n")
            log_file_handler.write(f"耗时: {elapsed:.1f}s\n")
            
            # 检查运行结果
            converged, message = check_convergence(log_path)
            if converged is False:
                return {
                    'status': 'failed',
                    'reason': message,
                    'time': round(elapsed, 1),
                    'log': log_path,
                    'recovered': is_first_case
                }
            
            return {
                'status': 'success' if process.returncode == 0 else 'failed',
                'time': round(elapsed, 1),
                'log': log_path,
                'recovered': is_first_case
            }
            
    except Exception as e:
        error_msg = f"严重错误: {str(e)}"
        print(error_msg)
        return {
            'status': 'error',
            'error': error_msg,
            'log': log_path,
            'recovered': is_first_case
        }

def analyze_current_results(args):
    """分析当前已完成的结果"""
    print("\n===== 分析当前结果 =====")
    print("执行临时结果分析...")
    
    analyze_cmd = [
        'python', 
        os.path.join(SCRIPTS_PY_DIR, 'analyze_results.py'),
        '--base-dir', args.base_dir,
        '--studies-dir', args.output_dir
    ]
    
    try:
        print(f"运行命令: {' '.join(analyze_cmd)}")
        process = subprocess.Popen(
            analyze_cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1,
            universal_newlines=True
        )
        
        # 实时输出分析过程
        for line in iter(process.stdout.readline, ''):
            print(f"  [分析] {line.strip()}")
        
        process.wait()
        
        if process.returncode == 0:
            print("✓ 临时结果分析完成")
            return True
        else:
            print("✗ 临时结果分析失败")
            return False
    except Exception as e:
        print(f"✗ 临时结果分析出错: {str(e)}")
        return False

def visualize_current_results(args):
    """对当前结果进行ParaView可视化处理"""
    if args.skip_visualization:
        print("\n跳过可视化处理（根据用户设置）")
        return True
        
    print("\n===== 可视化当前结果 =====")
    print("执行临时可视化处理...")
    
    # 构建ParaView处理命令
    paraview_cmd = [
        'bash',
        os.path.join(SCRIPTS_SH_DIR, 'setup_paraview.sh'),
        '--env-name', args.paraview_env,
        '--studies-dir', args.output_dir,
        '--base-dir', args.base_dir,
        '--target-times', args.target_times
    ]
    
    try:
        print(f"运行命令: {' '.join(paraview_cmd)}")
        process = subprocess.Popen(
            paraview_cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1,
            universal_newlines=True
        )
        
        # 实时输出可视化过程
        for line in iter(process.stdout.readline, ''):
            print(f"  [可视化] {line.strip()}")
        
        process.wait()
        
        if process.returncode == 0:
            print("✓ 临时可视化处理完成")
            return True
        else:
            print("✗ 临时可视化处理失败")
            return False
    except Exception as e:
        print(f"✗ 临时可视化处理出错: {str(e)}")
        return False

def process_case_results(args):
    """处理当前案例的结果（分析和可视化）"""
    print("\n===== 处理当前案例结果 =====")
    
    # 分析结果
    analyze_success = analyze_current_results(args)
    
    # 可视化处理
    visualize_success = visualize_current_results(args)
    
    return analyze_success and visualize_success

def run_simulation(args):
    """执行仿真程序的主函数"""
    # 加载进度
    completed_cases = load_progress(args.output_dir, args.progress_file)
    if completed_cases:
        print(f"\n发现 {len(completed_cases)} 个已完成的案例")

    # 查找待运行案例
    cases = find_input_files(args.output_dir, args.main_pattern, args.single_pattern)
    if not cases:
        print("未找到可执行案例！")
        return
    
    # 过滤已完成案例
    base_dir_path = args.base_dir
    cases_to_run = [case for case in cases 
                    if os.path.relpath(case, base_dir_path) not in completed_cases]
    
    if len(cases) != len(cases_to_run):
        for case in cases:
            if os.path.relpath(case, base_dir_path) in completed_cases:
                print(f"跳过已完成的案例: {os.path.basename(case)}")
    
    print(f"\n找到 {len(cases_to_run)} 个待执行案例")
    
    # 执行案例
    results = []
    try:
        for idx, case in enumerate(cases_to_run):
            print(f"\n=== 进度 [{idx+1}/{len(cases_to_run)}] ===")
            result = run_case(
                case, 
                args.moose_app, 
                args.mpi_processes, 
                args.log_file,
                args.sub_pattern,
                is_first_case=(idx == 0)
            )
            results.append(result)
            
            if result['status'] == 'success':
                print(f"✔ 成功完成！耗时 {result['time']} 秒")
                completed_cases.append(os.path.relpath(case, base_dir_path))
                save_progress(args.output_dir, args.progress_file, completed_cases)
            elif result['status'] == 'skipped':
                print(f"⏭ 跳过案例！原因: {result['reason']}")
            else:
                print(f"✖ 执行失败！日志路径: {result['log']}")
                if 'reason' in result:
                    print(f"   原因: {result['reason']}")
            
            # 无论案例结果如何，都处理结果(分析和可视化)
            print("\n正在处理当前案例结果...")
            process_case_results(args)
    except KeyboardInterrupt:
        print("\n\n检测到用户中断，保存进度...")
        save_progress(args.output_dir, args.progress_file, completed_cases)
        print("进度已保存，下次运行时将从中断处继续")
        sys.exit(1)
    
    # 生成报告
    success_count = sum(1 for r in results if r['status'] == 'success')
    recovered_count = sum(1 for r in results if r.get('recovered', False))
    print(f"\n执行完成：成功 {success_count}/{len(cases_to_run)} 个案例")
    if recovered_count > 0:
        print(f"其中 {recovered_count} 个案例是从中断处恢复运行的")
    print(f"详细日志请查看各案例目录下的 {args.log_file} 文件")

    # 清理进度文件
    progress_file_path = os.path.join(args.output_dir, args.progress_file)
    if os.path.exists(progress_file_path):
        os.remove(progress_file_path)

def main():
    """主函数"""
    args = parse_args()
    
    # 如果未指定base_dir，直接使用SCRIPTS_PATH（而不是它的父目录）
    if args.base_dir is None:
        args.base_dir = SCRIPTS_PATH  # 直接使用脚本目录作为基础目录
        
    # 如果未指定输出目录，使用SCRIPTS_PATH/parameter_studies作为默认输出目录
    if args.output_dir is None:
        args.output_dir = os.path.join(SCRIPTS_PATH, 'parameter_studies')
        
    if args.moose_app is None:
        args.moose_app = "/home/yp/projects/raccoon/raccoon-opt"
    
    # 显示路径信息
    print(f"\n使用以下路径配置:")
    print(f"基础目录: {args.base_dir}")
    print(f"输出目录: {args.output_dir}")
    print(f"MOOSE应用: {args.moose_app}")
    print(f"脚本目录: {SCRIPTS_PATH}")
    print(f"Shell脚本目录: {SCRIPTS_SH_DIR}")
    print(f"Python脚本目录: {SCRIPTS_PY_DIR}")
    
    # 检查环境
    issues = check_environment(args.moose_app, args.conda_env)
    
    if 'need_activation' in issues:
        script_path = os.path.abspath(__file__)
        activate_and_run(args.conda_env, script_path)
        return
        
    if issues:
        print("\n环境检查发现以下问题：")
        for issue in issues:
            print(issue)
        sys.exit(1)
    
    # 运行仿真
    run_simulation(args)

if __name__ == '__main__':
    main() 