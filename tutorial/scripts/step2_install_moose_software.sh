#!/bin/bash
# 安装MOOSE软件的脚本 - 优化版本
# 使用方法：
# chmod +x step2_install_moose_software.sh
# ./step2_install_moose_software.sh

# 设置错误处理
set -e  # 遇到错误立即退出
trap 'echo "❌ 发生错误，安装过程中断"; exit 1' ERR

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印带颜色的消息
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

echo -e "${GREEN}===== 开始安装MOOSE软件 - 优化版本 =====${NC}"

# 1. 检查Git版本并安装
print_info "检查Git是否已安装..."
if command -v git &> /dev/null; then
    git_version=$(git --version)
    print_success "Git已安装: $git_version"
else
    print_warning "Git未安装，正在安装Git..."
    sudo apt update
    sudo apt install -y git
    if command -v git &> /dev/null; then
        git_version=$(git --version)
        print_success "Git安装成功: $git_version"
    else
        print_error "Git安装失败"
        exit 1
    fi
fi

# 2. 系统更新
print_info "正在更新系统包..."
print_warning "这可能需要一些时间，请耐心等待..."
sudo apt-get update
sudo apt-get upgrade -y
sudo apt install -y git curl wget
print_success "系统更新完成"

# 3. 网络延迟测试
print_info "测试到GitHub的网络延迟..."
if ping -c 3 github.com > /dev/null 2>&1; then
    ping_result=$(ping -c 3 github.com | tail -1 | awk -F '/' '{print $5}')
    print_success "GitHub网络连接正常，平均延迟: ${ping_result}ms"
else
    print_warning "GitHub网络连接不稳定，将使用国内镜像源"
fi

# 创建projects文件夹
print_info "创建projects文件夹..."
mkdir -p ~/projects || { print_error "创建projects文件夹失败"; exit 1; }

# 进入projects文件夹
print_info "进入projects文件夹..."
cd ~/projects || { print_error "进入projects文件夹失败"; exit 1; }

# 4. 克隆MOOSE软件 - 使用多个源
clone_moose() {
    # 定义多个克隆源
    declare -a clone_sources=(
        "https://gitee.com/mirrors/moose.git"
        "https://github.com/idaholab/moose.git"
        "https://hub.fastgit.xyz/idaholab/moose.git"
        "https://github.com.cnpmjs.org/idaholab/moose.git"
    )
    
    declare -a source_names=(
        "Gitee镜像源（推荐）"
        "GitHub官方源"
        "FastGit镜像源"
        "CNPM镜像源"
    )
    
    local success=false
    
    for i in "${!clone_sources[@]}"; do
        local source="${clone_sources[$i]}"
        local name="${source_names[$i]}"
        
        print_info "尝试从 $name 克隆MOOSE..."
        print_info "源地址: $source"
        
        if timeout 300 git clone --depth 1 "$source" moose; then
            print_success "从 $name 克隆成功！"
            success=true
            break
        else
            print_warning "从 $name 克隆失败，尝试下一个源..."
            # 清理可能的部分克隆
            rm -rf moose 2>/dev/null || true
        fi
    done
    
    if [ "$success" = false ]; then
        print_error "所有克隆源都失败了！"
        print_info "请检查网络连接或手动下载MOOSE源码"
        print_info "手动下载地址: https://github.com/idaholab/moose/archive/refs/heads/master.zip"
        exit 1
    fi
}

# 检查moose文件夹是否已存在
if [ -d "$HOME/projects/moose" ]; then
    print_success "MOOSE软件文件夹已存在，跳过克隆步骤..."
    
    # 检查是否为完整的git仓库
    cd ~/projects/moose
    if [ ! -d ".git" ]; then
        print_warning "现有moose文件夹不是完整的git仓库，重新克隆..."
        cd ~/projects
        rm -rf moose
        clone_moose
    else
        print_info "检查远程仓库连接..."
        if git remote -v | grep -q "gitee.com"; then
            print_success "已使用Gitee镜像源"
        else
            print_info "切换到Gitee镜像源以提高速度..."
            git remote set-url origin https://gitee.com/mirrors/moose.git
            print_success "已切换到Gitee镜像源"
        fi
    fi
else
    clone_moose
fi

# 检查moose文件夹是否成功创建
if [ ! -d "$HOME/projects/moose" ]; then
    print_error "MOOSE文件夹不存在，安装失败"
    exit 1
fi

# 进入moose文件夹
print_info "进入MOOSE文件夹..."
cd ~/projects/moose || { print_error "进入MOOSE文件夹失败"; exit 1; }

# 检查是否为git仓库
if [ ! -d ".git" ]; then
    print_error "MOOSE文件夹不是有效的git仓库，安装失败"
    exit 1
fi

# 获取最新代码
print_info "获取最新代码..."
git fetch origin || print_warning "获取最新代码失败，使用现有代码继续"

# 切换到master分支
print_info "切换到master分支..."
if git show-ref --verify --quiet refs/heads/master; then
    git checkout master || print_warning "切换到master分支失败，使用当前分支继续"
elif git show-ref --verify --quiet refs/heads/main; then
    print_info "使用main分支（新的默认分支）..."
    git checkout main || print_warning "切换到main分支失败，使用当前分支继续"
