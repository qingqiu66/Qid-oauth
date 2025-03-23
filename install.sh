#!/bin/bash

# QID OAuth账号中心系统安装脚本
# 此脚本将自动下载、安装和配置QID OAuth账号中心系统

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印带颜色的信息
info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# 检查系统要求
check_requirements() {
    info "检查系统要求..."
    
    # 检测操作系统类型
    if [[ "$(uname)" == "Darwin" ]]; then
        OS_TYPE="macos"
        info "检测到MacOS系统"
    elif [[ -f /etc/debian_version ]]; then
        OS_TYPE="debian"
        info "检测到Debian/Ubuntu系统"
    elif [[ -f /etc/redhat-release ]]; then
        OS_TYPE="redhat"
        info "检测到RedHat/CentOS系统"
    else
        OS_TYPE="unknown"
        warning "未能确定操作系统类型，部分自动安装功能可能不可用"
    fi
    
    # 检查Node.js
    if ! command -v node &> /dev/null; then
        warning "未安装Node.js。需要Node.js v14.x或更高版本。"
        read -p "是否自动安装Node.js? (y/n): " install_node
        if [[ "$install_node" == "y" || "$install_node" == "Y" ]]; then
            install_nodejs
        else
            error "未安装Node.js。请安装Node.js v14.x或更高版本后再运行此脚本。"
        fi
    fi
    
    NODE_VERSION=$(node -v | cut -d 'v' -f 2)
    NODE_MAJOR=$(echo $NODE_VERSION | cut -d '.' -f 1)
    
    if [ "$NODE_MAJOR" -lt 14 ]; then
        warning "Node.js版本过低。当前版本: $NODE_VERSION, 需要: v14.x或更高版本。"
        read -p "是否自动更新Node.js? (y/n): " update_node
        if [[ "$update_node" == "y" || "$update_node" == "Y" ]]; then
            install_nodejs
        else
            error "Node.js版本过低。请更新Node.js后再运行此脚本。"
        fi
    fi
    
    # 检查npm
    if ! command -v npm &> /dev/null; then
        warning "未安装npm。需要npm v6.x或更高版本。"
        read -p "是否自动安装npm? (y/n): " install_npm
        if [[ "$install_npm" == "y" || "$install_npm" == "Y" ]]; then
            info "安装npm..."
            # npm通常随Node.js一起安装，如果单独安装npm，可能会导致版本不匹配
            install_nodejs
        else
            error "未安装npm。请安装npm v6.x或更高版本后再运行此脚本。"
        fi
    fi
    
    # 检查MongoDB
    if ! command -v mongod &> /dev/null; then
        warning "未检测到MongoDB。需要MongoDB v4.x或更高版本。"
        read -p "是否自动安装MongoDB? (y/n): " install_mongo
        if [[ "$install_mongo" == "y" || "$install_mongo" == "Y" ]]; then
            install_mongodb
        else
            read -p "MongoDB是否已安装并运行? (y/n): " mongo_installed
            if [[ "$mongo_installed" != "y" && "$mongo_installed" != "Y" ]]; then
                error "请安装并启动MongoDB后再运行此脚本。"
            fi
        fi
    fi
    
    # 检查unzip
    if ! command -v unzip &> /dev/null; then
        warning "未安装unzip。尝试安装..."
        if command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y unzip
        elif command -v yum &> /dev/null; then
            sudo yum install -y unzip
        else
            error "无法自动安装unzip。请手动安装后再运行此脚本。"
        fi
    fi
    
    success "系统要求检查完成。"
}

# 确保下载工具已安装
ensure_download_tools() {
    if ! command -v curl &> /dev/null && ! command -v wget &> /dev/null; then
        warning "未安装curl或wget。尝试安装curl..."
        
        case "$OS_TYPE" in
            debian)
                info "使用apt安装curl..."
                sudo apt-get update && sudo apt-get install -y curl
                ;;
            redhat)
                info "使用yum安装curl..."
                sudo yum install -y curl
                ;;
            macos)
                if command -v brew &> /dev/null; then
                    info "使用Homebrew安装curl..."
                    brew install curl
                else
                    info "安装Homebrew..."
                    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
                    brew install curl
                fi
                ;;
            *)
                error "无法自动安装curl或wget。请手动安装后再运行此脚本。"
                ;;
        esac
    fi
    
    # 验证安装
    if command -v curl &> /dev/null || command -v wget &> /dev/null; then
        success "下载工具已准备就绪。"
    else
        error "下载工具安装失败，请手动安装curl或wget。"
    fi
}

