# AWS構成の準備 - アカウント作成とTerraform環境構築

## 🎯 **AWS学習の目的**
- クラウドインフラの複雑さを体験
- Infrastructure as Code (Terraform) の理解
- AWSサービス間の連携を学習
- スケーラビリティとコスト管理の実感

---

## 📋 **必要なアカウント・ツール**

### **1. AWSアカウント作成**

#### **🚨 重要な注意事項**
- **クレジットカード必須**
- **無料利用枠あり**（12ヶ月間）
- **課金に注意**（設定ミスで高額請求の可能性）
- **必ず請求アラート設定**

#### **申し込み手順**
1. **AWS公式サイト**: https://aws.amazon.com/jp/
2. **「無料でアカウント作成」**をクリック
3. **基本情報入力**:
   - メールアドレス
   - パスワード
   - AWSアカウント名（例: `your-name-infra-test`）
4. **連絡先情報**:
   - アカウントタイプ: **個人**
   - 住所、電話番号
5. **支払い情報**:
   - クレジットカード情報
   - 住所確認
6. **本人確認**:
   - 電話番号認証（SMS or 音声通話）
7. **サポートプラン**: **ベーシック（無料）**を選択

#### **アカウント作成後の初期設定**
```bash
# 1. ルートユーザーのMFA設定（必須）
# AWS Console → セキュリティ認証情報 → MFA

# 2. IAMユーザーの作成（推奨）
# IAM → ユーザー → ユーザーを追加
# ユーザー名: terraform-user
# アクセス権限: AdministratorAccess（学習用）

# 3. 請求アラートの設定（必須）
# Billing → Billing preferences → Receive Billing Alerts
```

---

### **2. Terraform環境構築**

#### **Terraformのインストール**
```bash
# WSL2 Ubuntu環境での手順

# 1. HashiCorp GPGキーを追加
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

# 2. リポジトリを追加
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list

# 3. パッケージリストを更新してインストール
sudo apt update && sudo apt install terraform

# 4. インストール確認
terraform version
# Terraform v1.6.x が表示されればOK
```

#### **AWS CLIのインストール**
```bash
# 1. AWS CLI v2をダウンロード
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"

# 2. 解凍してインストール
unzip awscliv2.zip
sudo ./aws/install

# 3. インストール確認
aws --version
# aws-cli/2.x.x が表示されればOK

# 4. 一時ファイルを削除
rm -rf awscliv2.zip aws/
```

---

### **3. AWS認証情報の設定**

#### **IAMユーザーのアクセスキー作成**
1. **AWS Console** → **IAM** → **ユーザー**
2. 作成した `terraform-user` をクリック
3. **セキュリティ認証情報** タブ
4. **アクセスキーを作成** → **コマンドラインインターフェイス (CLI)**
5. **アクセスキーID** と **シークレットアクセスキー** をメモ

#### **AWS CLIの設定**
```bash
# AWS認証情報を設定
aws configure

# 入力項目:
# AWS Access Key ID: [IAMユーザーのアクセスキーID]
# AWS Secret Access Key: [IAMユーザーのシークレットアクセスキー]  
# Default region name: ap-northeast-1
# Default output format: json

# 設定確認
aws sts get-caller-identity
# アカウントIDとユーザー情報が表示されればOK
```

---

### **4. 費用管理と安全対策**

#### **請求アラートの詳細設定**
```bash
# CloudWatch請求アラートの作成（AWS CLIで）

# 1. SNSトピックの作成
aws sns create-topic --name billing-alerts --region us-east-1

# 2. メール通知の設定
aws sns subscribe \
  --topic-arn arn:aws:sns:us-east-1:[ACCOUNT-ID]:billing-alerts \
  --protocol email \
  --notification-endpoint your-email@example.com \
  --region us-east-1

# 3. CloudWatchアラームの作成（月額$10で警告）
aws cloudwatch put-metric-alarm \
  --alarm-name "BillingAlarm" \
  --alarm-description "Billing alarm for AWS costs" \
  --metric-name EstimatedCharges \
  --namespace AWS/Billing \
  --statistic Maximum \
  --period 86400 \
  --threshold 10 \
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=Currency,Value=USD \
  --evaluation-periods 1 \
  --alarm-actions arn:aws:sns:us-east-1:[ACCOUNT-ID]:billing-alerts \
  --region us-east-1
```

#### **コスト最適化設定**
```bash
# 1. 使用していないリソースの自動停止設定
# EC2インスタンスの自動停止（夜間・週末）

# 2. 無料利用枠の監視
# AWS Budgets で無料利用枠の使用量を監視

# 3. リソースタグの設定
# すべてのリソースに Project:infra-test タグを付与
```

---

## 🏗️ **Terraform環境の準備**

### **プロジェクト構造の確認**
```bash
cd /home/suda/infra-test
tree infrastructure/aws-strapi-only/

# 以下の構造になっているはず:
# infrastructure/aws-strapi-only/
# └── terraform/
#     ├── main.tf
#     ├── variables.tf
#     └── outputs.tf (これから作成)
```

