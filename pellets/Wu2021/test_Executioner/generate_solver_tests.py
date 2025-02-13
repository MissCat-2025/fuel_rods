import os
import shutil

# 定义输入和输出路径
input_file = 'CreepStrain.i'  # 输入文件路径
output_dir = 'InputFiles'  # 输出目录

# 确保输出目录存在
if not os.path.exists(output_dir):
    os.makedirs(output_dir)

# 定义不同的求解器设置
solver_settings = [
    {
        'value': 'lu superlu_dist gmres',
        'iname': '-pc_type -pc_factor_mat_solver_package -ksp_type'
    },
    {
        'value': 'hypre gmres boomeramg',
        'iname': '-pc_type -ksp_type -pc_hypre_type'
    },
    {
        'value': 'bjacobi gmres NONZERO 1e-10',
        'iname': '-pc_type -ksp_type -pc_factor_shift_type -pc_factor_shift_amount'
    },
    {
        'value': 'lu superlu_dist',
        'iname': '-pc_type -pc_factor_mat_solver_package'
    },
    {
        'value': '201 hypre boomeramg',
        'iname': '-ksp_gmres_restart -pc_type -pc_hypre_type'
    }
]

# 获取输入文件的基本名称（不包含路径和扩展名）
input_base_name = os.path.splitext(os.path.basename(input_file))[0]

# 读取原始输入文件
with open(input_file, 'r', encoding='utf-8') as f:
    original_content = f.read()

# 为每个求解器设置创建新的输入文件
for setting in solver_settings:
    # 生成文件名，使用所有参数值
    name_parts = setting['value'].replace('.', '_').replace('-', '_').split()
    solver_name = '_'.join(name_parts)
    
    # 创建新文件名（在InputFiles目录下）
    new_filename = os.path.join(output_dir, f'{input_base_name}_{solver_name}.i')
    
    # 复制原始内容
    new_content = original_content
    
    # 替换求解器设置
    # 在[Executioner]部分替换或添加求解器设置
    executioner_start = new_content.find('[Executioner]')
    executioner_end = new_content.find('[', executioner_start + 1)
    if executioner_end == -1:
        executioner_end = len(new_content)
    
    executioner_section = new_content[executioner_start:executioner_end]
    
    # 移除现有的petsc_options相关设置
    lines = executioner_section.split('\n')
    filtered_lines = [line for line in lines if not any(x in line for x in ['petsc_options_iname', 'petsc_options_value', 'petsc_options ='])]
    
    # 添加新的求解器设置
    filtered_lines.insert(3, f'  petsc_options_iname = \'{setting["iname"]}\'')
    filtered_lines.insert(4, f'  petsc_options_value = \'{setting["value"]}\'')
    
    # 重建执行器部分
    new_executioner_section = '\n'.join(filtered_lines)
    
    # 替换原始文件中的执行器部分
    new_content = new_content[:executioner_start] + new_executioner_section + new_content[executioner_end:]
    
    # 写入新文件
    with open(new_filename, 'w', encoding='utf-8') as f:
        f.write(new_content)

print(f"已在 {output_dir} 目录下生成以下输入文件：")
for setting in solver_settings:
    name_parts = setting['value'].replace('.', '_').replace('-', '_').split()
    solver_name = '_'.join(name_parts)
    print(f"- {input_base_name}_{solver_name}.i") 