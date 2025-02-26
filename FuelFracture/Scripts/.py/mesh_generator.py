import os
import re
import shutil
import itertools
import argparse
import json
from datetime import datetime

def parse_args():
    """解析命令行参数"""
    parser = argparse.ArgumentParser(description="网格与参数研究生成器")
    
    # 基本路径参数
    parser.add_argument('--base-dir', default=None, 
                        help='基础目录路径，默认为当前脚本所在目录的父目录')
    parser.add_argument('--template-main', default=None,
                        help='主模板文件路径')
    parser.add_argument('--template-sub', default=None,
                        help='子模板文件路径，如果与主模板相同则为单程序模式')
    parser.add_argument('--output-dir', default=None,
                        help='输出目录名称')
    
    # Checkpoint配置参数
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
    
    return parser.parse_args()

def add_checkpoint_to_outputs(content, interval, num_files, wall_time):
    """在[Outputs]块中添加checkpoint配置"""
    checkpoint_config = f'''
  [my_checkpoint]
    type = Checkpoint
    time_step_interval = {interval}    # 每{interval}个时间步保存
    num_files = {num_files}            # 保留最近{num_files}个检查点
    wall_time_interval = {wall_time} # 每{wall_time//60}分钟保存一次（秒）
  []'''
    
    # 查找[Outputs]块
    outputs_match = re.search(r'\[Outputs\](.*?)\[\]', content, re.DOTALL)
    if outputs_match:
        outputs_block = outputs_match.group(1)
        # 检查是否已经有checkpoint配置 - 更新检测条件
        if 'type = Checkpoint' not in outputs_block:
            # 在[Outputs]块的开始处添加checkpoint配置
            new_outputs = f'[Outputs]{checkpoint_config}{outputs_block}[]'
            content = content.replace(outputs_match.group(0), new_outputs)
    else:
        # 如果没有找到[Outputs]块，在文件末尾添加
        content += f'\n[Outputs]{checkpoint_config}\n[]'
    return content

def extract_end_time(template_file):
    """从模板文件中提取end_time值"""
    try:
        with open(template_file, 'r') as f:
            content = f.read()
            match = re.search(r'end_time\s*=\s*([\d\.eE+-]+)', content)
            if match:
                return float(match.group(1))
    except Exception as e:
        print(f"警告：无法从模板文件中提取end_time: {str(e)}")
    return None

def generate_parameter_combinations(params_dict, exclude_combinations):
    """生成所有参数的笛卡尔积组合，排除不可运行的组合"""
    keys = params_dict.keys()
    values = params_dict.values()
    all_combinations = [dict(zip(keys, combo)) for combo in itertools.product(*values)]
    
    # 过滤掉排除列表中的组合
    valid_combinations = [combo for combo in all_combinations if not should_exclude_combination(combo, exclude_combinations)]
    
    return valid_combinations

def should_exclude_combination(params, exclude_combinations):
    """检查参数组合是否在排除列表中"""
    for exclude_combo in exclude_combinations:
        # 将排除组合转换为字典进行比较
        exclude_dict = {}
        for i in range(0, len(exclude_combo), 2):
            param_name = exclude_combo[i]
            param_value = exclude_combo[i+1]
            exclude_dict[param_name] = param_value
        
        # 检查所有排除参数是否匹配
        match = True
        for param_name, param_value in exclude_dict.items():
            if param_name not in params or abs(params[param_name] - param_value) > 1e-10:
                match = False
                break
        
        if match:
            return True
    
    return False

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

def generate_header(params, end_time=None):
    """生成包含参数信息的注释头"""
    header = "# === 参数研究案例 ===\n"
    
    # 从模板文件中提取end_time
    if end_time is not None:
        header += f"# end_time = {format_scientific(end_time)}\n"
    
    for k, v in params.items():
        header += f"# {k}: {format_scientific(v)}\n"
    header += f"# 生成时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n"
    return header

def rename_and_cleanup_files(case_dir, case_name, is_multiapp):
    """重命名文件并清理不需要的文件"""
    main_file = os.path.join(case_dir, f"main_{case_name}.i")
    if not is_multiapp:
        # 在单程序模式下，将main_前缀的文件重命名为不带前缀的文件
        new_file = os.path.join(case_dir, f"{case_name}.i")
        if os.path.exists(main_file):
            os.rename(main_file, new_file)
        # 删除可能存在的sub文件
        sub_file = os.path.join(case_dir, f"sub_{case_name}.i")
        if os.path.exists(sub_file):
            os.remove(sub_file)