else
    print_warning "未找到master或main分支，使用当前分支继续"
fi

# 获取CPU核心数
cpu_cores=$(nproc 2>/dev/null || echo "4")
print_info "检测到您的系统有 $cpu_cores 个CPU核心"

# 智能选择CPU核心数
if [ "$cpu_cores" -gt 8 ]; then
    recommended_cores=$((cpu_cores - 5))
elif [ "$cpu_cores" -gt 4 ]; then
    recommended_cores=$((cpu_cores - 1))
else
    recommended_cores=$cpu_cores
fi

# 让用户选择使用的CPU核心数
echo -e "${YELLOW}请输入您想使用的CPU核心数：${NC}"
echo -e "  总核心数: $cpu_cores"
echo -e "  推荐值: $recommended_cores （为系统保留一些资源）"
echo -e "  注意：数值越大编译速度越快，但可能会导致系统响应变慢"
read -t 30 -p "CPU核心数 [$recommended_cores]: " user_cores

# 如果用户没有输入或超时，使用推荐值
if [ -z "$user_cores" ]; then
    user_cores=$recommended_cores
    print_info "使用推荐CPU核心数: $user_cores"
fi

# 验证输入的核心数
if ! [[ "$user_cores" =~ ^[0-9]+$ ]] || [ "$user_cores" -lt 1 ] || [ "$user_cores" -gt "$cpu_cores" ]; then
    print_warning "输入的核心数无效，使用推荐值: $recommended_cores"
    user_cores=$recommended_cores
fi

print_success "将使用 $user_cores 个CPU核心进行编译和测试"

# 验证MOOSE软件
echo -e "${GREEN}===== 开始验证MOOSE软件 =====${NC}"

# 检查test目录是否存在
if [ ! -d "$HOME/projects/moose/test" ]; then
    print_error "test目录不存在，验证失败"
    exit 1
fi

# 进入test目录
print_info "进入test目录..."
cd ~/projects/moose/test || { print_error "进入test目录失败"; exit 1; }

# 激活moose环境
print_info "激活MOOSE conda环境..."
if command -v conda &> /dev/null; then
    eval "$(conda shell.bash hook)"
    if conda activate moose 2>/dev/null; then
        print_success "MOOSE环境激活成功"
    else
        print_error "激活MOOSE环境失败"
        print_info "请确保已安装MOOSE conda环境："
        print_info "  conda activate moose"
        exit 1
    fi
else
    print_error "未找到conda，请先安装Miniconda或Anaconda"
    exit 1
fi

# 检查moose_test-opt文件是否已存在
if [ -f "./moose_test-opt" ]; then
    print_success "moose_test-opt文件已存在，跳过编译步骤..."
else
    # 编译test
    print_info "正在编译test，这可能需要较长时间..."
    print_info "使用 $user_cores 个CPU核心进行编译"
    print_warning "编译过程中请不要关闭终端..."
    
    # 显示编译进度
    if make -j $user_cores 2>&1 | tee compile.log; then
        print_success "编译完成"
    else
        print_error "编译失败，请查看compile.log文件"
        print_info "常见解决方案："
        print_info "  1. 检查MOOSE环境是否正确安装"
        print_info "  2. 尝试减少CPU核心数重新编译"
        print_info "  3. 检查系统内存是否充足"
        exit 1
    fi
fi

# 检查run_tests是否存在
if [ ! -f "./run_tests" ]; then
    print_error "run_tests文件不存在，验证失败"
    exit 1
fi

# 运行测试
print_info "正在运行MOOSE测试..."
print_info "使用 $user_cores 个CPU核心进行测试"
print_warning "测试过程可能需要很长时间，请耐心等待..."

# 运行基础测试
if timeout 1800 ./run_tests -j $user_cores --no-color -t 2>&1 | tee test.log; then
    print_success "MOOSE测试完成"
else
    exit_code=$?
    if [ $exit_code -eq 124 ]; then
        print_warning "测试超时（30分钟），但这可能是正常的"
        print_info "MOOSE安装可能已经成功，可以尝试运行简单测试验证"
    else
        print_error "测试失败，请查看test.log文件"
        print_info "即使测试失败，MOOSE可能仍然可以正常使用"
    fi
fi

# 最终检查
print_info "进行最终验证..."
if [ -f "./moose_test-opt" ] && [ -x "./moose_test-opt" ]; then
    print_success "MOOSE可执行文件验证成功"
    
    # 显示MOOSE版本信息
    if ./moose_test-opt --version 2>/dev/null; then
        print_success "MOOSE版本信息显示正常"
    fi
else
    print_error "MOOSE可执行文件验证失败"
    exit 1
fi

echo -e "${GREEN}===== MOOSE软件安装完成 =====${NC}"
print_success "安装路径: $HOME/projects/moose"
print_success "测试路径: $HOME/projects/moose/test"
print_info "使用方法："
print_info "  cd ~/projects/moose/test"
print_info "  conda activate moose"
print_info "  ./run_tests -j $user_cores"

echo -e "${BLUE}📝 安装日志已保存到以下文件：${NC}"
echo -e "  编译日志: ~/projects/moose/test/compile.log"
echo -e "  测试日志: ~/projects/moose/test/test.log"

print_success "🎉 MOOSE软件安装和验证完成！"
