import os
import math
import shutil
from datetime import datetime
import re

# 基础配置 - 使用完整相对路径
base_dir = 'raccoon/FuelFracture/Annular/Liwei2022/MeshVerification/step4_ThermalCreepFracture/MultiApp'
template_main = os.path.join(base_dir, 'NoClad3D_ThermallFractureStaggered.i')
template_sub = os.path.join(base_dir, 'NoClad3D_ThermallFractureStaggered_SubApp.i')
output_dir = os.path.join(base_dir, 'mesh_independence_study')

# 固定几何参数 (单位：米)
pellet_inner_diameter = 10.291e-3  # 转换为米
pellet_outer_diameter = 14.627e-3
length = 6e-5  # 轴向长度

# 需要测试的网格尺寸列表 (米)
grid_sizes = [10e-5, 9e-5, 8e-5,7e-5,6e-5,5e-5]

def calculate_mesh_params(grid_size):
    """计算网格参数"""
    params = {}
    pellet_outer_radius = pellet_outer_diameter / 2
    pellet_inner_radius = pellet_inner_diameter / 2
    
    # 计算基础周向单元数
    base_azimuthal = 2 * math.pi * pellet_outer_radius / grid_size
    # 调整为4的倍数且不小于基础值
    params['n_azimuthal'] = ((int(round(base_azimuthal)) + 3) // 4) * 4
    
    params['n_radial_pellet'] = int(round((pellet_outer_radius - pellet_inner_radius) / grid_size))
    params['length_scale_paramete'] = 6e-5
    
    # 保持参数精度
    params['pellet_inner_radius'] = round(pellet_inner_radius, 6)
    params['pellet_outer_radius'] = round(pellet_outer_radius, 6)
    params['normal_tol'] = round(3.14 * pellet_inner_diameter / params['n_azimuthal'] / 10, 9)
    
    return params

def replace_params_in_file(template_path, output_path, params, grid_size):
    """精确替换目标参数并添加注释头"""
    with open(template_path, 'r') as f:
        content = f.read()
    
    # 添加网格信息注释头
    header = f"""# === 网格无关性验证案例 ===
# 目标网格尺寸: {grid_size:.1e} m
# 总网格单元数: {params['n_radial_pellet'] * params['n_azimuthal']}
# 径向单元数: {params['n_radial_pellet']}
# 周向单元数: {params['n_azimuthal']}
# 特征长度参数: {params['length_scale_paramete']:.1e} m
# 生成时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
\n"""
    content = header + content
    
    # 新增：生成子应用文件名
    subapp_name = f"sub_rad{params['n_radial_pellet']}_azi{params['n_azimuthal']}_grid{grid_size:.1e}.i"
    
    # 修改：替换input_files参数
    param_map = {
        r'input_files\s*=\s*\'.*\'': 
            f"input_files = '{subapp_name}'",  # 关键修改点
        r'length_scale_paramete\s*=\s*\d+\.?\d*e?-?\d*': 
            f"length_scale_paramete = {params['length_scale_paramete']:.6e}",
        r'n_radial_pellet\s*=\s*\d+': 
            f"n_radial_pellet = {params['n_radial_pellet']}",
        r'n_azimuthal\s*=\s*\d+': 
            f"n_azimuthal = {params['n_azimuthal']}"
    }
    
    for pattern, replacement in param_map.items():
        content = re.sub(pattern, replacement, content)
    
    with open(output_path, 'w') as f:
        f.write(content)

def generate_mesh_cases():
    # 创建带校验的目录
    if not os.path.exists(template_main):
        raise FileNotFoundError(f"主模板文件不存在: {template_main}")
    if not os.path.exists(template_sub):
        raise FileNotFoundError(f"子模板文件不存在: {template_sub}")
    
    if os.path.exists(output_dir):
        shutil.rmtree(output_dir)
    os.makedirs(output_dir, exist_ok=True)
    
    for i, grid_size in enumerate(grid_sizes):
        case_name = f"case_{i+1}_gridsize_{grid_size:.1e}"
        case_dir = os.path.join(output_dir, case_name)
        os.makedirs(case_dir, exist_ok=True)
        
        params = calculate_mesh_params(grid_size)
        
        # 生成主程序文件
        main_output = os.path.join(case_dir, 
            f"main_rad{params['n_radial_pellet']}_azi{params['n_azimuthal']}_grid{grid_size:.1e}.i")
        replace_params_in_file(template_main, main_output, params, grid_size)
        
        # 生成子程序文件
        sub_output = os.path.join(case_dir,
            f"sub_rad{params['n_radial_pellet']}_azi{params['n_azimuthal']}_grid{grid_size:.1e}.i")
        replace_params_in_file(template_sub, sub_output, params, grid_size)
        
        print(f"生成案例 {i+1}: 网格尺寸 {grid_size:.1e} m")
        print(f"  径向单元: {params['n_radial_pellet']}")
        print(f"  周向单元: {params['n_azimuthal']}")
        print(f"  输出路径: {case_dir}\n")

if __name__ == '__main__':
    try:
        generate_mesh_cases()
        print(f"所有网格案例已成功生成至: {os.path.abspath(output_dir)}")
    except Exception as e:
        print(f"错误发生: {str(e)}")
        print("请检查：")
        print(f"1. 模板文件路径是否正确：\n  主程序: {template_main}\n  子程序: {template_sub}")
        print("2. 文件读取权限")
        print("3. 磁盘空间是否充足")