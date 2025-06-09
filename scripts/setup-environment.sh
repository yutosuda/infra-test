#!/bin/bash

# インフラ構成体験学習プロジェクト環境セットアップスクリプト

set -e

# カラー出力設定
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ログ関数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# OS検出
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [ -f /etc/debian_version ]; then
            OS="debian"
        elif [ -f /etc/redhat-release ]; then
            OS="redhat"
        else
            OS="linux"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
        OS="windows"
    else
        OS="unknown"
    fi
    
    log_info "検出されたOS: $OS"
}

# Docker インストール
install_docker() {
    log_info "Dockerのインストール状況を確認しています..."
    
    if command -v docker &> /dev/null; then
        log_success "Docker は既にインストールされています"
        docker --version
        return 0
    fi
    
    log_info "Dockerをインストールしています..."
    
    case $OS in
        "debian")
            # Ubuntu/Debian
            sudo apt-get update
            sudo apt-get install -y ca-certificates curl gnupg lsb-release
            
            # Docker公式GPGキー追加
            sudo mkdir -p /etc/apt/keyrings
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
            
            # リポジトリ追加
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
            
            # Docker インストール
            sudo apt-get update
            sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
            
            # ユーザーをdockerグループに追加
            sudo usermod -aG docker $USER
            ;;
        "redhat")
            # CentOS/RHEL/Fedora
            sudo yum install -y yum-utils
            sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
            sudo yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
            sudo systemctl start docker
            sudo systemctl enable docker
            sudo usermod -aG docker $USER
            ;;
        "macos")
            log_warning "macOSでは Docker Desktop を手動でインストールしてください"
            log_info "https://docs.docker.com/desktop/mac/install/"
            return 1
            ;;
        *)
            log_error "サポートされていないOSです。手動でDockerをインストールしてください"
            return 1
            ;;
    esac
    
    log_success "Dockerのインストールが完了しました"
    log_warning "グループ変更を反映するため、一度ログアウト・ログインしてください"
}

# Docker Compose インストール
install_docker_compose() {
    log_info "Docker Composeのインストール状況を確認しています..."
    
    if command -v docker-compose &> /dev/null; then
        log_success "Docker Compose は既にインストールされています"
        docker-compose --version
        return 0
    fi
    
    # Docker Compose V2 (plugin) チェック
    if docker compose version &> /dev/null; then
        log_success "Docker Compose V2 (plugin) は既にインストールされています"
        docker compose version
        return 0
    fi
    
    log_info "Docker Composeをインストールしています..."
    
    case $OS in
        "debian"|"redhat"|"linux")
            # Linux用 Docker Compose インストール
            DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
            sudo curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
            sudo chmod +x /usr/local/bin/docker-compose
            ;;
        "macos")
            log_warning "macOSでは Docker Desktop に Docker Compose が含まれています"
            ;;
        *)
            log_error "サポートされていないOSです"
            return 1
            ;;
    esac
    
    log_success "Docker Composeのインストールが完了しました"
}

# Node.js インストール
install_nodejs() {
    log_info "Node.jsのインストール状況を確認しています..."
    
    if command -v node &> /dev/null; then
        NODE_VERSION=$(node --version)
        log_success "Node.js は既にインストールされています: $NODE_VERSION"
        
        # バージョンチェック (v18以上推奨)
        NODE_MAJOR=$(echo $NODE_VERSION | cut -d'.' -f1 | sed 's/v//')
        if [ "$NODE_MAJOR" -ge 18 ]; then
            log_success "Node.js バージョンは要件を満たしています"
            return 0
        else
            log_warning "Node.js v18以上を推奨します。現在: $NODE_VERSION"
        fi
    fi
    
    log_info "Node.js v20をインストールしています..."
    
    case $OS in
        "debian")
            # Ubuntu/Debian用 NodeSource リポジトリ
            curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
            sudo apt-get install -y nodejs
            ;;
        "redhat")
            # CentOS/RHEL/Fedora用 NodeSource リポジトリ
            curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -
            sudo yum install -y nodejs
            ;;
        "macos")
            if command -v brew &> /dev/null; then
                brew install node@20
            else
                log_warning "Homebrewがインストールされていません"
                log_info "https://nodejs.org/en/download/ から手動でインストールしてください"
                return 1
            fi
            ;;
        *)
            log_error "サポートされていないOSです"
            return 1
            ;;
    esac
    
    log_success "Node.jsのインストールが完了しました"
    node --version
    npm --version
}