def generate_study_cases(base_dir, template_main, template_sub, output_dir, 
                         parameter_matrix, exclude_combinations,
                         checkpoint_interval, checkpoint_files, checkpoint_time):
    """生成参数研究案例"""
    # 校验主程序模板文件
    if not os.path.exists(template_main):
        raise FileNotFoundError(f"主程序模板文件不存在: {template_main}")

    # 判断是否为多程序模式 - 修改判断逻辑
    is_multiapp = os.path.exists(template_sub) and os.path.abspath(template_main) != os.path.abspath(template_sub)

    # 清理并创建输出目录
    if os.path.exists(output_dir):
        shutil.rmtree(output_dir)
    os.makedirs(output_dir, exist_ok=True)

    # 生成所有参数组合（排除不可运行的组合）
    all_params = generate_parameter_combinations(parameter_matrix, exclude_combinations)
    
    # 打印排除的组合信息
    total_combinations = len(list(itertools.product(*parameter_matrix.values())))
    excluded_count = total_combinations - len(all_params)
    print(f"\n已排除 {excluded_count} 个已知无法运行的参数组合")
    print("排除的组合：")
    for combo in exclude_combinations:
        params_str = ", ".join(f"{combo[i]}={combo[i+1]}" for i in range(0, len(combo), 2))
        print(f"  - {params_str}")
    print()

    # 提取end_time
    end_time = extract_end_time(template_main)

    for idx, params in enumerate(all_params, 1):
        case_name = generate_case_name(params)
        case_dir = os.path.join(output_dir, f"case_{idx:03d}_{case_name}")
        os.makedirs(case_dir, exist_ok=True)

        # 处理主程序文件
        with open(template_main, 'r') as f:
            main_content = generate_header(params, end_time) + f.read()
        
        # 添加checkpoint配置
        main_content = add_checkpoint_to_outputs(main_content, checkpoint_interval, checkpoint_files, checkpoint_time)
        
        # 如果是多程序模式，需要替换input_files参数
        if is_multiapp:
            main_content = replace_parameters(main_content, params)
        else:
            # 单程序模式不需要替换input_files参数
            for param, value in params.items():
                pattern = rf'(\s*){param}\s*=\s*[\d\.eE+-]+(.*?)(\n)'
                replacement = f'\\1{param} = {format_scientific(value)}\\2\\3'
                main_content = re.sub(pattern, replacement, main_content, flags=re.MULTILINE)
                
        main_output = os.path.join(case_dir, f"main_{case_name}.i")
        with open(main_output, 'w') as f:
            f.write(main_content)

        # 如果存在子程序文件，则处理子程序文件
        if is_multiapp:
            with open(template_sub, 'r') as f:
                sub_content = generate_header(params, end_time) + f.read()
            sub_content = replace_parameters(sub_content, params)
            sub_output = os.path.join(case_dir, f"sub_{case_name}.i")
            with open(sub_output, 'w') as f:
                f.write(sub_content)

        # 重命名和清理文件
        rename_and_cleanup_files(case_dir, case_name, is_multiapp)

        print(f"生成案例 {idx:03d}: {case_name}")
        print(f"  路径: {case_dir}")
        if is_multiapp:
            print("  模式: MultiApp")
        else:
            print("  模式: SingleApp")

def main():
    """主函数"""
    args = parse_args()
    
    # 如果未指定base_dir，使用当前脚本所在目录的父目录
    if args.base_dir is None:
        script_dir = os.path.dirname(os.path.abspath(__file__))
        base_dir = os.path.dirname(os.path.dirname(script_dir))  # 脚本在 Scripts/.py 目录中，需要上溯两级
    else:
        base_dir = args.base_dir
    
    # 如果未指定其他目录，使用默认值
    template_main = args.template_main or os.path.join(base_dir, 'ScriptTesting', 'NoClad3D_ThermalCreepFracture.i')
    template_sub = args.template_sub or os.path.join(base_dir, 'ScriptTesting', 'NoClad3D_ThermalCreepFracture_Sub.i')
    output_dir = args.output_dir or os.path.join(base_dir, 'parameter_studies')
    
    # 解析参数矩阵和排除组合
    try:
        parameter_matrix = json.loads(args.parameter_matrix)
        exclude_combinations = json.loads(args.exclude_combinations)
    except json.JSONDecodeError as e:
        print(f"错误：无法解析JSON参数：{e}")
        # 使用默认参数
        parameter_matrix = {
            'Gf': [8, 10],
            'length_scale_paramete': [5e-5, 10e-5],
            'power_factor_mod': [1, 2, 3],
        }
        exclude_combinations = [
            ('Gf', 8, 'length_scale_paramete', 10e-5, 'power_factor_mod', 3),
            ('Gf', 10, 'length_scale_paramete', 5e-5),
        ]
        print("使用默认参数矩阵和排除组合")
    
    # 将JSON格式的排除组合转换为元组格式
    if isinstance(exclude_combinations, list) and all(isinstance(item, list) for item in exclude_combinations):
        # 转换为元组形式
        tuple_excludes = []
        for combo in exclude_combinations:
            if len(combo) % 2 == 0:  # 确保参数是成对的
                tuple_combo = tuple(combo)
                tuple_excludes.append(tuple_combo)
        exclude_combinations = tuple_excludes
    
    try:
        generate_study_cases(
            base_dir, template_main, template_sub, output_dir,
            parameter_matrix, exclude_combinations,
            args.checkpoint_interval, args.checkpoint_files, args.checkpoint_time
        )
        print(f"\n所有案例已成功生成至: {os.path.abspath(output_dir)}")
        print(f"总案例数: {len(generate_parameter_combinations(parameter_matrix, exclude_combinations))}")
    except Exception as e:
        print(f"\n错误发生: {str(e)}")
        print("故障排查建议:")
        print("1. 检查模板文件路径是否正确")
        print("2. 确认参数名称与模板文件中的变量名完全一致")
        print("3. 验证参数值格式是否正确 (支持整型和浮点型)")
        print("4. 检查文件系统权限和磁盘空间")

if __name__ == '__main__':
    main() 