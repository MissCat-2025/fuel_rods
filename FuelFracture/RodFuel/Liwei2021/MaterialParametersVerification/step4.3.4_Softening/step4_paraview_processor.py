#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
增强版ParaView结果处理脚本
"""

import os
import sys
import subprocess
from collections import namedtuple

# 配置参数
ExportConfig = namedtuple('ExportConfig', [
    'target_times',    # 目标时间列表 [4.0, 5.0, 6.0]
    'field_list',      # 要导出的字段配置 [('T', '温度'), ('stress', '应力')]
    'image_size',      # 图像分辨率 [1642, 1083]
    'output_dir_name'  # 输出目录名称后缀
])

# 默认配置
DEFAULT_CONFIG = ExportConfig(
    target_times=[175000],
    field_list=[
        ('d', '相场变量'),
        # ('T', '温度'),
        ('hoop_stress', '环向应力'),
        # ('thermal_hoop_strain', '环向热应变'),
        # ('mechanical_hoop_strain', '环向机械应变')
    ],
    image_size=(1642, 1083),
    output_dir_name="post_results"
)

def export_field_data(file_path, config=DEFAULT_CONFIG):
    """导出多字段数据"""
    try:
        from paraview.simple import (
            OpenDataFile, GetActiveViewOrCreate, GetDisplayProperties,
            ColorBy, GetColorTransferFunction, GetOpacityTransferFunction,
            GetAnimationScene, GetLayout, SaveScreenshot, UpdatePipeline,
            GetSettingsProxy, HideAll
        )
        import paraview.simple
        paraview.simple._DisableFirstRenderCameraReset()
    except ImportError:
        print("错误：无法导入ParaView模块")
        return False

    try:
        # 1. 读取文件
        print(f"\n处理文件: {os.path.basename(file_path)}")
        reader = OpenDataFile(file_path)
        if not reader:
            print("无法读取文件")
            return False

        # 2. 获取时间步
        time_steps = []
        if hasattr(reader, 'TimestepValues'):
            time_steps = [float(t) for t in reader.TimestepValues]
        elif hasattr(reader, 'TimestepValue'):
            time_steps = [float(reader.TimestepValue)]
        
        if not time_steps:
            print("警告: 未找到时间步信息")
            return False

        # 3. 创建输出目录
        base_name = os.path.splitext(os.path.basename(file_path))[0]
        output_root = os.path.join(os.path.dirname(file_path), config.output_dir_name)
        os.makedirs(output_root, exist_ok=True)

        # 为每个字段创建子目录
        field_dirs = {}
        for field, display_name in config.field_list:
            dir_path = os.path.join(output_root, f"{field}_images")
            os.makedirs(dir_path, exist_ok=True)
            field_dirs[field] = dir_path

        # 4. 设置视图参数
        renderView1 = GetActiveViewOrCreate('RenderView')
        layout1 = GetLayout()
        layout1.SetSize(*config.image_size)
        
        # 设置背景和文字颜色
        colorPalette = GetSettingsProxy('ColorPalette')
        colorPalette.Background = [1.0, 1.0, 1.0]  # 白色背景
        colorPalette.Text = [0.0, 0.0, 0.0]  # 黑色文字
        
        renderView1.CameraPosition = [0.0, 0.0, 0.03999187526517147]
        renderView1.CameraFocalPoint = [0.0, 0.0, 3e-05]
        renderView1.CameraParallelScale = 0.010342894396637723

        # 5. 处理每个字段
        for field, display_name in config.field_list:
            print(f"\n正在处理字段: {display_name} ({field})")
            
            try:
                # 隐藏所有已有显示
                HideAll()
                # paraview.simple.HideAll(reader, renderView1)
                
                # 创建新的显示对象
                display = paraview.simple.Show(reader, renderView1)
                display.Representation = 'Surface'

                # 获取所有可用字段（包括点、单元和场数据）
                def get_all_fields(reader):
                    fields = []
                    # 检查所有可能的数据属性
                    for attr in ['PointData', 'CellData', 'FieldData']:
                        if hasattr(reader, attr):
                            data = getattr(reader, attr)
                            fields.extend([(arr.GetName(), attr) for arr in data])
                    return fields

                # 获取所有字段及其存储位置
                all_fields = get_all_fields(reader)
                available_fields = [f[0] for f in all_fields]
                print(f"可用字段列表: {available_fields}")

                # 查找字段实际存储名称（精确匹配）
                actual_field = next(
                    (f for f in all_fields if f[0] == field),  # 改为精确匹配
                    None
                )

                if not actual_field:
                    print(f"  警告: 字段 {field} 不存在，可用字段：{available_fields}")
                    continue

                # 获取数据数组
                data_attr = getattr(reader, actual_field[1])  # PointData/CellData
                data_array = data_attr[actual_field[0]]
                
                # 检查数据有效性
                if not data_array:
                    print(f"  警告: 字段 {field} 数据为空")
                    continue

                # 设置字段显示（使用新的display对象）
                association = 'POINTS' if actual_field[1] == 'PointData' else 'CELLS'
                ColorBy(display, (association, actual_field[0]))
                renderView1.Update()

                # 删除旧的颜色条（关键修改）
                display.SetScalarBarVisibility(renderView1, False)  # 先隐藏旧颜色条
                display.SetScalarBarVisibility(renderView1, True)   # 显示新颜色条

                # 安全获取数据范围
                try:
                    data_range = data_array.GetRange()
                    print(f"  数据范围: {data_range[0]:.2e} 至 {data_range[1]:.2e}")
                except Exception as e:
                    print(f"  无法获取数据范围: {str(e)}")
                    data_range = [0, 1]  # 使用默认范围

                # 设置颜色映射
                lut = GetColorTransferFunction(actual_field[0])
                pov = GetOpacityTransferFunction(actual_field[0])
                
                # 应用预设的颜色方案
                lut.ApplyPreset('Blue to Red Rainbow', True)
                lut.NumberOfTableValues = 20  # 将颜色表的值数量减少到20
                
                # 显示颜色条
                display.SetScalarBarVisibility(renderView1, True)

                # 强制更新视图
                renderView1.ResetCamera()
                renderView1.Update()

            except Exception as e:
                print(f"  字段设置失败: {str(e)}")
                continue

            # 6. 处理每个时间点
            for target_time in config.target_times:
                closest_time = min(time_steps, key=lambda x: abs(x - target_time))
                print(f"  时间 {target_time}s → 使用 {closest_time:.2f}s")

                # 设置时间步
                animationScene1 = GetAnimationScene()
                animationScene1.AnimationTime = float(closest_time)

                # 强制更新数据
                UpdatePipeline(time=closest_time, proxy=reader)
                
                # 获取当前显示属性
                display = GetDisplayProperties(reader, view=renderView1)
                
                # 重新缩放传输函数（关键修改点）
                display.RescaleTransferFunctionToDataRange(False, True)  # 参数说明：(useVisibleRange=False, clamp=False)
                
                # 强制更新视图
                renderView1.Update()
                renderView1.ResetCamera()

                # 生成输出路径
                time_str = f"{closest_time:.2f}s".replace('.', 'p')
                output_file = os.path.join(
                    field_dirs[field],
                    f'{base_name}_{field}_{time_str}.png'
                )

                # 保存截图
                SaveScreenshot(
                    filename=output_file,
                    viewOrLayout=renderView1,
                    ImageResolution=config.image_size
                )
                print(f"    已保存: {os.path.basename(output_file)}")

        return True

    except Exception as e:
        print(f"\n错误: {str(e)}")
        return False

def main():
    """主函数"""
    # 1. 检查目录
    script_dir = os.path.dirname(os.path.abspath(__file__))
    studies_dir = os.path.join(script_dir, 'parameter_studies')
    
    if not os.path.exists(studies_dir):
        print("数据目录不存在")
        return
        
    # 2. 查找.e文件
    e_files = []
    for root, _, files in os.walk(studies_dir):
        for file in files:
            if file.endswith('.e'):
                e_files.append(os.path.join(root, file))
                
    if not e_files:
        print("未找到.e文件")
        return
        
    print(f"找到{len(e_files)}个数据文件")
    
    # 3. 处理所有文件
    success_count = 0
    for idx, e_file in enumerate(e_files):
        print(f"\n处理文件 {idx+1}/{len(e_files)}: {os.path.basename(e_file)}")
        if export_field_data(e_file):
            success_count += 1

    print(f"\n处理完成：成功{success_count}个，失败{len(e_files)-success_count}个")

if __name__ == "__main__":
    main()