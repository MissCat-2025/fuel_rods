# MooseScripts/utils/error_handler.py

"""
错误处理模块
-----------
提供统一的错误处理机制

主要功能：
1. 自定义异常类
2. 错误处理和报告函数
3. 用户友好的错误信息
"""

import traceback
import sys

class MooseScriptError(Exception):
    """MooseScripts的基础异常类"""
    pass

class TemplateError(MooseScriptError):
    """模板处理错误"""
    pass

class ParameterError(MooseScriptError):
    """参数处理错误"""
    pass

class SimulationError(MooseScriptError):
    """仿真执行错误"""
    pass

class EnvironmentError(MooseScriptError):
    """环境设置错误"""
    pass

class PathError(MooseScriptError):
    """路径处理错误"""
    pass

def handle_error(error, verbose=False, exit_code=1):
    """
    集中处理错误
    
    Args:
        error (Exception): 捕获的异常
        verbose (bool): 是否显示详细信息
        exit_code (int): 退出代码，如果为None则不退出
        
    Returns:
        None
    """
    error_type = error.__class__.__name__
    error_msg = str(error)
    
    print(f"\n❌ {error_type}: {error_msg}")
    
    if verbose:
        traceback.print_exc()
    
    # 根据错误类型提供建议
    if isinstance(error, TemplateError):
        print("\n排查建议:")
        print("1. 检查模板文件路径是否正确")
        print("2. 确认模板文件格式是否为标准MOOSE输入格式")
        print("3. 尝试手动打开模板文件检查内容")
    elif isinstance(error, ParameterError):
        print("\n排查建议:")
        print("1. 检查参数名称是否与模板中变量名匹配")
        print("2. 确认参数值格式是否正确")
        print("3. 验证JSON格式是否有效")
    elif isinstance(error, SimulationError):
        print("\n排查建议:")
        print("1. 检查MOOSE可执行文件路径是否正确")
        print("2. 确认环境设置是否完善")
        print("3. 查看日志文件获取详细错误信息")
    elif isinstance(error, EnvironmentError):
        print("\n排查建议:")
        print("1. 检查conda环境是否正确激活")
        print("2. 确认所需软件包是否已安装")
        print("3. 尝试手动激活环境并测试")
    elif isinstance(error, PathError):
        print("\n排查建议:")
        print("1. 确保路径存在且有正确的访问权限")
        print("2. 检查路径中是否包含特殊字符")
        print("3. 尝试使用绝对路径而非相对路径")
    else:
        print("\n排查建议:")
        print("1. 检查命令行参数是否正确")
        print("2. 确认文件路径和权限")
        print("3. 检查系统资源是否足够")
    
    # 如果提供了退出代码，终止程序
    if exit_code is not None:
        sys.exit(exit_code)