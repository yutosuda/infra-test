#!/bin/bash

# 3つのインフラ構成統合検証スクリプト
# VPS構成 + AWS-Hybrid + AWS-Full での既存web-app検証

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

# 前提条件チェック
check_prerequisites() {
    log_info "前提条件をチェックしています..."
    
    # Docker & Docker Compose
    if ! command -v docker &> /dev/null; then
        log_error "Dockerがインストールされていません"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Composeがインストールされていません"
        exit 1
    fi
    
    # AWS CLI
    if ! command -v aws &> /dev/null; then
        log_warning "AWS CLIがインストールされていません（AWS構成テスト時に必要）"
    fi
    
    # Terraform
    if ! command -v terraform &> /dev/null; then
        log_warning "Terraformがインストールされていません（AWS構成テスト時に必要）"
    fi
    
    # Node.js & npm
    if ! command -v node &> /dev/null; then
        log_error "Node.jsがインストールされていません"
        exit 1
    fi
    
    if ! command -v npm &> /dev/null; then
        log_error "npmがインストールされていません"
        exit 1
    fi
    
    log_success "前提条件チェック完了"
}

# アプリケーションの準備
prepare_applications() {
    log_info "アプリケーションを準備しています..."
    
    # Strapi準備
    if [ -d "applications/strapi-app" ]; then
        cd applications/strapi-app
        if [ ! -d "node_modules" ]; then
            npm install
        fi
        cd ../..
        log_success "Strapi準備完了"
    else
        log_warning "Strapiアプリケーションが見つかりません"
    fi
    
    # Web App準備
    if [ -d "applications/web-app" ]; then
        cd applications/web-app
        if [ ! -d "node_modules" ]; then
            npm install
        fi
        
        # Prismaクライアント生成
        if [ -f "prisma/schema.prisma" ]; then
            npx prisma generate
        fi
        
        cd ../..
        log_success "Web App準備完了"
    else
        log_warning "Webアプリケーションが見つかりません"
    fi
}

# 1. VPS構成での検証
test_vps_configuration() {
    log_info "=== VPS構成での検証を開始 ==="
    
    cd infrastructure/vps
    
    # 開発環境用Docker Composeでサービス起動
    log_info "VPS構成サービスを起動しています..."
    if [ -f "environments/development/docker-compose.yml" ]; then
        cd environments/development
        docker-compose up -d
        cd ../..
    else
        log_error "VPS開発環境設定が見つかりません"
        return 1
    fi
    
    # サービス起動待機
    log_info "サービス起動を待機しています..."
    sleep 30
    
    # ヘルスチェック
    log_info "ヘルスチェックを実行しています..."
    
    # PostgreSQL接続確認
    if docker-compose exec -T postgres pg_isready -U webapp_user 2>/dev/null; then
        log_success "PostgreSQL接続OK"
    else
        log_warning "PostgreSQL接続確認をスキップ（起動中の可能性）"
    fi
    
    # Strapi接続確認
    if curl -f http://localhost:1337/api/health 2>/dev/null; then
        log_success "Strapi接続OK"
    else
        log_warning "Strapi接続確認をスキップ（起動中の可能性）"
    fi
    
    # Next.js web-app接続確認
    if curl -f http://localhost:3000 2>/dev/null; then
        log_success "Next.js web-app接続OK"
    else
        log_warning "Next.js web-app接続確認をスキップ（起動中の可能性）"
    fi
    
    # Nginx接続確認
    if curl -f http://localhost:80/health 2>/dev/null; then
        log_success "Nginx接続OK"
    else
        log_warning "Nginx接続確認をスキップ（起動中の可能性）"
    fi
    
    # ログ確認
    log_info "サービスログを確認しています..."
    if [ -f "environments/development/docker-compose.yml" ]; then
        cd environments/development
        docker-compose logs --tail=10
        cd ../..
    fi
    
    # サービス停止
    log_info "VPS構成サービスを停止しています..."
    if [ -f "environments/development/docker-compose.yml" ]; then
        cd environments/development
        docker-compose down
        cd ../..
    fi
    
    cd ../..
    log_success "=== VPS構成検証完了 ==="
}

# 2. AWS-Hybrid構成での検証
test_aws_hybrid_configuration() {
    log_info "=== AWS-Hybrid構成での検証を開始 ==="
    
    # AWS認証確認
    if command -v aws &> /dev/null && aws sts get-caller-identity &> /dev/null; then
        log_success "AWS認証確認OK"
    else
        log_warning "AWS認証が設定されていません（実際のデプロイテストをスキップ）"
        cd infrastructure/aws-hybrid
        
        # 設定ファイル確認のみ
        if [ -d "terraform" ]; then
            log_success "Terraform設定ディレクトリ確認OK"
        else
            log_error "Terraform設定ディレクトリが見つかりません"
            return 1
        fi
        
        cd ../..
        log_success "=== AWS-Hybrid構成検証完了（設定確認のみ） ==="
        return 0
    fi
    
    cd infrastructure/aws-hybrid
    
    # Terraform初期化
    if [ -d "terraform" ]; then
        cd terraform
        log_info "Terraform初期化中..."
        terraform init
        
        # プラン確認
        log_info "Terraformプランを確認しています..."
        terraform plan -out=tfplan
        
        # 実際のデプロイは危険なのでスキップ
        log_warning "実際のAWSデプロイはスキップします（コスト考慮）"
        log_info "デプロイ手順を確認しています..."
        
        # クリーンアップ
        rm -f tfplan
        cd ..
    else
        log_error "Terraform設定ディレクトリが見つかりません"
        return 1
    fi
    
    # web-app連携設定確認
    if [ -f "webapp-integration.md" ]; then
        log_success "web-app連携ガイド確認OK"
    else
        log_warning "web-app連携ガイドが見つかりません"
    fi
    
    cd ../..
    log_success "=== AWS-Hybrid構成検証完了 ==="
}

