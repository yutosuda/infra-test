#!/bin/bash

# AWS全体構成リソース削除スクリプト
# 安全にすべてのリソースを削除し、課金を停止

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
    
    # Terraformステート確認
    if [ ! -f "$TERRAFORM_DIR/terraform.tfstate" ]; then
        log_warn "Terraformステートファイルが見つかりません"
        log_warn "リソースが存在しない可能性があります"
    fi
    
    log_success "前提条件チェック完了"
}

# 現在のリソース確認
check_current_resources() {
    log_info "現在のリソースを確認しています..."
    
    cd "$TERRAFORM_DIR"
    
    if [ -f "terraform.tfstate" ]; then
        # Terraformで管理されているリソース一覧
        log_info "=== Terraformで管理されているリソース ==="
        terraform state list 2>/dev/null || log_warn "ステートファイルの読み込みに失敗しました"
        echo ""
    fi
    
    # EC2インスタンス確認
    log_info "=== EC2インスタンス ==="
    aws ec2 describe-instances \
        --region "$AWS_REGION" \
        --filters "Name=tag:Name,Values=${PROJECT_NAME}-*" "Name=instance-state-name,Values=running,stopped" \
        --query 'Reservations[*].Instances[*].[InstanceId,InstanceType,State.Name,Tags[?Key==`Name`].Value|[0]]' \
        --output table 2>/dev/null || log_warn "EC2インスタンスの確認に失敗しました"
    
    # RDSインスタンス確認
    log_info "=== RDSインスタンス ==="
    aws rds describe-db-instances \
        --region "$AWS_REGION" \
        --query 'DBInstances[?starts_with(DBInstanceIdentifier,`'${PROJECT_NAME}'`)].[DBInstanceIdentifier,DBInstanceClass,DBInstanceStatus]' \
        --output table 2>/dev/null || log_warn "RDSインスタンスの確認に失敗しました"
    
    # S3バケット確認
    log_info "=== S3バケット ==="
    aws s3api list-buckets \
        --query 'Buckets[?starts_with(Name,`'${PROJECT_NAME}'`)].[Name,CreationDate]' \
        --output table 2>/dev/null || log_warn "S3バケットの確認に失敗しました"
    
    echo ""
}

