import re
import os
import csv
import argparse
from collections import defaultdict

def parse_args():
    """解析命令行参数"""
    parser = argparse.ArgumentParser(description="结果分析与汇总工具")
    
    # 基本路径参数
    parser.add_argument('--base-dir', default=None, 
                        help='基础目录路径，默认为当前脚本所在目录的父目录')
    parser.add_argument('--studies-dir', default=None,
                        help='参数研究目录路径，默认为base-dir/ScriptTesting/parameter_studies')
    parser.add_argument('--output-file', default=None,
                        help='输出文件名，默认为studies-dir/convergence_report.csv')
    
    return parser.parse_args()

def natural_sort_key(s):
    """用于自然排序的键函数"""
    return [int(t) if t.isdigit() else t.lower() for t in re.split(r'(\d+)', s)]

def get_param_names_from_template(studies_dir):
    """从输入文件的注释中获取参数的完整名称"""
    # 遍历目录找到第一个输入文件
    for case_dir in os.listdir(studies_dir):
        case_path = os.path.join(studies_dir, case_dir)
        if not os.path.isdir(case_path):
            continue
        
        # 查找输入文件
        for file in os.listdir(case_path):
            if file.endswith('.i'):
                file_path = os.path.join(case_path, file)
                with open(file_path, 'r', encoding='utf-8') as f:
                    lines = f.readlines()
                    # 提取参数名称
                    param_dict = {}
                    for line in lines:
                        # 跳过前两行
                        if "=== 参数研究案例 ===" in line or "end_time" in line:
                            continue
                        # 如果遇到生成时间，停止读取
                        if "生成时间" in line:
                            break
                        # 提取参数名
                        if line.startswith('#') and ':' in line:
                            param_line = line.strip('# ').split(':')
                            if len(param_line) == 2:
                                name = param_line[0].strip()
                                # 从文件名中提取的简写形式
                                if name == 'Gf':
                                    short_name = 'gf'
                                elif name == 'length_scale_paramete':
                                    short_name = 'le'
                                elif name == 'power_factor_mod':
                                    short_name = 'po'
                                else:
                                    continue
                                param_dict[short_name] = name
                    if param_dict:
                        print(f"找到参数映射: {param_dict}")  # 调试信息
                        return param_dict
    return {}

def analyze_logs(studies_dir, output_path):
    """分析仿真日志并生成报告"""
    # 获取参数的完整名称
    param_names = get_param_names_from_template(studies_dir)
    print(f"参数名称映射: {param_names}")  # 调试信息

    # 精确参数解析模式（匹配形如 _参数名数值 的结构）
    param_pattern = re.compile(
        r'_(Gf|le|po)(\d+(?:_\d+)*(?:[eE][+-]?\d+)?)'  # 修改为精确匹配特定参数
        r'(?=_|$)',
        re.IGNORECASE
    )

    # 参数值格式化函数
    def format_value(v):
        # 将第一个下划线替换为小数点（1_00e-5 → 1.00e-5）
        if '_' in v:
            parts = v.split('_', 1)
            return f"{parts[0]}.{parts[1].replace('_', '')}"
        return v

    # 收集所有案例和参数
    case_list = []
    all_params = set()
    
    for case_dir in sorted(os.listdir(studies_dir), key=natural_sort_key):
        if not os.path.isdir(os.path.join(studies_dir, case_dir)):
            continue
        
        # 提取参数
        params = {}
        for match in param_pattern.finditer(case_dir):
            name = match.group(1).lower()  # 统一小写处理
            value = format_value(match.group(2))
            params[name] = value
        
        # 记录参数
        all_params.update(params.keys())
        case_list.append((case_dir, params))

    # 生成表头（使用完整参数名）
    priority_order = ['gf', 'le', 'po']
    sorted_params = sorted(
        all_params,
        key=lambda x: (priority_order.index(x) if x in priority_order else len(priority_order), x)
    )

    # 处理每个案例
    results = []
    for case_dir, params in case_list:
        result = {
            'Case': case_dir,
            'converged': 'False',
            'end_time': '0',
            'return_code': '1',
            'errors': 'None',
            'error': ''
        }
        
        # 添加参数（使用完整名称）
        for param_short in sorted_params:
            param_full = param_names.get(param_short, param_short)
            result[param_full] = params.get(param_short, '')
        
        log_path = os.path.join(studies_dir, case_dir, 'run.log')
        if not os.path.exists(log_path):
            result['error'] = 'Missing log'
            results.append(result)
            continue

        # 解析日志内容
        with open(log_path, 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read()
        
        # 返回码
        if rc_match := re.search(r'返回码: (\d+)', content):
            result['return_code'] = rc_match.group(1)
            result['converged'] = 'True' if rc_match.group(1) == '0' else 'False'
        
        # 最终时间
        if time_steps := re.findall(r'Time Step \d+, time = ([\d\.e+]+)', content):
            result['end_time'] = time_steps[-1]
        
        # 错误信息
        errors = []
        if re.search(r'dtmin', content, re.IGNORECASE):
            errors.append('DT_MIN')
        if re.search(r'max steps', content, re.IGNORECASE):
            errors.append('MAX_STEPS')
        result['errors'] = ','.join(errors) if errors else 'None'
        
        results.append(result)

    # 生成CSV（使用完整参数名作为表头）
    headers = ['Case'] + [param_names.get(p, p) for p in sorted_params] + ['converged', 'end_time', 'return_code', 'errors', 'error']
    with open(output_path, 'w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=headers)
        writer.writeheader()
        writer.writerows(results)

    print(f"报告生成成功：{output_path}")
    return len(results)

def main():
    """主函数"""
    args = parse_args()
    
    # 如果未指定base_dir，使用当前脚本所在目录的父目录
    if args.base_dir is None:
        script_dir = os.path.dirname(os.path.abspath(__file__))
        base_dir = os.path.dirname(os.path.dirname(script_dir))  # 脚本在 Scripts/.py 目录中，需要上溯两级
    else:
        base_dir = args.base_dir
    
    # 如果未指定studies_dir，使用默认值
    if args.studies_dir is None:
        studies_dir = os.path.join(base_dir, 'parameter_studies')  # 移除ScriptTesting
    else:
        studies_dir = args.studies_dir
    
    # 确保studies_dir存在
    if not os.path.exists(studies_dir):
        print(f"错误：参数研究目录不存在: {studies_dir}")
        return
    
    # 如果未指定output_file，使用默认值
    if args.output_file is None:
        output_path = os.path.join(studies_dir, 'convergence_report.csv')
    else:
        # 若提供了相对路径，相对于studies_dir解析
        if not os.path.isabs(args.output_file):
            output_path = os.path.join(studies_dir, args.output_file)
        else:
            output_path = args.output_file
    
    # 确保output_path的目录存在
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    
    try:
        case_count = analyze_logs(studies_dir, output_path)
        print(f"分析完成: 共处理 {case_count} 个案例")
    except Exception as e:
        print(f"分析过程中出错: {str(e)}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    main() 