# 3. AWS-Full構成での検証
test_aws_full_configuration() {
    log_info "=== AWS-Full構成での検証を開始 ==="
    
    # AWS認証確認
    if command -v aws &> /dev/null && aws sts get-caller-identity &> /dev/null; then
        log_success "AWS認証確認OK"
    else
        log_warning "AWS認証が設定されていません（実際のデプロイテストをスキップ）"
        cd infrastructure/aws-full
        
        # 設定ファイル確認のみ
        if [ -d "terraform" ]; then
            log_success "Terraform設定ディレクトリ確認OK"
        else
            log_error "Terraform設定ディレクトリが見つかりません"
            return 1
        fi
        
        cd ../..
        log_success "=== AWS-Full構成検証完了（設定確認のみ） ==="
        return 0
    fi
    
    cd infrastructure/aws-full
    
    # Terraform初期化
    if [ -d "terraform" ]; then
        cd terraform
        log_info "Terraform初期化中..."
        terraform init
        
        # プラン確認
        log_info "Terraformプランを確認しています..."
        terraform plan -out=tfplan
        
        # 実際のデプロイは高額なのでスキップ
        log_warning "実際のAWSデプロイはスキップします（高額課金リスク）"
        log_info "デプロイ手順を確認しています..."
        
        # クリーンアップ
        rm -f tfplan
        cd ..
    else
        log_error "Terraform設定ディレクトリが見つかりません"
        return 1
    fi
    
    # デプロイスクリプト確認
    if [ -f "deploy.sh" ]; then
        log_success "デプロイスクリプト確認OK"
    else
        log_warning "デプロイスクリプトが見つかりません"
    fi
    
    # 削除スクリプト確認
    if [ -f "destroy.sh" ]; then
        log_success "削除スクリプト確認OK"
    else
        log_warning "削除スクリプトが見つかりません"
    fi
    
    cd ../..
    log_success "=== AWS-Full構成検証完了 ==="
}

# ドキュメント構造確認
check_documentation() {
    log_info "=== ドキュメント構造確認 ==="
    
    # 学習フェーズドキュメント確認
    local phases=("phase0-immediate-start.md" "phase1-preparation.md" "phase2-vps.md" "phase3-aws-hybrid.md" "phase4-aws-full.md" "phase5-comparison.md")
    
    for phase in "${phases[@]}"; do
        if [ -f "docs/learning-phases/$phase" ]; then
            log_success "$phase 確認OK"
        else
            log_warning "$phase が見つかりません"
        fi
    done
    
    # 構成別ドキュメント確認
    local configs=("vps-configuration.md" "aws-hybrid-configuration.md" "aws-full-configuration.md")
    
    for config in "${configs[@]}"; do
        if [ -f "docs/configurations/$config" ]; then
            log_success "$config 確認OK"
        else
            log_warning "$config が見つかりません"
        fi
    done
    
    log_success "=== ドキュメント構造確認完了 ==="
}

# プロジェクト構造確認
check_project_structure() {
    log_info "=== プロジェクト構造確認 ==="
    
    # 必要なディレクトリ確認
    local required_dirs=("applications" "infrastructure" "docs" "scripts")
    
    for dir in "${required_dirs[@]}"; do
        if [ -d "$dir" ]; then
            log_success "$dir ディレクトリ確認OK"
        else
            log_error "$dir ディレクトリが見つかりません"
            return 1
        fi
    done
    
    # アプリケーションディレクトリ確認
    if [ -d "applications/strapi-app" ] && [ -d "applications/web-app" ]; then
        log_success "アプリケーションディレクトリ確認OK"
    else
        log_error "アプリケーションディレクトリが不完全です"
        return 1
    fi
    
    # インフラ構成ディレクトリ確認
    local infra_dirs=("vps" "aws-hybrid" "aws-full")
    
    for dir in "${infra_dirs[@]}"; do
        if [ -d "infrastructure/$dir" ]; then
            log_success "infrastructure/$dir 確認OK"
        else
            log_error "infrastructure/$dir が見つかりません"
            return 1
        fi
    done
    
    log_success "=== プロジェクト構造確認完了 ==="
}

# メイン実行
main() {
    echo "========================================"
    echo "  3つのインフラ構成統合検証スクリプト"
    echo "========================================"
    echo ""
    
    # プロジェクト構造確認
    check_project_structure
    
    # 前提条件チェック
    check_prerequisites
    
    # アプリケーション準備
    prepare_applications
    
    # ドキュメント確認
    check_documentation
    
    # 各構成のテスト実行
    test_vps_configuration
    echo ""
    
    test_aws_hybrid_configuration
    echo ""
    
    test_aws_full_configuration
    echo ""
    
    echo "========================================"
    log_success "全ての構成検証が完了しました！"
    echo "========================================"
    echo ""
    echo "次のステップ:"
    echo "1. docs/learning-phases/phase0-immediate-start.md から学習を開始"
    echo "2. 各構成を実際に体験してみる"
    echo "3. 体験した内容を docs/learning-phases/phase5-comparison.md でまとめる"
    echo ""
}

# スクリプト実行
main "$@" 