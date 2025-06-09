# AWS全体構成（Strapi + Next.js）- 無料枠最適化版

## 概要

このディレクトリには、StrapiとNext.jsの両方をAWSで運用するためのインフラ構成が含まれています。AWS無料枠の制約を厳密に考慮し、コストを最小限に抑えながら本格的なWebアプリケーションを運用できる構成です。

## アーキテクチャ

### 全体構成図

```
Internet
    |
    v
[Elastic IP] ← 無料（インスタンスに割り当て時）
    |
    v
[EC2 t3.micro] ← 無料枠: 750時間/月
    |
    ├── Nginx (リバースプロキシ)
    ├── Strapi (ポート: 1337)
    ├── Next.js (ポート: 3000)
    └── CloudWatch Agent
    |
    v
[RDS PostgreSQL db.t3.micro] ← 無料枠: 750時間/月
    |
    v
[S3 Bucket] ← 無料枠: 5GB/月
```

### 主要コンポーネント

1. **EC2インスタンス (t3.micro)**
   - Amazon Linux 2023
   - Nginx（リバースプロキシ）
   - Node.js 20.x + pnpm
   - PM2（プロセス管理）
   - CloudWatch Agent

2. **RDS PostgreSQL (db.t3.micro)**
   - PostgreSQL 15.4
   - 20GB SSD ストレージ
   - 自動バックアップ（7日間）

3. **S3バケット**
   - Strapiアセット用
   - パブリック読み取り可能

4. **ネットワーク**
   - VPC（10.0.0.0/16）
   - パブリックサブネット（シングルAZ）
   - プライベートサブネット（RDS用、マルチAZ）
   - インターネットゲートウェイ

5. **セキュリティ**
   - セキュリティグループ（EC2、RDS）
   - IAMロール（S3アクセス、CloudWatch）

## 無料枠制約

### AWS無料枠の詳細

| サービス | 無料枠制限 | 本構成での使用量 | 注意点 |
|---------|-----------|----------------|--------|
| EC2 | t3.micro 750時間/月 | 744時間/月（24時間稼働） | ✅ 無料枠内 |
| RDS | db.t3.micro 750時間/月 | 744時間/月（24時間稼働） | ✅ 無料枠内 |
| EBS | 30GB/月 | 8GB | ✅ 無料枠内 |
| RDS Storage | 20GB | 20GB | ✅ 無料枠内 |
| S3 | 5GB/月 | 監視が必要 | ⚠️ 使用量監視 |
| CloudWatch | 5GB ログ/月 | 監視が必要 | ⚠️ 使用量監視 |
| データ転送 | 1GB/月 | 監視が必要 | ⚠️ 使用量監視 |

### コスト最適化のポイント

- **NAT Gateway不使用**: プライベートサブネットからのインターネットアクセスなし
- **シングルAZ構成**: 可用性よりもコストを優先
- **最小インスタンスサイズ**: t3.micro、db.t3.micro
- **詳細監視無効**: CloudWatchの詳細監視を無効化
- **バージョニング無効**: S3バケットのバージョニングを無効化

## 前提条件

### 必要なツール

- AWS CLI v2
- Terraform >= 1.0
- Bash（Linux/macOS/WSL）

### AWS設定

1. **AWS CLIの設定**
   ```bash
   aws configure
   ```

2. **必要な権限**
   - EC2フルアクセス
   - RDSフルアクセス
   - S3フルアクセス
   - IAMフルアクセス
   - CloudWatchフルアクセス
   - VPCフルアクセス

## デプロイ手順

### 1. 自動デプロイ（推奨）

```bash
# リポジトリのクローン
cd infrastructure/aws-all

# デプロイスクリプトの実行
chmod +x deploy.sh
./deploy.sh
```

### 2. 手動デプロイ

```bash
# Terraformディレクトリに移動
cd terraform

# 初期化
terraform init

# プラン確認
terraform plan

# デプロイ実行
terraform apply
```

### 3. デプロイ後の確認

```bash
# 出力値の確認
terraform output

# EC2インスタンスへのSSH接続
ssh -i ~/.ssh/aws-all-keypair.pem ec2-user@<PUBLIC_IP>

# アプリケーションログの確認
sudo tail -f /var/log/user-data.log
```

## アプリケーション設定

### Strapi設定

1. **管理者アカウント作成**
   ```
   http://<PUBLIC_IP>/admin
   ```

2. **S3プロバイダー設定**
   - Upload設定でAWS S3を選択
   - バケット名: terraform outputで確認
   - リージョン: ap-northeast-1

### Next.js設定

1. **環境変数確認**
   ```bash
   # EC2インスタンス内
   cat /opt/apps/webapp/.env.local
   ```

2. **Prismaデータベース設定**
   ```bash
   # EC2インスタンス内
   cd /opt/apps/webapp
   npx prisma migrate deploy
   ```

## 運用・監視

### ログ監視

