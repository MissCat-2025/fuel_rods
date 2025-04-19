import os
import re
import shutil
import itertools
from datetime import datetime

# 基础配置
base_dir = '/home/yp/projects/raccoon/FuelFracture/RodFuel/Liwei2021/MaterialParametersVerification/step3_ThermalFracture'
template_main = os.path.join(base_dir, 'NoClad3D_ThermallFracture.i')
template_sub = os.path.join(base_dir, 'NoClad3D_ThermallFracture_Sub.i')
output_dir = os.path.join(base_dir, 'parameter_studies')

# 参数矩阵定义 (在此修改需要研究的参数)
parameter_matrix = {
    'Gf': [1,3,5,10],# 添加新参数格式：'parameter_name': [value1, value2, ...]}
    'length_scale_paramete': [1e-5,3e-5,5e-5,7e-5,10e-5]
}
def generate_parameter_combinations(params_dict):
    """生成所有参数的笛卡尔积组合"""
    keys = params_dict.keys()
    values = params_dict.values()
    return [dict(zip(keys, combo)) for combo in itertools.product(*values)]

def format_scientific(value):
    """将数值格式化为科学计数法字符串"""
    if isinstance(value, float) and (abs(value) >= 1e4 or abs(value) < 1e-3):
        return f"{value:.2e}".replace('e-0', 'e-').replace('e+0', 'e+')
    return str(value)

def generate_case_name(params):
    """生成包含所有参数的短名称"""
    return '_'.join([f"{k[:2]}{format_scientific(v).replace('.','_')}" 
                    for k, v in params.items()])

def replace_parameters(content, params):
    """动态替换所有参数"""
    # 先处理常规参数
    for param, value in params.items():
        pattern = rf'(\s*){param}\s*=\s*[\d\.eE+-]+(.*?)(\n)'
        replacement = f'\\1{param} = {format_scientific(value)}\\2\\3'
        content = re.sub(pattern, replacement, content, flags=re.MULTILINE)
    
    # 特殊处理MultiApp的input_files参数
    subapp_filename = f"sub_{generate_case_name(params)}.i"
    content = re.sub(
        r'(input_files\s*=\s*)\'\S+\.i\'',
        f"\\1'{subapp_filename}'", 
        content
    )
    return content

def generate_header(params):
    """生成包含参数信息的注释头"""
    header = "# === 参数研究案例 ===\n"
    for k, v in params.items():
        header += f"# {k}: {format_scientific(v)}\n"
    header += f"# 生成时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n"
    return header

def generate_study_cases():
    # 校验模板文件
    if not all(os.path.exists(f) for f in [template_main, template_sub]):
        raise FileNotFoundError("模板文件不存在，请检查路径配置")

    # 清理并创建输出目录
    if os.path.exists(output_dir):
        shutil.rmtree(output_dir)
    os.makedirs(output_dir, exist_ok=True)

    # 生成所有参数组合
    all_params = generate_parameter_combinations(parameter_matrix)
    
    for idx, params in enumerate(all_params, 1):
        case_name = generate_case_name(params)
        case_dir = os.path.join(output_dir, f"case_{idx:03d}_{case_name}")
        os.makedirs(case_dir, exist_ok=True)

        # 处理主程序文件
        with open(template_main, 'r') as f:
            main_content = generate_header(params) + f.read()
        main_content = replace_parameters(main_content, params)
        main_output = os.path.join(case_dir, f"main_{case_name}.i")
        with open(main_output, 'w') as f:
            f.write(main_content)

        # 处理子程序文件
        with open(template_sub, 'r') as f:
            sub_content = generate_header(params) + f.read()
        sub_content = replace_parameters(sub_content, params)
        sub_output = os.path.join(case_dir, f"sub_{case_name}.i")
        with open(sub_output, 'w') as f:
            f.write(sub_content)

        print(f"生成案例 {idx:03d}: {case_name}")
        print(f"  路径: {case_dir}")

if __name__ == '__main__':
    try:
        generate_study_cases()
        print(f"\n所有案例已成功生成至: {os.path.abspath(output_dir)}")
        print(f"总案例数: {len(generate_parameter_combinations(parameter_matrix))}")
    except Exception as e:
        print(f"\n错误发生: {str(e)}")
        print("故障排查建议:")
        print("1. 检查模板文件路径是否正确")
        print("2. 确认参数名称与模板文件中的变量名完全一致")
        print("3. 验证参数值格式是否正确 (支持整型和浮点型)")
        print("4. 检查文件系统权限和磁盘空间")