# AWS CLI インストール
install_aws_cli() {
    log_info "AWS CLIのインストール状況を確認しています..."
    
    if command -v aws &> /dev/null; then
        log_success "AWS CLI は既にインストールされています"
        aws --version
        return 0
    fi
    
    log_info "AWS CLI v2をインストールしています..."
    
    case $OS in
        "debian"|"redhat"|"linux")
            # Linux用 AWS CLI v2
            curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
            unzip awscliv2.zip
            sudo ./aws/install
            rm -rf awscliv2.zip aws/
            ;;
        "macos")
            # macOS用 AWS CLI v2
            curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
            sudo installer -pkg AWSCLIV2.pkg -target /
            rm AWSCLIV2.pkg
            ;;
        *)
            log_error "サポートされていないOSです"
            return 1
            ;;
    esac
    
    log_success "AWS CLIのインストールが完了しました"
    aws --version
}

# Terraform インストール
install_terraform() {
    log_info "Terraformのインストール状況を確認しています..."
    
    if command -v terraform &> /dev/null; then
        log_success "Terraform は既にインストールされています"
        terraform version
        return 0
    fi
    
    log_info "Terraformをインストールしています..."
    
    case $OS in
        "debian")
            # Ubuntu/Debian用 HashiCorp リポジトリ
            wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
            echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
            sudo apt update && sudo apt install terraform
            ;;
        "redhat")
            # CentOS/RHEL/Fedora用 HashiCorp リポジトリ
            sudo yum install -y yum-utils
            sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
            sudo yum -y install terraform
            ;;
        "macos")
            if command -v brew &> /dev/null; then
                brew tap hashicorp/tap
                brew install hashicorp/tap/terraform
            else
                log_warning "Homebrewがインストールされていません"
                log_info "https://www.terraform.io/downloads から手動でインストールしてください"
                return 1
            fi
            ;;
        *)
            log_error "サポートされていないOSです"
            return 1
            ;;
    esac
    
    log_success "Terraformのインストールが完了しました"
    terraform version
}

# Git インストール確認
check_git() {
    log_info "Gitのインストール状況を確認しています..."
    
    if command -v git &> /dev/null; then
        log_success "Git は既にインストールされています"
        git --version
        return 0
    fi
    
    log_info "Gitをインストールしています..."
    
    case $OS in
        "debian")
            sudo apt-get update && sudo apt-get install -y git
            ;;
        "redhat")
            sudo yum install -y git
            ;;
        "macos")
            if command -v brew &> /dev/null; then
                brew install git
            else
                log_warning "Xcodeコマンドラインツールをインストールしてください: xcode-select --install"
            fi
            ;;
        *)
            log_error "サポートされていないOSです"
            return 1
            ;;
    esac
    
    log_success "Gitのインストールが完了しました"
}

# 追加ツールのインストール
install_additional_tools() {
    log_info "追加ツールをインストールしています..."
    
    case $OS in
        "debian")
            sudo apt-get update
            sudo apt-get install -y curl wget vim unzip jq htop
            ;;
        "redhat")
            sudo yum install -y curl wget vim unzip jq htop
            ;;
        "macos")
            if command -v brew &> /dev/null; then
                brew install curl wget vim jq htop
            fi
            ;;
    esac
    
    log_success "追加ツールのインストールが完了しました"
}

