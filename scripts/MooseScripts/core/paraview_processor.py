#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ParaView后处理器
--------------
使用ParaView导出MOOSE结果数据并生成可视化

主要功能：
1. 处理MOOSE计算结果
2. 导出指定时间点的场数据
3. 生成特定视角的可视化图像
4. 批量处理多个案例
"""

import os
import sys
import glob
import argparse
import time
import json
from datetime import datetime
from collections import namedtuple

# 导入自定义模块
from MooseScripts.core.path_manager import (
    create_path_config, ensure_path_exists
)
from MooseScripts.core.env_manager import (
    setup_paraview_env
)
from MooseScripts.utils.output_utils import (
    print_header, print_config, print_summary, print_progress, print_file_list
)

# 配置参数
ExportConfig = namedtuple('ExportConfig', [
    'target_times',    # 目标时间列表 [4.0, 5.0, 6.0]
    'field_list',      # 要导出的字段配置 [('T', '温度'), ('stress', '应力')]
    'image_size',      # 图像分辨率 [1642, 1083]
    'output_dir_name'  # 输出目录名称后缀
])

def parse_args():
    """解析命令行参数"""
    parser = argparse.ArgumentParser(description="ParaView后处理工具")
    
    # 基本路径参数
    parser.add_argument('--base-dir', default=None, 
                        help='基础目录路径，默认为当前脚本所在目录的父目录')
    parser.add_argument('--studies-dir', default=None,
                        help='参数研究目录路径，默认为base-dir/parameter_studies')
    
    # ParaView环境配置
    parser.add_argument('--env-name', default='paraview_post',
                        help='ParaView环境名称')
    parser.add_argument('--force-rebuild', action='store_true',
                        help='强制重建ParaView环境')
    
    # 导出配置
    parser.add_argument('--target-times', nargs='+', type=float, default=[4.0, 5.0, 6.0],
                        help='要导出的目标时间点，例如: 4.0 5.0 6.0')
    parser.add_argument('--output-dir-name', default='post_results',
                        help='输出目录名称')
    
    return parser.parse_args()

def export_field_data(file_path, config):
    """
    导出指定时间点的场数据并生成可视化图像
    
    Args:
        file_path: Exodus文件路径
        config: 导出配置
        
    Returns:
        bool: 是否成功导出
    """
    try:
        # 尽可能延迟导入ParaView相关模块，避免在环境设置前导入
        import paraview
        paraview.compatibility.major = 5
        paraview.compatibility.minor = 11
        
        from paraview.simple import (
            GetActiveViewOrCreate, GetSources, OpenDataFile, ExodusIIReader,
            Delete, Render, ResetCamera, SaveScreenshot, Show, Hide, ColorBy,
            GetColorTransferFunction, GetOpacityTransferFunction,
            GetDisplayProperties, WriteImage, FindSource, GetScalarBar,
            HideScalarBarIfNotNeeded, ColorBarVisibility, SetProperties,
            CreateWriter, servermanager, UpdatePipeline, AnnotateTimeFilter,
            GetRenderView, Text, CreateLayout, GetLayout, LoadState,
            SetActiveView, ResetSession, GetRepresentations
        )
        from vtk.numpy_interface import dataset_adapter as dsa
        import numpy as np
        
    except ImportError as e:
        print(f"错误: 无法导入ParaView模块: {e}")
        print("请确保ParaView环境已正确配置")
        return False
    
    # 创建输出目录
    file_dir = os.path.dirname(file_path)
    output_dir = os.path.join(file_dir, config.output_dir_name)
    ensure_path_exists(output_dir)
    
    # 创建图像目录
    image_dir = os.path.join(output_dir, f"{os.path.basename(file_path)}_images")
    ensure_path_exists(image_dir)
    
    # 获取Exodus文件的读取器
    try:
        reader = OpenDataFile(file_path)
        if not reader:
            print(f"无法打开文件: {file_path}")
            return False
        
        # 注册Exodus读取器
        reader = ExodusIIReader(FileName=file_path)
        
        # 获取可用字段
        def get_all_fields(reader):
            """获取所有可用字段"""
            available_fields = {}
            
            # 获取节点字段
            node_fields = reader.PointArrayStatus.Available
            for field in node_fields:
                # 确保字段被激活
                reader.PointArrayStatus.append(field)
                available_fields[field] = 'Point'
                
            # 获取单元字段
            cell_fields = reader.CellArrayStatus.Available
            for field in cell_fields:
                # 确保字段被激活
                reader.CellArrayStatus.append(field)
                available_fields[field] = 'Cell'
                
            return available_fields
        
        # 获取所有字段
        all_fields = get_all_fields(reader)
        print(f"可用字段: {', '.join(all_fields.keys())}")
        
        # 获取时间步
        reader.UpdatePipelineInformation()
        available_times = reader.TimestepValues
        if not available_times:
            print("文件没有时间步")
            return False
        
        print(f"可用时间点: {available_times}")
        
        # 过滤目标时间点
        target_times = config.target_times
        valid_times = []
        
        for t in target_times:
            # 查找最接近的时间点
            closest_time = min(available_times, key=lambda x: abs(x - t))
            if abs(closest_time - t) < 0.1:  # 0.1是允许的误差范围
                valid_times.append(closest_time)
            else:
                print(f"找不到接近时间点 {t} 的可用时间步")
        
        if not valid_times:
            print("没有有效的目标时间点")
            return False
        
        # 创建默认视图
        view = GetActiveViewOrCreate('RenderView')
        
        # 显示网格
        display = Show(reader, view)
        
        # 处理每个时间点和字段
        for target_time in valid_times:
            # 设置时间步
            view.ViewTime = target_time
            reader.UpdatePipelineInformation()
            
            # 重置相机以确保视图合适
            ResetCamera()
            
            # 导出每个目标字段的图像
            for field_name, field_title in config.field_list:
                if field_name in all_fields:
                    field_type = all_fields[field_name]
                    
                    if field_type == 'Point':
                        ColorBy(display, ('POINTS', field_name))
                    else:
                        ColorBy(display, ('CELLS', field_name))
                    
                    # 获取颜色映射
                    color_map = GetColorTransferFunction(field_name)
                    opacity_map = GetOpacityTransferFunction(field_name)
                    
                    # 设置标量条
                    scalar_bar = GetScalarBar(color_map, view)
                    scalar_bar.Title = field_title
                    scalar_bar.ComponentTitle = ''
                    scalar_bar.Visibility = 1
                    
                    # 渲染视图
                    Render(view)
                    
                    # 生成图像文件名
                    image_file = os.path.join(
                        image_dir, 
                        f"{os.path.basename(file_path)}_{field_name}_{target_time:.1f}.png"
                    )
                    
                    # 保存图像
                    SaveScreenshot(
                        image_file, view, 
                        ImageResolution=config.image_size,
                        TransparentBackground=0
                    )
                    
                    print(f"已导出: {image_file}")
                    
                    # 隐藏标量条
                    HideScalarBarIfNotNeeded(color_map, view)
        
        # 清理资源
        Delete(reader)
        
        return True
    
    except Exception as e:
        print(f"处理文件时出错: {file_path}")
        print(f"错误信息: {str(e)}")
        import traceback
        traceback.print_exc()
        return False

def find_e_files(studies_dir):
    """
    查找所有Exodus结果文件
    
    Args:
        studies_dir: 研究目录路径
        
    Returns:
        list: 发现的文件路径列表
    """
    result = []
    
    # 遍历所有子目录
    for case_dir in os.listdir(studies_dir):
        case_path = os.path.join(studies_dir, case_dir)
        if not os.path.isdir(case_path):
            continue
        
        # 查找.e文件
        e_files = glob.glob(os.path.join(case_path, "*.e"))
        result.extend(e_files)
    
    return result

def main():
    """主函数"""
    start_time = time.time()
    args = parse_args()
    
    # 创建路径配置
    path_config = create_path_config(args)
    
    # 如果未指定studies_dir，使用默认值
    if args.studies_dir is None:
        studies_dir = path_config['output_dir']
    else:
        studies_dir = args.studies_dir
    
    # 确保studies_dir存在
    if not os.path.exists(studies_dir):
        print(f"错误：参数研究目录不存在: {studies_dir}")
        return
    
    # 打印配置信息
    config = {
        'studies_dir': studies_dir,
        'env_name': args.env_name,
        'force_rebuild': args.force_rebuild,
        'target_times': args.target_times,
        'output_dir_name': args.output_dir_name,
    }
    print_config(config, "ParaView处理配置")
    
    # 设置ParaView环境
    print_header("ParaView环境设置")
    env_ready = setup_paraview_env(
        env_name=args.env_name, 
        force_recreate=args.force_rebuild
    )
    
    if not env_ready:
        print("❌ ParaView环境设置失败")
        return
    
    # 创建导出配置
    export_config = ExportConfig(
        target_times=args.target_times,
        field_list=[
            ('T', '温度(K)'),
            ('mechanical_strain_xx', '横向机械应变'),
            ('mechanical_strain_yy', '纵向机械应变'),
            ('mechanical_strain_zz', '轴向机械应变'),
            ('creep_strain_xx', '横向蠕变应变'),
            ('creep_strain_yy', '纵向蠕变应变'),
            ('creep_strain_zz', '轴向蠕变应变'),
            ('vonmises_stress', 'Mises应力(MPa)'),
            ('d', '相场损伤值'),
            ('disp_x', 'X位移(mm)'),
            ('disp_y', 'Y位移(mm)'),
            ('disp_z', 'Z位移(mm)'),
        ],
        image_size=[1642, 1083],
        output_dir_name=args.output_dir_name
    )
    
    # 查找所有结果文件
    print_header("查找结果文件")
    result_files = find_e_files(studies_dir)
    
    if not result_files:
        print("❌ 未找到.e结果文件")
        return
    
    # 打印找到的文件
    print_file_list(result_files, "发现的Exodus文件", max_files=10)
    
    # 处理所有文件
    print_header("开始处理结果文件")
    
    total_files = len(result_files)
    success_count = 0
    failed_count = 0
    
    for i, file_path in enumerate(result_files, 1):
        print(f"\n处理文件 ({i}/{total_files}): {os.path.basename(file_path)}")
        
        success = export_field_data(file_path, export_config)
        
        if success:
            print(f"✅ 成功处理: {os.path.basename(file_path)}")
            success_count += 1
        else:
            print(f"❌ 处理失败: {os.path.basename(file_path)}")
            failed_count += 1
        
        # 更新进度
        print_progress(i, total_files, prefix='总进度:', suffix=f'({i}/{total_files})', length=40)
    
    # 计算总运行时间
    elapsed_time = time.time() - start_time
    hours = int(elapsed_time // 3600)
    minutes = int((elapsed_time % 3600) // 60)
    seconds = int(elapsed_time % 60)
    
    # 打印摘要
    print_summary(success_count, failed_count, 0, elapsed_time)
    
    print(f"\n===== ParaView处理器已完成 =====")
    print(f"总文件数: {total_files}")
    print(f"成功处理: {success_count}")
    print(f"处理失败: {failed_count}")
    print(f"总运行时间: {hours}小时 {minutes}分钟 {seconds}秒")
    print(f"当前时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")

if __name__ == "__main__":
    main() 