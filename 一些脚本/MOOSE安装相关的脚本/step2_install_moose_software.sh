#!/bin/bash
# 安装MOOSE软件的脚本
# 先运行chmod +x install_moose_software.sh
# ./install_moose_software.sh

# 设置错误处理
set -e  # 遇到错误立即退出
trap 'echo "发生错误，安装过程中断"; exit 1' ERR

echo "===== 开始安装MOOSE软件 ====="

# 创建projects文件夹
echo "正在创建projects文件夹..."
mkdir -p ~/projects || { echo "创建projects文件夹失败"; exit 1; }

# 进入projects文件夹
echo "进入projects文件夹..."
cd ~/projects || { echo "进入projects文件夹失败"; exit 1; }

# 检查moose文件夹是否已存在
if [ -d "$HOME/projects/moose" ]; then
    echo "moose软件文件夹已存在，跳过克隆步骤..."
else
    # 克隆MOOSE软件
    echo "正在克隆MOOSE软件，这可能需要一段时间..."
    echo "如果克隆失败，请检查您的网络连接或尝试使用代理"
    git clone https://github.com/idaholab/moose.git || { echo "克隆MOOSE软件失败，请检查网络连接"; exit 1; }
fi

# 检查moose文件夹是否成功创建
if [ ! -d "$HOME/projects/moose" ]; then
    echo "moose文件夹不存在，安装失败"
    exit 1
fi

# 进入moose文件夹
echo "进入moose文件夹..."
cd ~/projects/moose || { echo "进入moose文件夹失败"; exit 1; }

# 检查是否为git仓库
if [ ! -d ".git" ]; then
    echo "moose文件夹不是有效的git仓库，安装失败"
    exit 1
fi

# 切换到master分支
echo "切换到master分支..."
git checkout master || { echo "切换到master分支失败"; exit 1; }

# 获取CPU核心数
cpu_cores=$(nproc 2>/dev/null || echo "6")
echo "检测到您的系统有 $cpu_cores 个CPU核心"

# 让用户选择使用的CPU核心数
echo "请输入您想使用的CPU核心数（建议值为CPU核心总数或略少，默认为6）："
echo "注意：数值越大编译速度越快，但可能会导致系统响应变慢"
read -t 30 -p "CPU核心数 [$cpu_cores]: " user_cores

# 如果用户没有输入或超时，使用默认值
if [ -z "$user_cores" ]; then
    if [ -n "$cpu_cores" ] && [ "$cpu_cores" -gt 0 ]; then
        user_cores=$cpu_cores
    else
        user_cores=6
    fi
    echo "使用默认CPU核心数: $user_cores"
fi

# 验证MOOSE软件
echo "===== 开始验证MOOSE软件 ====="

# 检查test目录是否存在
if [ ! -d "$HOME/projects/moose/test" ]; then
    echo "test目录不存在，验证失败"
    exit 1
fi

# 进入test目录
echo "进入test目录..."
cd ~/projects/moose/test || { echo "进入test目录失败"; exit 1; }


# 激活moose环境
echo "激活moose环境..."
eval "$(conda shell.bash hook)"
conda activate moose || { echo "激活moose环境失败，请现conda activate moose"; exit 1; }

# 检查moose_test-opt文件是否已存在
if [ -f "./moose_test-opt" ]; then
    echo "moose_test-opt文件已存在，跳过编译步骤..."
else
    # 编译test
    echo "正在编译test，这可能需要一段时间..."
    echo "使用 $user_cores 个CPU核心进行编译"
    make -j $user_cores || { echo "编译test失败"; exit 1; }
fi

# 检查run_tests是否存在
if [ ! -f "./run_tests" ]; then
    echo "run_tests文件不存在，验证失败"
    exit 1
fi

# 运行测试
echo "正在运行测试，这可能需要一段时间..."
echo "使用 $user_cores 个CPU核心进行测试"
./run_tests -j $user_cores || { echo "运行测试失败"; exit 1; }