# 環境変数設定
setup_environment_variables() {
    log_info "環境変数を設定しています..."
    
    # .bashrc または .zshrc に追加
    SHELL_RC=""
    if [ -n "$ZSH_VERSION" ]; then
        SHELL_RC="$HOME/.zshrc"
    elif [ -n "$BASH_VERSION" ]; then
        SHELL_RC="$HOME/.bashrc"
    fi
    
    if [ -n "$SHELL_RC" ]; then
        # Docker Compose エイリアス設定
        if ! grep -q "alias dc=" "$SHELL_RC" 2>/dev/null; then
            echo "" >> "$SHELL_RC"
            echo "# Docker Compose エイリアス" >> "$SHELL_RC"
            echo "alias dc='docker-compose'" >> "$SHELL_RC"
            echo "alias dcup='docker-compose up -d'" >> "$SHELL_RC"
            echo "alias dcdown='docker-compose down'" >> "$SHELL_RC"
            echo "alias dclogs='docker-compose logs -f'" >> "$SHELL_RC"
        fi
        
        log_success "環境変数とエイリアスを設定しました"
        log_info "変更を反映するため、新しいターミナルを開くか 'source $SHELL_RC' を実行してください"
    fi
}

# プロジェクト固有の設定
setup_project() {
    log_info "プロジェクト固有の設定を行っています..."
    
    # アプリケーションの依存関係インストール
    if [ -d "applications/strapi-app" ]; then
        log_info "Strapiの依存関係をインストールしています..."
        cd applications/strapi-app
        npm install
        cd ../..
    fi
    
    if [ -d "applications/web-app" ]; then
        log_info "Web Appの依存関係をインストールしています..."
        cd applications/web-app
        npm install
        npx prisma generate
        cd ../..
    fi
    
    # スクリプトに実行権限付与
    chmod +x scripts/*.sh
    
    log_success "プロジェクト設定が完了しました"
}

# メイン実行
main() {
    echo "========================================"
    echo "  インフラ構成体験学習プロジェクト"
    echo "      環境セットアップスクリプト"
    echo "========================================"
    echo ""
    
    # OS検出
    detect_os
    
    # 基本ツールのインストール
    check_git
    install_nodejs
    install_docker
    install_docker_compose
    
    # AWS関連ツール（オプション）
    read -p "AWS関連ツール（AWS CLI, Terraform）をインストールしますか？ (y/N): " install_aws
    if [[ $install_aws =~ ^[Yy]$ ]]; then
        install_aws_cli
        install_terraform
    else
        log_info "AWS関連ツールのインストールをスキップしました"
        log_warning "AWS構成を体験する際は、後でインストールしてください"
    fi
    
    # 追加ツール
    install_additional_tools
    
    # 環境変数設定
    setup_environment_variables
    
    # プロジェクト設定
    setup_project
    
    echo ""
    echo "========================================"
    log_success "環境セットアップが完了しました！"
    echo "========================================"
    echo ""
    echo "次のステップ:"
    echo "1. 新しいターミナルを開くか、以下を実行してください:"
    echo "   source ~/.bashrc  (または source ~/.zshrc)"
    echo ""
    echo "2. 環境確認を実行してください:"
    echo "   ./scripts/test-all-configurations.sh"
    echo ""
    echo "3. 学習を開始してください:"
    echo "   docs/learning-phases/phase0-immediate-start.md"
    echo ""
    
    # インストール済みツールの確認
    echo "インストール済みツール:"
    command -v docker && echo "✅ Docker: $(docker --version)"
    command -v docker-compose && echo "✅ Docker Compose: $(docker-compose --version)"
    command -v node && echo "✅ Node.js: $(node --version)"
    command -v npm && echo "✅ npm: $(npm --version)"
    command -v git && echo "✅ Git: $(git --version)"
    command -v aws && echo "✅ AWS CLI: $(aws --version)"
    command -v terraform && echo "✅ Terraform: $(terraform version --short)"
    echo ""
}

# スクリプト実行
main "$@" 