# S3バケットの事前クリーンアップ
cleanup_s3_buckets() {
    log_info "S3バケットをクリーンアップしています..."
    
    # プロジェクト関連のS3バケット一覧取得
    BUCKETS=$(aws s3api list-buckets \
        --query "Buckets[?starts_with(Name,'${PROJECT_NAME}')].Name" \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$BUCKETS" ]; then
        for bucket in $BUCKETS; do
            log_info "バケット '$bucket' をクリーンアップしています..."
            
            # バケット内のオブジェクトを削除
            aws s3 rm "s3://$bucket" --recursive 2>/dev/null || log_warn "バケット '$bucket' のオブジェクト削除に失敗しました"
            
            # バケットのバージョニング確認と削除
            aws s3api list-object-versions --bucket "$bucket" \
                --query 'Versions[].{Key:Key,VersionId:VersionId}' \
                --output text 2>/dev/null | while read key version_id; do
                if [ -n "$key" ] && [ -n "$version_id" ]; then
                    aws s3api delete-object --bucket "$bucket" --key "$key" --version-id "$version_id" 2>/dev/null || true
                fi
            done
            
            # 削除マーカーの削除
            aws s3api list-object-versions --bucket "$bucket" \
                --query 'DeleteMarkers[].{Key:Key,VersionId:VersionId}' \
                --output text 2>/dev/null | while read key version_id; do
                if [ -n "$key" ] && [ -n "$version_id" ]; then
                    aws s3api delete-object --bucket "$bucket" --key "$key" --version-id "$version_id" 2>/dev/null || true
                fi
            done
            
            log_success "バケット '$bucket' のクリーンアップ完了"
        done
    else
        log_info "クリーンアップ対象のS3バケットが見つかりません"
    fi
}

# Terraformによるリソース削除
terraform_destroy() {
    log_info "Terraformでリソースを削除しています..."
    
    cd "$TERRAFORM_DIR"
    
    # 初期化（必要に応じて）
    terraform init
    
    # 削除プラン作成
    log_info "削除プランを作成しています..."
    terraform plan -destroy -out=destroy.tfplan
    
    # 削除実行
    log_info "リソースを削除しています..."
    terraform apply destroy.tfplan
    
    log_success "Terraformによるリソース削除完了"
}

# 残存リソースの手動確認と削除
cleanup_remaining_resources() {
    log_info "残存リソースを確認しています..."
    
    # EC2インスタンス確認
    REMAINING_INSTANCES=$(aws ec2 describe-instances \
        --region "$AWS_REGION" \
        --filters "Name=tag:Name,Values=${PROJECT_NAME}-*" "Name=instance-state-name,Values=running,stopped" \
        --query 'Reservations[*].Instances[*].InstanceId' \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$REMAINING_INSTANCES" ]; then
        log_warn "残存EC2インスタンス: $REMAINING_INSTANCES"
        log_info "手動で削除しますか? (y/n)"
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            for instance_id in $REMAINING_INSTANCES; do
                log_info "インスタンス $instance_id を削除しています..."
                aws ec2 terminate-instances --instance-ids "$instance_id" --region "$AWS_REGION" 2>/dev/null || log_warn "インスタンス削除に失敗: $instance_id"
            done
        fi
    fi
    
    # RDSインスタンス確認
    REMAINING_RDS=$(aws rds describe-db-instances \
        --region "$AWS_REGION" \
        --query "DBInstances[?starts_with(DBInstanceIdentifier,'${PROJECT_NAME}')].DBInstanceIdentifier" \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$REMAINING_RDS" ]; then
        log_warn "残存RDSインスタンス: $REMAINING_RDS"
        log_info "手動で削除しますか? (y/n)"
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            for db_id in $REMAINING_RDS; do
                log_info "RDSインスタンス $db_id を削除しています..."
                aws rds delete-db-instance \
                    --db-instance-identifier "$db_id" \
                    --skip-final-snapshot \
                    --region "$AWS_REGION" 2>/dev/null || log_warn "RDS削除に失敗: $db_id"
            done
        fi
    fi
    
    # S3バケット確認
    REMAINING_BUCKETS=$(aws s3api list-buckets \
        --query "Buckets[?starts_with(Name,'${PROJECT_NAME}')].Name" \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$REMAINING_BUCKETS" ]; then
        log_warn "残存S3バケット: $REMAINING_BUCKETS"
        log_info "手動で削除しますか? (y/n)"
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            for bucket in $REMAINING_BUCKETS; do
                log_info "S3バケット $bucket を削除しています..."
                aws s3 rb "s3://$bucket" --force 2>/dev/null || log_warn "S3バケット削除に失敗: $bucket"
            done
        fi
    fi
}

# キーペア削除確認
cleanup_key_pair() {
    KEY_PAIR_NAME="aws-all-keypair"
    
    if aws ec2 describe-key-pairs --key-names "$KEY_PAIR_NAME" --region "$AWS_REGION" &> /dev/null; then
        log_info "キーペア '$KEY_PAIR_NAME' を削除しますか? (y/n)"
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            aws ec2 delete-key-pair --key-name "$KEY_PAIR_NAME" --region "$AWS_REGION"
            log_success "キーペア削除完了"
            
            # ローカルファイルも削除
            if [ -f ~/.ssh/${KEY_PAIR_NAME}.pem ]; then
                log_info "ローカルキーファイルも削除しますか? (y/n)"
                read -r response
                if [[ "$response" =~ ^[Yy]$ ]]; then
                    rm -f ~/.ssh/${KEY_PAIR_NAME}.pem
                    log_success "ローカルキーファイル削除完了"
                fi
            fi
        fi
    fi
}

# 最終確認
final_verification() {
    log_info "最終確認を実行しています..."
    
    # 課金対象リソースの確認
    log_info "=== 課金対象リソース確認 ==="
    
    # EC2インスタンス
    RUNNING_EC2=$(aws ec2 describe-instances \
        --region "$AWS_REGION" \
        --filters "Name=instance-state-name,Values=running" \
        --query 'Reservations[*].Instances[*].InstanceId' \
        --output text | wc -w)
    echo "実行中のEC2インスタンス: $RUNNING_EC2 個"
    
    # RDSインスタンス
    RUNNING_RDS=$(aws rds describe-db-instances \
        --region "$AWS_REGION" \
        --query 'DBInstances[?DBInstanceStatus==`available`].DBInstanceIdentifier' \
        --output text | wc -w)
    echo "実行中のRDSインスタンス: $RUNNING_RDS 個"
    
    # Elastic IP
    ALLOCATED_EIP=$(aws ec2 describe-addresses \
        --region "$AWS_REGION" \
        --query 'Addresses[?AssociationId==null].AllocationId' \
        --output text | wc -w)
    echo "未割り当てのElastic IP: $ALLOCATED_EIP 個"
    
    # NAT Gateway
    RUNNING_NAT=$(aws ec2 describe-nat-gateways \
        --region "$AWS_REGION" \
        --filter "Name=state,Values=available" \
        --query 'NatGateways[].NatGatewayId' \
        --output text | wc -w)
    echo "実行中のNAT Gateway: $RUNNING_NAT 個"
    
    echo ""
    
    if [ "$RUNNING_EC2" -eq 0 ] && [ "$RUNNING_RDS" -eq 0 ] && [ "$ALLOCATED_EIP" -eq 0 ] && [ "$RUNNING_NAT" -eq 0 ]; then
        log_success "主要な課金対象リソースは削除されています"
    else
        log_warn "一部の課金対象リソースが残存している可能性があります"
        log_warn "AWS コンソールで最終確認することをお勧めします"
    fi
}

# メイン処理
main() {
    log_info "=== AWS全体構成リソース削除開始 ==="
    
    # 前提条件チェック
    check_prerequisites
    
    # 現在のリソース確認
    check_current_resources
    
    # 削除確認
    log_warn "=== 重要な警告 ==="
    log_warn "この操作により、すべてのリソースが削除されます"
    log_warn "データは復旧できません"
    echo ""
    log_info "本当に削除を実行しますか? (yes/no)"
    read -r response
    if [[ ! "$response" == "yes" ]]; then
        log_info "削除をキャンセルしました"
        exit 0
    fi
    
    # S3バケットの事前クリーンアップ
    cleanup_s3_buckets
    
    # Terraformによるリソース削除
    terraform_destroy
    
    # 残存リソースの確認と削除
    cleanup_remaining_resources
    
    # キーペア削除確認
    cleanup_key_pair
    
    # 最終確認
    final_verification
    
    log_success "=== AWS全体構成リソース削除完了 ==="
    log_info "AWS コンソールで課金状況を確認することをお勧めします"
}

# スクリプト実行
main "$@" 