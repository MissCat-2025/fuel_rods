import re
import os
import csv
from collections import defaultdict

def analyze_logs():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    studies_dir = os.path.join(script_dir, 'parameter_studies')
    output_path = os.path.join(studies_dir, 'convergence_report.csv')

    # 精确参数解析模式（匹配形如 _参数名数值 的结构）
    param_pattern = re.compile(
        r'_([A-Za-z]+)'          # 参数名（纯字母）
        r'((?:\d+_)*\d+'         # 数值部分（支持1_00格式）
        r'(?:[eE][+-]?\d+)?'     # 科学计数法
        r'(?:\.\d+)?)'           # 小数部分
        r'(?=_|$)',              # 以下划线或结尾为界
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

    # 生成表头（优先显示常用参数）
    priority_order = ['gf', 'le', 'pe', 'e']
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
        
        # 添加参数
        for param in sorted_params:
            result[param] = params.get(param, '')
        
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

    # 生成CSV
    headers = ['Case'] + sorted_params + ['converged', 'end_time', 'return_code', 'errors', 'error']
    with open(output_path, 'w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=headers)
        writer.writeheader()
        writer.writerows(results)

    print(f"报告生成成功：{output_path}")

def natural_sort_key(s):
    return [int(t) if t.isdigit() else t.lower() for t in re.split(r'(\d+)', s)]

if __name__ == "__main__":
    analyze_logs()