#!/bin/bash

# AWS全体構成デプロイメントスクリプト
# 無料枠制約を厳密に確認し、安全にデプロイを実行

set -e

# 色付きログ関数
log_info() {
    echo -e "\033[1;34m[INFO]\033[0m $1"
}

log_warn() {
    echo -e "\033[1;33m[WARN]\033[0m $1"
}

log_error() {
    echo -e "\033[1;31m[ERROR]\033[0m $1"
}

log_success() {
    echo -e "\033[1;32m[SUCCESS]\033[0m $1"
}

# 設定
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/terraform"
PROJECT_NAME="aws-all-infra-test"
AWS_REGION="ap-northeast-1"

# 前提条件チェック
check_prerequisites() {
    log_info "前提条件をチェックしています..."
    
    # AWS CLI確認
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLIがインストールされていません"
        exit 1
    fi
    
    # Terraform確認
    if ! command -v terraform &> /dev/null; then
        log_error "Terraformがインストールされていません"
        exit 1
    fi
    
    # AWS認証確認
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS認証が設定されていません"
        log_info "aws configure を実行してください"
        exit 1
    fi
    
    # キーペア確認
    KEY_PAIR_NAME="aws-all-keypair"
    if ! aws ec2 describe-key-pairs --key-names "$KEY_PAIR_NAME" --region "$AWS_REGION" &> /dev/null; then
        log_warn "キーペア '$KEY_PAIR_NAME' が存在しません"
        log_info "キーペアを作成しますか? (y/n)"
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            create_key_pair
        else
            log_error "キーペアが必要です。手動で作成してください"
            exit 1
        fi
    fi
    
    log_success "前提条件チェック完了"
}

# キーペア作成
create_key_pair() {
    log_info "キーペアを作成しています..."
    
    # ローカルディレクトリ作成
    mkdir -p ~/.ssh
    
    # キーペア作成
    aws ec2 create-key-pair \
        --key-name "$KEY_PAIR_NAME" \
        --region "$AWS_REGION" \
        --query 'KeyMaterial' \
        --output text > ~/.ssh/${KEY_PAIR_NAME}.pem
    
    # 権限設定
    chmod 600 ~/.ssh/${KEY_PAIR_NAME}.pem
    
    log_success "キーペア作成完了: ~/.ssh/${KEY_PAIR_NAME}.pem"
}

# 無料枠制約チェック
check_free_tier_limits() {
    log_info "無料枠制約をチェックしています..."
    
    # 既存のEC2インスタンス確認
    RUNNING_INSTANCES=$(aws ec2 describe-instances \
        --region "$AWS_REGION" \
        --filters "Name=instance-state-name,Values=running" \
        --query 'Reservations[*].Instances[*].InstanceType' \
        --output text | wc -w)
    
    if [ "$RUNNING_INSTANCES" -gt 0 ]; then
        log_warn "既に $RUNNING_INSTANCES 個のEC2インスタンスが実行中です"
        log_warn "無料枠は750時間/月です。複数インスタンスの実行に注意してください"
    fi
    
    # 既存のRDSインスタンス確認
    RUNNING_RDS=$(aws rds describe-db-instances \
        --region "$AWS_REGION" \
        --query 'DBInstances[?DBInstanceStatus==`available`].DBInstanceClass' \
        --output text | wc -w)
    
    if [ "$RUNNING_RDS" -gt 0 ]; then
        log_warn "既に $RUNNING_RDS 個のRDSインスタンスが実行中です"
        log_warn "無料枠は750時間/月です。複数インスタンスの実行に注意してください"
    fi
    
    # S3バケット数確認
    BUCKET_COUNT=$(aws s3api list-buckets --query 'Buckets | length(@)')
    log_info "現在のS3バケット数: $BUCKET_COUNT"
    
    log_success "無料枠制約チェック完了"
}

# コスト見積もり表示
show_cost_estimate() {
    log_info "=== 無料枠使用量見積もり ==="
    echo "EC2 t3.micro: 750時間/月 (24時間稼働で31日 = 744時間)"
    echo "RDS db.t3.micro: 750時間/月 (24時間稼働で31日 = 744時間)"
    echo "EBS gp3 8GB: 30GB/月の無料枠内"
    echo "RDS ストレージ 20GB: 20GB/月の無料枠内"
    echo "S3 ストレージ: 5GB/月の無料枠内で監視が必要"
    echo "CloudWatch ログ: 5GB/月の無料枠内で監視が必要"
    echo "データ転送: 1GB/月の無料枠内で監視が必要"
    echo ""
    log_warn "注意: 無料枠を超過した場合は課金されます"
    echo ""
}

# Terraformプラン実行
terraform_plan() {
    log_info "Terraformプランを実行しています..."
    
    cd "$TERRAFORM_DIR"
    
    # 初期化
    terraform init
    
    # プラン実行
    terraform plan -out=tfplan
    
    log_success "Terraformプラン完了"
    log_info "プランファイル: $TERRAFORM_DIR/tfplan"
}

# Terraformアプライ実行
terraform_apply() {
    log_info "Terraformアプライを実行しています..."
    
    cd "$TERRAFORM_DIR"
    
    # アプライ実行
    terraform apply tfplan
    
    log_success "Terraformアプライ完了"
}

# デプロイ後の確認
post_deploy_check() {
    log_info "デプロイ後の確認を実行しています..."
    
    cd "$TERRAFORM_DIR"
    
    # 出力値取得
    PUBLIC_IP=$(terraform output -raw ec2_public_ip)
    WEB_APP_URL=$(terraform output -raw web_app_url)
    STRAPI_ADMIN_URL=$(terraform output -raw strapi_admin_url)
    SSH_COMMAND=$(terraform output -raw ssh_command)
    
    log_success "=== デプロイ完了 ==="
    echo "パブリックIP: $PUBLIC_IP"
    echo "Webアプリ: $WEB_APP_URL"
    echo "Strapi管理画面: $STRAPI_ADMIN_URL"
    echo "SSH接続: $SSH_COMMAND"
    echo ""
    
    log_info "=== 次のステップ ==="
    echo "1. EC2インスタンスの初期化完了を待つ (5-10分程度)"
    echo "2. Webアプリにアクセスして動作確認"
    echo "3. Strapi管理画面で初期設定"
    echo "4. CloudWatchでログ監視設定"
    echo ""
    
    log_warn "=== 重要な注意事項 ==="
    echo "- 無料枠の使用量を定期的に監視してください"
    echo "- 不要になったらリソースを削除してください (./destroy.sh)"
    echo "- セキュリティグループの設定を本番環境に合わせて調整してください"
}

# メイン処理
main() {
    log_info "=== AWS全体構成デプロイメント開始 ==="
    
    # 前提条件チェック
    check_prerequisites
    
    # 無料枠制約チェック
    check_free_tier_limits
    
    # コスト見積もり表示
    show_cost_estimate
    
    # 確認プロンプト
    log_info "デプロイを続行しますか? (y/n)"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        log_info "デプロイをキャンセルしました"
        exit 0
    fi
    
    # Terraformプラン
    terraform_plan
    
    # 最終確認
    log_info "Terraformプランを確認しました。アプライを実行しますか? (y/n)"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        log_info "デプロイをキャンセルしました"
        exit 0
    fi
    
    # Terraformアプライ
    terraform_apply
    
    # デプロイ後確認
    post_deploy_check
    
    log_success "=== AWS全体構成デプロイメント完了 ==="
}

# スクリプト実行
main "$@" 