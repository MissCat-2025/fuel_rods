#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ParaView结果处理脚本 - 导出温度分布图像
使用方法：
1. 先运行: ./run_paraview.sh
2. 或直接: python paraview_processor.py (会自动调用run_paraview.sh)
"""

import os
import sys
import subprocess

def run_with_pvpython():
    """使用run_paraview.sh重新运行此脚本"""
    try:
        script_dir = os.path.dirname(os.path.abspath(__file__))
        run_script = os.path.join(script_dir, 'run_paraview.sh')
        
        if not os.path.exists(run_script):
            print("错误: 未找到run_paraview.sh")
            return False
            
        print("切换到正确环境...")
        subprocess.run(['bash', run_script], check=True)
        return True
        
    except subprocess.CalledProcessError as e:
        print(f"环境切换失败: {str(e)}")
        return False

def export_temperature(file_path, target_time=4.0):
    """导出指定时间的温度分布图像"""
    try:
        # 尝试导入paraview
        try:
            from paraview.simple import (OpenDataFile, GetActiveViewOrCreate, GetDisplayProperties,
                                       ColorBy, GetColorTransferFunction, GetOpacityTransferFunction,
                                       GetTransferFunction2D, GetAnimationScene, GetTimeKeeper,
                                       GetLayout, SaveScreenshot)
            import paraview.simple
            paraview.simple._DisableFirstRenderCameraReset()
        except ImportError:
            print("需要先运行run_paraview.sh")
            if run_with_pvpython():
                sys.exit(0)  # 成功切换环境后退出
            return False
        
        # 1. 读取文件
        print(f"读取文件: {os.path.basename(file_path)}")
        reader = OpenDataFile(file_path)
        if not reader:
            print("无法读取文件")
            return False
            
        # 2. 创建视图
        renderView1 = GetActiveViewOrCreate('RenderView')
        
        # 3. 获取显示属性
        display = GetDisplayProperties(reader, view=renderView1)
        
        # 4. 设置标量着色
        ColorBy(display, ('POINTS', 'T'))
        
        # 5. 重新缩放颜色范围
        display.RescaleTransferFunctionToDataRange(True, False)
        
        # 6. 显示颜色条
        display.SetScalarBarVisibility(renderView1, True)
        
        # 7. 获取颜色和不透明度传输函数
        tLUT = GetColorTransferFunction('T')
        tPWF = GetOpacityTransferFunction('T')
        tTF2D = GetTransferFunction2D('T')
        
        # 8. 设置动画时间
        animationScene1 = GetAnimationScene()
        animationScene1.AnimationTime = target_time
        
        # 9. 获取时间管理器
        timeKeeper1 = GetTimeKeeper()
        
        # 10. 重新缩放到当前数据范围
        display.RescaleTransferFunctionToDataRange(False, True)
        
        # 11. 获取布局并设置大小
        layout1 = GetLayout()
        layout1.SetSize(1642, 1083)
        
        # 12. 设置相机位置
        renderView1.CameraPosition = [0.0, 0.0, 0.03999187526517147]
        renderView1.CameraFocalPoint = [0.0, 0.0, 3e-05]
        renderView1.CameraParallelScale = 0.010342894396637723
        
        # 13. 保存截图
        output_dir = os.path.dirname(file_path)
        base_name = os.path.splitext(os.path.basename(file_path))[0]
        output_file = os.path.join(output_dir, f'{base_name}.png')
        
        SaveScreenshot(
            filename=output_file,
            viewOrLayout=renderView1,
            ImageResolution=[1642, 1083]
        )
        
        print(f"\n图像已保存: {output_file}")
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
        
    print(f"找到{len(e_files)}个文件")
    
    # 3. 处理第一个文件
    if export_temperature(e_files[0]):
        print("处理完成")
    else:
        print("处理失败")

if __name__ == "__main__":
    main()