```bash
# CloudWatchログの確認
aws logs describe-log-groups --log-group-name-prefix "/aws/ec2/aws-all-infra-test"

# リアルタイムログ監視
aws logs tail "/aws/ec2/aws-all-infra-test" --follow
```

### ヘルスチェック

```bash
# アプリケーションヘルスチェック
curl http://<PUBLIC_IP>/health

# 個別サービスチェック
curl http://<PUBLIC_IP>:3000  # Next.js
curl http://<PUBLIC_IP>:1337  # Strapi
```

### パフォーマンス監視

```bash
# EC2インスタンス内でのリソース監視
htop
df -h
free -h
```

## トラブルシューティング

### よくある問題

1. **EC2インスタンスが起動しない**
   ```bash
   # CloudWatchログを確認
   aws logs tail "/aws/ec2/aws-all-infra-test" --follow
   
   # EC2インスタンスのシステムログを確認
   aws ec2 get-console-output --instance-id <INSTANCE_ID>
   ```

2. **RDS接続エラー**
   ```bash
   # セキュリティグループの確認
   aws ec2 describe-security-groups --group-ids <RDS_SG_ID>
   
   # RDSエンドポイントの確認
   aws rds describe-db-instances --db-instance-identifier aws-all-infra-test-postgres
   ```

3. **S3アクセスエラー**
   ```bash
   # IAMロールの確認
   aws iam get-role --role-name aws-all-infra-test-ec2-role
   
   # S3バケットポリシーの確認
   aws s3api get-bucket-policy --bucket <BUCKET_NAME>
   ```

### デバッグコマンド

```bash
# EC2インスタンス内でのサービス状態確認
sudo systemctl status nginx
sudo -u appuser pm2 status

# アプリケーションログの確認
sudo tail -f /opt/apps/strapi/logs/strapi.log
sudo tail -f /opt/apps/webapp/logs/webapp.log
```

## セキュリティ

### 本番環境での推奨設定

1. **セキュリティグループの制限**
   ```hcl
   # variables.tfで設定
   variable "allowed_cidr_blocks" {
     default = ["YOUR_IP/32"]  # 特定IPのみ許可
   }
   
   variable "ssh_allowed_cidr_blocks" {
     default = ["YOUR_IP/32"]  # SSH接続を特定IPのみ許可
   }
   ```

2. **SSL/TLS証明書の設定**
   - AWS Certificate Manager
   - Let's Encrypt

3. **WAF設定**
   - AWS WAF v2
   - DDoS保護

## バックアップ・復旧

### 自動バックアップ

- **RDS**: 7日間の自動バックアップ
- **S3**: バージョニング無効（コスト削減のため）

### 手動バックアップ

```bash
# RDSスナップショット作成
aws rds create-db-snapshot \
  --db-instance-identifier aws-all-infra-test-postgres \
  --db-snapshot-identifier manual-snapshot-$(date +%Y%m%d)

# S3バケットの同期
aws s3 sync s3://<BUCKET_NAME> ./backup/
```

## スケーリング

### 垂直スケーリング

```hcl
# variables.tfで設定変更
variable "ec2_instance_type" {
  default = "t3.small"  # t3.microから変更（有料）
}

variable "db_instance_class" {
  default = "db.t3.small"  # db.t3.microから変更（有料）
}
```

### 水平スケーリング

- Application Load Balancer
- Auto Scaling Group
- RDS Read Replica

## リソース削除

### 自動削除（推奨）

```bash
chmod +x destroy.sh
./destroy.sh
```

### 手動削除

```bash
cd terraform
terraform destroy
```

### 削除後の確認

```bash
# 課金対象リソースの確認
aws ec2 describe-instances --query 'Reservations[*].Instances[?State.Name==`running`]'
aws rds describe-db-instances --query 'DBInstances[?DBInstanceStatus==`available`]'
aws ec2 describe-addresses --query 'Addresses[?AssociationId==null]'
```

## コスト監視

### AWS Cost Explorer

1. AWS コンソール → Cost Management → Cost Explorer
2. 日次コストの監視
3. サービス別コスト分析

### 予算アラート

```bash
# 予算作成（月額$5）
aws budgets create-budget \
  --account-id <ACCOUNT_ID> \
  --budget file://budget.json
```

## FAQ

### Q: 無料枠を超過した場合の対処法は？

A: 以下の手順で対処してください：
1. AWS Cost Explorerで超過原因を特定
2. 不要なリソースを削除
3. インスタンスサイズを縮小
4. データ転送量を削減

### Q: 本番環境での運用は可能？

A: 以下の制限があります：
- 単一障害点（シングルAZ）
- 限定的なリソース
- セキュリティ設定の強化が必要

### Q: 他のリージョンでの運用は？

A: `variables.tf`の`aws_region`を変更することで可能です。ただし、無料枠の適用条件を確認してください。

## 参考資料

- [AWS無料枠](https://aws.amazon.com/free/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Strapi Documentation](https://docs.strapi.io/)
- [Next.js Documentation](https://nextjs.org/docs)

## ライセンス

このプロジェクトはMITライセンスの下で公開されています。 