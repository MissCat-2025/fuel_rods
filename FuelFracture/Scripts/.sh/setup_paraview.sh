#!/bin/bash

# 解析命令行参数
function show_help {
    echo "使用方法: $0 [选项]"
    echo "选项:"
    echo "  --force              强制重建环境"
    echo "  --env-name NAME      指定环境名称 (默认: paraview_post)"
    echo "  --studies-dir DIR    指定研究结果目录"
    echo "  --base-dir DIR       指定基础目录"
    echo "  --target-times TIMES 指定目标时间点 (空格分隔的浮点数，如 '4.0 5.0 6.0')"
    echo "  --help               显示此帮助信息"
}

# 默认参数
ENV_NAME="paraview_post"
FORCE_RECREATE=false
PROCESSOR_ARGS=""

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case "$1" in
        --force)
            FORCE_RECREATE=true
            shift
            ;;
        --env-name)
            ENV_NAME="$2"
            shift 2
            ;;
        --studies-dir)
            PROCESSOR_ARGS="$PROCESSOR_ARGS --studies-dir $2"
            shift 2
            ;;
        --base-dir)
            PROCESSOR_ARGS="$PROCESSOR_ARGS --base-dir $2"
            shift 2
            ;;
        --target-times)
            # 获取目标时间参数
            times="$2"
            time_args=""
            for t in $times; do
                time_args="$time_args $t"
            done
            PROCESSOR_ARGS="$PROCESSOR_ARGS --target-times $time_args"
            shift 2
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            echo "错误: 未知选项 $1"
            show_help
            exit 1
            ;;
    esac
done

# 获取脚本所在目录
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PY_SCRIPT_DIR="$(dirname "$SCRIPT_DIR")/.py"  # Scripts/.py目录

# 检查paraview_processor.py是否存在
if [ ! -f "$PY_SCRIPT_DIR/paraview_processor.py" ]; then
    echo "错误: 未找到处理脚本 $PY_SCRIPT_DIR/paraview_processor.py"
    exit 1
fi

echo "=== ParaView专用环境配置 ==="

# 1. 检查conda安装
if ! command -v conda &> /dev/null; then
    echo "安装Miniconda..."
    wget -q https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O miniconda.sh
    bash miniconda.sh -b -p "$HOME/miniconda"
    rm miniconda.sh
    export PATH="$HOME/miniconda/bin:$PATH"
    source "$HOME/miniconda/etc/profile.d/conda.sh"
fi

# 2. 初始化conda
source "$HOME/miniconda/etc/profile.d/conda.sh" 2> /dev/null || source "$(conda info --base)/etc/profile.d/conda.sh"

# 3. 环境配置
ENV_EXISTS=$(conda env list | grep -w "$ENV_NAME" | wc -l)

# 处理强制重建参数
if [ "$FORCE_RECREATE" = true ]; then
    echo "强制重建环境..."
    conda deactivate 2> /dev/null
    conda env remove -n "$ENV_NAME" -y
    ENV_EXISTS=0
fi

if [ "$ENV_EXISTS" -eq 0 ]; then
    echo "创建新环境: $ENV_NAME..."
    conda create -y -n "$ENV_NAME" python=3.10
    conda activate "$ENV_NAME"
    
    # 使用mamba加速安装
    conda install -y -c conda-forge mamba
    mamba install -y -c conda-forge \
        paraview=5.11.1 \
        vtk=9.2.5 \
        numpy=1.24.4 \
        matplotlib=3.7.1 \
        h5py=3.9.0 \
        pandas=1.5.3 \
        scipy=1.10.1
        
    echo "环境创建完成"
else
    echo "使用现有环境: $ENV_NAME"
    conda activate "$ENV_NAME"
fi

# 4. 设置环境变量（仅在首次运行时需要）
if [ -z "$PARAVIEW_ENV_SET" ]; then
    echo "配置环境变量..."
    export PV_PYTHON_PATH="$CONDA_PREFIX/lib/python3.10/site-packages"
    export PV_LIB_PATH="$CONDA_PREFIX/lib"
    
    export PYTHONPATH="$PV_PYTHON_PATH:$PYTHONPATH"
    export LD_LIBRARY_PATH="$PV_LIB_PATH:$LD_LIBRARY_PATH"
    
    # 标记环境变量已设置
    export PARAVIEW_ENV_SET=1
fi

# 5. 运行处理脚本
echo "执行处理脚本..."
cd "$PY_SCRIPT_DIR"
python "$PY_SCRIPT_DIR/paraview_processor.py" $PROCESSOR_ARGS

echo "✅ 处理完成" 