# 下载项目
download_project() {
    info "准备下载项目..."
    
    # 确保curl或wget已安装
    ensure_download_tools
    
    
    if [ -z "https://github.com/qingqiu66/Qid-oauth/releases/download/Qid/Qid.zip" ]; then
        error "下载URL不能为空。"
    fi
    
    # 设置安装目录
    read -p "请输入安装目录 [默认: ./qid-oauth]: " INSTALL_DIR
    INSTALL_DIR=${INSTALL_DIR:-"./qid-oauth"}
    
    # 创建安装目录
    mkdir -p "$INSTALL_DIR"
    
    # 下载项目
    info "正在从 $DOWNLOAD_URL 下载项目..."
    if command -v curl &> /dev/null; then
        curl -L "$DOWNLOAD_URL" -o "${INSTALL_DIR}/qid-oauth.zip"
    elif command -v wget &> /dev/null; then
        wget -O "${INSTALL_DIR}/qid-oauth.zip" "$DOWNLOAD_URL"
    else
        error "未安装curl或wget。请安装其中一个后再运行此脚本。"
    fi
    
    # 解压项目
    info "正在解压项目..."
    unzip -q "${INSTALL_DIR}/qid-oauth.zip" -d "${INSTALL_DIR}/temp"
    
    # 查找解压后的目录（通常是单个目录）
    EXTRACTED_DIR=$(find "${INSTALL_DIR}/temp" -mindepth 1 -maxdepth 1 -type d | head -n 1)
    
    if [ -z "$EXTRACTED_DIR" ]; then
        error "解压失败或ZIP文件结构不正确。"
    fi
    
    # 移动文件到安装目录
    mv "$EXTRACTED_DIR"/* "$INSTALL_DIR/"
    
    # 清理临时文件
    rm -rf "${INSTALL_DIR}/temp"
    rm -f "${INSTALL_DIR}/qid-oauth.zip"
    
    success "项目下载和解压完成。"
}

# 配置项目
configure_project() {
    info "配置项目..."
    
    cd "$INSTALL_DIR"
    
    # 配置MongoDB连接URI
    read -p "请输入MongoDB连接URI [默认: mongodb://localhost:27017/qid-oauth-prod]: " MONGO_URI
    MONGO_URI=${MONGO_URI:-"mongodb://localhost:27017/qid-oauth-prod"}
    
    # 配置JWT密钥
    read -p "请输入JWT密钥 [默认: 自动生成]: " JWT_SECRET
    JWT_SECRET=${JWT_SECRET:-$(openssl rand -hex 32)}
    
    # 配置OAuth令牌密钥
    read -p "请输入OAuth令牌密钥 [默认: 自动生成]: " OAUTH_SECRET
    OAUTH_SECRET=${OAUTH_SECRET:-$(openssl rand -hex 32)}
    
    # 更新配置文件
    info "更新配置文件..."
    
    # 确保config目录存在
    mkdir -p config
    
    # 创建或更新production.json配置文件
    cat > config/production.json << EOF
{
  "mongoURI": "$MONGO_URI",
  "jwtSecret": "$JWT_SECRET",
  "oauthTokenSecret": "$OAUTH_SECRET"
}
EOF
    
    success "项目配置完成。"
}

# 安装依赖
install_dependencies() {
    info "安装项目依赖..."
    
    # 安装后端依赖
    info "安装后端依赖..."
    npm install
    
    # 安装前端依赖
    info "安装前端依赖..."
    npm run client-install
    
    success "依赖安装完成。"
}

# 构建前端应用
build_frontend() {
    info "构建前端应用..."
    
    # 进入客户端目录并构建
    cd "$INSTALL_DIR"
    npm run build
    
    success "前端应用构建完成。"
}

# 设置PM2（如果需要）
setup_pm2() {
    info "设置PM2进程管理..."
    
    read -p "是否使用PM2管理应用? (y/n) [默认: y]: " USE_PM2
    USE_PM2=${USE_PM2:-"y"}
    
    if [[ "$USE_PM2" == "y" || "$USE_PM2" == "Y" ]]; then
        # 检查PM2是否已安装
        if ! command -v pm2 &> /dev/null; then
            info "安装PM2..."
            npm install -g pm2
        fi
        
        # 使用PM2启动应用
        cd "$INSTALL_DIR"
        pm2 start server.js --name "qid-oauth"
        
        # 设置PM2开机自启
        read -p "是否设置PM2开机自启? (y/n) [默认: y]: " PM2_STARTUP
        PM2_STARTUP=${PM2_STARTUP:-"y"}
        
        if [[ "$PM2_STARTUP" == "y" || "$PM2_STARTUP" == "Y" ]]; then
            pm2 startup
            pm2 save
        fi
        
        success "PM2设置完成。应用已启动。"
    else
        info "跳过PM2设置。您可以使用 'npm start' 手动启动应用。"
    fi
}

# 设置环境变量
setup_env() {
    info "设置环境变量..."
    
    # 创建.env文件
    cat > "$INSTALL_DIR/.env" << EOF
NODE_ENV=production
PORT=5000
EOF
    
    # 询问是否需要自定义端口
    read -p "是否需要自定义端口? (默认: 5000) (y/n): " CUSTOM_PORT
    
    if [[ "$CUSTOM_PORT" == "y" || "$CUSTOM_PORT" == "Y" ]]; then
        read -p "请输入端口号: " PORT_NUMBER
        if [[ -n "$PORT_NUMBER" ]]; then
            # 更新.env文件中的端口
            sed -i "s/PORT=5000/PORT=$PORT_NUMBER/" "$INSTALL_DIR/.env"
        fi
    fi
    
    success "环境变量设置完成。"
}

# 显示安装完成信息
show_completion_info() {
    PORT=$(grep PORT "$INSTALL_DIR/.env" | cut -d '=' -f 2)
    
    echo ""
    echo "====================================================="
    echo -e "${GREEN}QID OAuth账号中心系统安装完成!${NC}"
    echo "====================================================="
    echo ""
    echo "安装目录: $INSTALL_DIR"
    echo "应用端口: $PORT"
    echo ""
    echo "访问地址: http://localhost:$PORT"
    echo ""
    echo "管理命令:"
    
    if [[ "$USE_PM2" == "y" || "$USE_PM2" == "Y" ]]; then
        echo "  - 查看应用状态: pm2 status"
        echo "  - 查看应用日志: pm2 logs qid-oauth"
        echo "  - 重启应用: pm2 restart qid-oauth"
        echo "  - 停止应用: pm2 stop qid-oauth"
    else
        echo "  - 启动应用: cd $INSTALL_DIR && npm start"
    fi
    
    echo ""
    echo "如需进一步配置Nginx反向代理或SSL，请参考部署指南。"
    echo "====================================================="
}

# 安装Node.js
install_nodejs() {
    info "开始安装Node.js..."
    
    # 确保curl或wget已安装
    ensure_download_tools
    
    case "$OS_TYPE" in
        macos)
            if command -v brew &> /dev/null; then
                info "使用Homebrew安装Node.js..."
                brew install node@14
                brew link --force node@14
            else
                info "安装Homebrew..."
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
                brew install node@14
                brew link --force node@14
            fi
            ;;
        debian)
            info "使用apt安装Node.js..."
            curl -fsSL https://deb.nodesource.com/setup_14.x | sudo -E bash -
            sudo apt-get install -y nodejs
            ;;
        redhat)
            info "使用yum安装Node.js..."
            curl -fsSL https://rpm.nodesource.com/setup_14.x | sudo bash -
            sudo yum install -y nodejs
            ;;
        *)
            info "尝试使用NVM安装Node.js..."
            curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash
            export NVM_DIR="$HOME/.nvm"
            [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
            nvm install 14
            nvm use 14
            ;;
    esac
    
    # 验证安装
    if command -v node &> /dev/null; then
        NODE_VERSION=$(node -v)
        success "Node.js安装成功，版本: $NODE_VERSION"
    else
        error "Node.js安装失败，请手动安装。"
    fi
}

# 安装MongoDB
install_mongodb() {
    info "开始安装MongoDB..."
    
    case "$OS_TYPE" in
        macos)
            if command -v brew &> /dev/null; then
                info "使用Homebrew安装MongoDB..."
                brew tap mongodb/brew
                brew install mongodb-community@4.4
                brew services start mongodb-community@4.4
            else
                info "安装Homebrew..."
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
                brew tap mongodb/brew
                brew install mongodb-community@4.4
                brew services start mongodb-community@4.4
            fi
            ;;
        debian)
            info "使用apt安装MongoDB..."
            wget -qO - https://www.mongodb.org/static/pgp/server-4.4.asc | sudo apt-key add -
            echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu $(lsb_release -cs)/mongodb-org/4.4 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.4.list
            sudo apt-get update
            sudo apt-get install -y mongodb-org
            sudo systemctl start mongod
            sudo systemctl enable mongod
            ;;
        redhat)
            info "使用yum安装MongoDB..."
            cat > /etc/yum.repos.d/mongodb-org-4.4.repo << EOF
[mongodb-org-4.4]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/\$releasever/mongodb-org/4.4/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-4.4.asc
EOF
            sudo yum install -y mongodb-org
            sudo systemctl start mongod
            sudo systemctl enable mongod
            ;;
        *)
            error "无法自动安装MongoDB。请手动安装MongoDB后再运行此脚本。"
            ;;
    esac
    
    # 验证安装
    if command -v mongod &> /dev/null; then
        MONGO_VERSION=$(mongod --version | grep "db version" | cut -d ' ' -f 3)
        success "MongoDB安装成功，版本: $MONGO_VERSION"
    else
        error "MongoDB安装失败，请手动安装。"
    fi
}

# 主函数
main() {
    echo ""
    echo "====================================================="
    echo -e "${BLUE}QID OAuth账号中心系统安装脚本${NC}"
    echo "====================================================="
    echo ""
    
    check_requirements
    download_project
    configure_project
    install_dependencies
    build_frontend
    setup_env
    setup_pm2
    show_completion_info
}

# 执行主函数
main