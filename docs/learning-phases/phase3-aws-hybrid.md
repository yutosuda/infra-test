# Phase 3: AWS-Hybrid構成体験

## 概要

この段階では、**Strapi専用AWS構成**を体験します。StrapiをAWS上にデプロイし、WebアプリはローカルまたはVercelで動作させるハイブリッド構成です。

## 🎯 学習目標

- **ハイブリッド構成の複雑さ**を実感する
- **ネットワーク分断**による課題を体験する
- **AWS基本サービス**の連携を理解する
- **セキュリティ設定**の重要性を実感する

## 📋 体験すべき観点

### セットアップ時の課題
- [ ] VPC・セキュリティグループ設定の複雑さ
- [ ] CORS設定の必要性
- [ ] SSL証明書の設定
- [ ] 環境変数の管理

### 運用時の課題
- [ ] ローカル⇔AWS間の通信遅延
- [ ] デバッグの困難さ（ログが分散）
- [ ] デプロイ手順の複雑化
- [ ] 環境差異による動作不具合

### コスト・セキュリティ
- [ ] AWS料金の発生パターン
- [ ] 公開範囲の設定ミス
- [ ] IAM権限の適切な設定
- [ ] データ転送料金の発生

## 🚀 実践手順

### 1. 前提条件確認

```bash
# AWS CLI設定確認
aws sts get-caller-identity

# Terraform確認
terraform version

# 必要な権限確認
aws iam get-user
```

### 2. AWS-Hybrid環境デプロイ

```bash
cd infrastructure/aws-hybrid

# Terraform初期化
terraform init

# プラン確認（重要：コストを事前確認）
terraform plan

# デプロイ実行
terraform apply
```

### 3. Strapi設定確認

```bash
# デプロイ後のURL取得
STRAPI_URL=$(terraform output -raw strapi_url)
echo "Strapi URL: $STRAPI_URL"

# Strapi管理画面アクセス
open $STRAPI_URL/admin
```

### 4. ローカルWebアプリ設定

```bash
cd ../../applications/web-app

# 環境変数設定
cat > .env.local << EOF
# AWS Strapi API
NEXT_PUBLIC_STRAPI_URL=$STRAPI_URL
STRAPI_API_TOKEN=your-strapi-api-token

# ローカルデータベース
DATABASE_URL=file:./prisma/dev.db

# NextAuth設定
NEXTAUTH_URL=http://localhost:3000
NEXTAUTH_SECRET=your-secret-here
EOF

# 依存関係インストール
npm install

# 開発サーバー起動
npm run dev
```

### 5. 統合テスト

```bash
# Strapi APIテスト
curl $STRAPI_URL/api/health

# WebアプリからAPI呼び出しテスト
open http://localhost:3000
```

## 🔍 体験すべき「困ったこと」

### ネットワーク・セキュリティ関連
1. **CORS設定で詰まる**
   - ローカルからAWS APIを呼び出せない
   - ブラウザコンソールでCORSエラー

2. **セキュリティグループ設定ミス**
   - ポートが開いていない
   - IP制限が厳しすぎる

3. **SSL証明書の問題**
   - HTTPSでないとAPIが呼べない
   - 証明書の自動更新設定

### 開発・デバッグ関連
4. **環境差異による動作不具合**
   - ローカルで動くがAWSで動かない
   - 環境変数の設定ミス

5. **ログ確認の困難さ**
   - CloudWatchでログを見る手間
   - エラーの原因特定が困難

6. **デプロイ時間の長さ**
   - ECSタスクの起動に時間がかかる
   - 設定変更のたびに再デプロイ

### コスト関連
7. **予想外の課金**
   - RDSの最低料金
   - データ転送料金
   - ECSの実行時間課金

## 📊 パフォーマンス・コスト測定

### レスポンス時間測定
```bash
# ローカル→AWS API呼び出し時間
time curl $STRAPI_URL/api/health

# 複数回実行して平均を取る
for i in {1..10}; do
  time curl -s $STRAPI_URL/api/health > /dev/null
done
```

### コスト確認
```bash
# AWS Cost Explorer確認
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity MONTHLY \
  --metrics BlendedCost
```

## 🛠️ トラブルシューティング

### よくある問題と解決方法

1. **ECSタスクが起動しない**
   ```bash
   # タスク定義確認
   aws ecs describe-task-definition --task-definition strapi-task
   
   # サービス状態確認
   aws ecs describe-services --cluster strapi-cluster --services strapi-service
   ```

2. **RDS接続エラー**
   ```bash
   # セキュリティグループ確認
   aws ec2 describe-security-groups --group-ids sg-xxxxxxxxx
   
   # RDS状態確認
   aws rds describe-db-instances --db-instance-identifier strapi-db
   ```

3. **S3アクセス権限エラー**
   ```bash
   # バケットポリシー確認
   aws s3api get-bucket-policy --bucket strapi-assets-bucket
   
   # IAMロール確認
   aws iam get-role --role-name strapi-execution-role
   ```

## 📝 学習記録テンプレート

### 体験した困難
- **最も時間がかかった作業**: 
- **最も理解が困難だった概念**: 
- **予想外だった問題**: 

### コスト感覚
- **1日の運用コスト**: $
- **最もコストがかかるサービス**: 
- **コスト削減のアイデア**: 

### セキュリティ・運用
- **設定ミスしやすいポイント**: 
- **監視すべき項目**: 
- **障害時の対応手順**: 

## 🎯 次のステップ

Phase 3完了後は、[Phase 4: AWS-Full構成体験](phase4-aws-full.md)に進みます。

### 環境クリーンアップ

```bash
# リソース削除（重要：課金停止）
cd infrastructure/aws-hybrid
terraform destroy

# 確認
aws ecs list-clusters
aws rds describe-db-instances
```

---

**重要**: このフェーズでは実際にAWS料金が発生します。不要なリソースは必ず削除してください。 