### **Terraform初期化**
```bash
cd infrastructure/aws-strapi-only/terraform

# Terraformの初期化
terraform init

# 設定ファイルの検証
terraform validate

# 実行計画の確認（まだ実行しない）
terraform plan
```

### **環境変数の設定**
```bash
# Terraform用の環境変数を設定
cat > terraform.tfvars << 'EOF'
# プロジェクト設定
project_name = "infra-test"
environment = "learning"

# ネットワーク設定
vpc_cidr = "10.0.0.0/16"
availability_zones = ["ap-northeast-1a", "ap-northeast-1c"]

# データベース設定
db_instance_class = "db.t3.micro"  # 無料利用枠
db_allocated_storage = 20          # 無料利用枠

# ECS設定
ecs_cpu = 256                      # 最小構成
ecs_memory = 512                   # 最小構成

# ドメイン設定（VPSで取得したドメインを使用）
domain_name = "your-domain.com"    # 実際のドメインに変更
EOF

# 機密情報用の環境変数
cat > .env << 'EOF'
# データベース認証情報
TF_VAR_db_username=strapiuser
TF_VAR_db_password=SecurePassword123!

# Strapi設定
TF_VAR_strapi_admin_jwt_secret=$(openssl rand -base64 32)
TF_VAR_strapi_api_token_salt=$(openssl rand -base64 32)
TF_VAR_strapi_jwt_secret=$(openssl rand -base64 32)
TF_VAR_strapi_app_keys=$(openssl rand -base64 32)
EOF

# 環境変数を読み込み
source .env
```

---

## 📊 **費用の目安**

### **AWS無料利用枠（12ヶ月間）**
- **EC2**: t2.micro インスタンス 750時間/月
- **RDS**: db.t2.micro インスタンス 750時間/月
- **S3**: 5GB ストレージ
- **ALB**: 750時間/月（条件付き）

### **学習期間の想定費用（1ヶ月）**
- **無料利用枠内**: $0
- **超過した場合**: $10-30/月
- **注意**: 設定ミスで高額になる可能性

### **コスト管理のベストプラクティス**
1. **毎日の費用確認**
2. **不要なリソースの即座削除**
3. **学習終了後の完全削除**

---

## ✅ **準備完了チェックリスト**

### **アカウント・認証**
- [ ] AWSアカウント作成完了
- [ ] MFA設定完了
- [ ] IAMユーザー作成完了
- [ ] アクセスキー作成・設定完了
- [ ] 請求アラート設定完了

### **開発環境**
- [ ] Terraform インストール完了
- [ ] AWS CLI インストール・設定完了
- [ ] AWS認証確認完了
- [ ] Terraformプロジェクト初期化完了

### **安全対策**
- [ ] 請求アラート設定
- [ ] 無料利用枠監視設定
- [ ] リソースタグ戦略決定

---

## 🎯 **準備完了後の学習フロー**

### **Phase 3-1: インフラ構築（1日目）**
1. Terraformでの基本インフラ作成
2. VPC、サブネット、セキュリティグループ
3. RDSデータベースの作成

### **Phase 3-2: アプリケーションデプロイ（2日目）**
1. ECRへのDockerイメージプッシュ
2. ECSサービスの作成
3. ALBの設定とドメイン接続

### **Phase 3-3: 運用と監視（3日目）**
1. CloudWatchでの監視設定
2. ログの確認と分析
3. スケーリングテスト

### **学習記録の準備**
```bash
# AWS学習記録セクションを追加
cat >> /home/suda/infra-test/learning-log.md << 'EOF'

## Phase 3: AWS構成体験

### 準備段階
- AWSアカウント作成日: [日付]
- 初期設定完了日: [日付]
- 想定月額費用: [金額]

### 環境情報
- AWSアカウントID: [アカウントID]
- 使用リージョン: ap-northeast-1
- Terraformバージョン: [バージョン]

### 準備で詰まったポイント
- [問題と解決方法]

### 費用管理
- 請求アラート設定: [設定内容]
- 日次費用確認: [確認方法]

---
EOF
```

---

## 🚨 **重要な注意事項**

### **セキュリティ**
- **アクセスキーの管理**: `.env` ファイルをGitにコミットしない
- **MFA必須**: ルートユーザーには必ずMFA設定
- **最小権限**: 学習後は不要な権限を削除

### **コスト管理**
- **毎日確認**: AWS Billing Dashboardで費用確認
- **即座削除**: 学習終了後はすべてのリソースを削除
- **アラート**: 想定外の費用が発生したら即座に調査

### **学習効率**
- **VPS体験後**: VPSでの手動作業を体験してからAWSに進む
- **段階的学習**: 一度にすべてを構築せず、段階的に進める
- **記録重要**: 設定内容と感想を詳細に記録

---

**準備が完了したら、実際のTerraform実行に進みましょう！** 