# Phase 4: AWS-Full構成体験

## 概要

この段階では、**フルAWS構成**を体験します。Strapi、Webアプリ、データベース、すべてをAWS上で動作させる本格的なクラウド構成です。

## 🎯 学習目標

- **フルクラウド構成の複雑さ**を実感する
- **AWSサービス間連携**の難しさを体験する
- **運用・監視の重要性**を理解する
- **コスト管理の困難さ**を実感する

## 📋 体験すべき観点

### セットアップ時の課題
- [ ] 多数のAWSサービス設定の複雑さ
- [ ] VPC・ネットワーク設計の重要性
- [ ] IAMロール・ポリシーの複雑な権限設定
- [ ] Load Balancer・Auto Scalingの設定

### 運用時の課題
- [ ] 分散ログの管理・監視
- [ ] 複数サービスの依存関係管理
- [ ] スケーリング設定の調整
- [ ] 障害時の影響範囲特定

### コスト・パフォーマンス
- [ ] 複数サービスによるコスト爆発
- [ ] リソース使用率の最適化
- [ ] 無駄なリソースの特定
- [ ] コスト予測の困難さ

## 🚀 実践手順

### 1. 前提条件確認

```bash
# AWS CLI設定確認
aws sts get-caller-identity

# 必要な権限確認（管理者権限推奨）
aws iam list-attached-user-policies --user-name $(aws sts get-caller-identity --query User.UserName --output text)

# Terraform確認
terraform version
```

### 2. AWS-Full環境デプロイ

```bash
cd infrastructure/aws-full

# Terraform初期化
terraform init

# プラン確認（重要：コストを事前確認）
terraform plan

# デプロイ実行（時間がかかります）
terraform apply
```

### 3. デプロイ状況確認

```bash
# ALB URL取得
ALB_URL=$(terraform output -raw alb_url)
echo "Application URL: $ALB_URL"

# ECSサービス状態確認
aws ecs describe-services \
  --cluster $(terraform output -raw ecs_cluster_name) \
  --services $(terraform output -raw ecs_service_name)

# RDS状態確認
aws rds describe-db-instances \
  --db-instance-identifier $(terraform output -raw rds_instance_id)
```

### 4. アプリケーション動作確認

```bash
# Strapi管理画面アクセス
open $ALB_URL/admin

# Webアプリアクセス
open $ALB_URL

# API動作確認
curl $ALB_URL/api/health
```

### 5. 監視・ログ確認

```bash
# CloudWatchログ確認
aws logs describe-log-groups

# ECSタスクログ確認
aws logs get-log-events \
  --log-group-name /ecs/strapi-task \
  --log-stream-name $(aws logs describe-log-streams \
    --log-group-name /ecs/strapi-task \
    --query 'logStreams[0].logStreamName' \
    --output text)
```

## 🔍 体験すべき「困ったこと」

### インフラ設定関連
1. **VPC・ネットワーク設定の複雑さ**
   - サブネット設計の重要性
   - セキュリティグループの依存関係
   - NATゲートウェイの必要性

2. **ECS設定の複雑さ**
   - タスク定義の細かい設定
   - サービス間通信の設定
   - Auto Scalingの適切な設定

3. **Load Balancer設定**
   - ヘルスチェック設定
   - ターゲットグループの設定
   - SSL証明書の設定

### 運用・監視関連
4. **ログ管理の困難さ**
   - 複数サービスのログが分散
   - ログの検索・フィルタリング
   - エラーの原因特定

5. **パフォーマンス監視**
   - CPU・メモリ使用率の監視
   - レスポンス時間の監視
   - データベース性能の監視

6. **障害対応の複雑さ**
   - 障害箇所の特定
   - 依存関係の把握
   - ロールバック手順

### コスト関連
7. **予想外のコスト発生**
   - ALBの固定費用
   - NATゲートウェイの料金
   - CloudWatchログの保存料金

## 📊 パフォーマンス・コスト測定

### パフォーマンステスト
```bash
# 負荷テスト（Apache Bench）
ab -n 1000 -c 10 $ALB_URL/api/health

# レスポンス時間測定
for i in {1..20}; do
  time curl -s $ALB_URL/api/health > /dev/null
done
```

