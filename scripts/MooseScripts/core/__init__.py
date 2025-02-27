# MooseScripts/core/__init__.py

"""
核心功能模块
-----------
MooseScripts的核心功能实现

包含:
1. file_io - 文件IO操作
2. path_manager - 路径管理
3. param_handler - 参数处理
4. env_manager - 环境管理
"""

# 导出关键接口
from .file_io import (
    read_file, write_file, extract_end_time, 
    add_checkpoint_to_outputs, rename_and_cleanup_files
)
from .path_manager import (
    resolve_base_dir, resolve_output_dir, ensure_path_exists, 
    find_template_files, detect_moose_input_files
)
from .param_handler import (
    parse_json_parameter, generate_parameter_combinations, 
    generate_case_name, replace_parameters, 
    generate_header, format_scientific
)

__all__ = [
    # 文件IO
    'read_file', 'write_file', 'extract_end_time', 
    'add_checkpoint_to_outputs', 'rename_and_cleanup_files',
    # 路径管理
    'resolve_base_dir', 'resolve_output_dir', 'ensure_path_exists',
    'find_template_files', 'detect_moose_input_files',
    # 参数处理
    'parse_json_parameter', 'generate_parameter_combinations',
    'generate_case_name', 'replace_parameters',
    'generate_header', 'format_scientific'
]