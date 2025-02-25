#!/bin/bash

# 获取脚本所在目录
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

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
ENV_NAME="paraview_post"
ENV_EXISTS=$(conda env list | grep -w "$ENV_NAME" | wc -l)

# 添加强制重建参数处理
FORCE_RECREATE=false
if [[ $1 == "--force" ]]; then
    FORCE_RECREATE=true
    echo "强制重建环境..."
    conda deactivate 2> /dev/null
    conda env remove -n "$ENV_NAME" -y
    ENV_EXISTS=0
fi

# 创建测试脚本函数 - 验证ParaView环境
function test_paraview_import() {
    python -c "
try:
    from paraview.simple import *
    print('ParaView模块导入成功')
    exit(0)
except ImportError as e:
    print(f'导入错误: {str(e)}')
    exit(1)
"
    return $?
}

# 标记环境是否已验证
ENVIRONMENT_VERIFIED=false

if [ "$ENV_EXISTS" -eq 0 ] || [ "$FORCE_RECREATE" = true ]; then
    echo "创建新环境: $ENV_NAME..."
    conda create -y -n "$ENV_NAME" python=3.10
    conda activate "$ENV_NAME"
    
    # 使用mamba加速安装
    echo "安装mamba加速器..."
    conda install -y -c conda-forge mamba
    
    echo "安装ParaView及依赖库..."
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

# 5. 验证ParaView环境
echo "验证ParaView环境..."
if test_paraview_import; then
    ENVIRONMENT_VERIFIED=true
    echo "✅ ParaView环境验证成功"
else
    echo "❌ ParaView环境验证失败，尝试修复..."
    
    # 尝试修复安装
    echo "重新安装关键组件..."
    mamba install -y -c conda-forge paraview=5.11.1 vtk=9.2.5 --force-reinstall
    
    # 再次验证
    echo "再次验证环境..."
    if test_paraview_import; then
        ENVIRONMENT_VERIFIED=true
        echo "✅ 修复成功，ParaView环境已验证"
    else
        echo "❌ 环境修复失败，尝试完全重建环境..."
        
        # 完全重建环境
        conda deactivate 2> /dev/null
        conda env remove -n "$ENV_NAME" -y
        
        echo "从头创建环境..."
        conda create -y -n "$ENV_NAME" python=3.10
        conda activate "$ENV_NAME"
        
        # 使用官方渠道安装
        echo "使用更可靠的安装方式..."
        conda install -y -c conda-forge mamba
        mamba install -y -c conda-forge paraview=5.11.1
        
        # 最后验证
        echo "最终验证环境..."
        if test_paraview_import; then
            ENVIRONMENT_VERIFIED=true
            echo "✅ 环境重建成功"
        else
            echo "⚠️ 所有尝试均失败，请手动检查环境"
        fi
    fi
fi

# 6. 运行处理脚本
if [ "$ENVIRONMENT_VERIFIED" = true ]; then
    echo "执行处理脚本..."
    cd "$SCRIPT_DIR"
    python "$SCRIPT_DIR/step4_paraview_processor.py"
    echo "✅ 处理完成"
else
    echo "❌ 由于环境问题，处理脚本未能执行"
    exit 1
fi