### リソース使用率確認
```bash
# ECS CPU・メモリ使用率
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ServiceName,Value=$(terraform output -raw ecs_service_name) \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average
```

### コスト分析
```bash
# 日次コスト確認
aws ce get-cost-and-usage \
  --time-period Start=$(date -d '7 days ago' +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --granularity DAILY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE
```

## 🛠️ トラブルシューティング

### よくある問題と解決方法

1. **ECSタスクが起動しない**
   ```bash
   # タスク停止理由確認
   aws ecs describe-tasks \
     --cluster $(terraform output -raw ecs_cluster_name) \
     --tasks $(aws ecs list-tasks \
       --cluster $(terraform output -raw ecs_cluster_name) \
       --query 'taskArns[0]' --output text)
   ```

2. **ALBヘルスチェック失敗**
   ```bash
   # ターゲットグループ状態確認
   aws elbv2 describe-target-health \
     --target-group-arn $(terraform output -raw target_group_arn)
   ```

3. **RDS接続エラー**
   ```bash
   # RDSエンドポイント確認
   aws rds describe-db-instances \
     --db-instance-identifier $(terraform output -raw rds_instance_id) \
     --query 'DBInstances[0].Endpoint'
   ```

4. **高額課金の原因調査**
   ```bash
   # サービス別コスト確認
   aws ce get-cost-and-usage \
     --time-period Start=$(date -d '1 day ago' +%Y-%m-%d),End=$(date +%Y-%m-%d) \
     --granularity DAILY \
     --metrics BlendedCost \
     --group-by Type=DIMENSION,Key=SERVICE
   ```

## 📈 スケーリング・最適化実験

### Auto Scaling設定
```bash
# CPU使用率ベースのスケーリング
aws application-autoscaling register-scalable-target \
  --service-namespace ecs \
  --resource-id service/$(terraform output -raw ecs_cluster_name)/$(terraform output -raw ecs_service_name) \
  --scalable-dimension ecs:service:DesiredCount \
  --min-capacity 1 \
  --max-capacity 10

# スケーリングポリシー作成
aws application-autoscaling put-scaling-policy \
  --service-namespace ecs \
  --resource-id service/$(terraform output -raw ecs_cluster_name)/$(terraform output -raw ecs_service_name) \
  --scalable-dimension ecs:service:DesiredCount \
  --policy-name cpu-scaling-policy \
  --policy-type TargetTrackingScaling \
  --target-tracking-scaling-policy-configuration file://scaling-policy.json
```

### リソース最適化
```bash
# 未使用のEBSボリューム確認
aws ec2 describe-volumes \
  --filters Name=status,Values=available \
  --query 'Volumes[*].[VolumeId,Size,CreateTime]'

# 未使用のElastic IP確認
aws ec2 describe-addresses \
  --query 'Addresses[?AssociationId==null].[PublicIp,AllocationId]'
```

## 📝 学習記録テンプレート

### 体験した困難
- **最も複雑だった設定**: 
- **最も時間がかかったトラブル**: 
- **理解が困難だった概念**: 

### パフォーマンス・スケーラビリティ
- **負荷テスト結果**: 
- **ボトルネックとなった箇所**: 
- **スケーリング効果**: 

### コスト感覚
- **1日の運用コスト**: $
- **最もコストがかかるサービス**: 
- **コスト削減のアイデア**: 

### 運用・監視
- **監視すべき重要メトリクス**: 
- **障害時の対応手順**: 
- **改善すべき運用プロセス**: 

## 🎯 次のステップ

Phase 4完了後は、[Phase 5: 比較・まとめ](phase5-comparison.md)に進みます。

### 環境クリーンアップ

```bash
# リソース削除（重要：高額課金停止）
cd infrastructure/aws-full
terraform destroy

# 削除確認
aws ecs list-clusters
aws elbv2 describe-load-balancers
aws rds describe-db-instances
```

---

**重要**: このフェーズでは最も高額なAWS料金が発生します。実験終了後は必ずリソースを削除してください。 