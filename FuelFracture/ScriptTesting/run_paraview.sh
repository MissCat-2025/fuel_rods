#!/bin/bash

# 获取脚本所在目录
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "=== ParaView数据处理 ==="

# 1. 检查系统ParaView
echo "1. 检查ParaView..."
if ! command -v pvpython &> /dev/null; then
    echo "未找到pvpython，正在安装ParaView..."
    sudo apt-get update
    sudo apt-get install -y paraview
fi

# 2. 运行脚本
echo "2. 运行处理脚本..."
cd "$SCRIPT_DIR"
pvpython paraview_processor.py

echo "完成" 