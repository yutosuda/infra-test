# Phase 2: VPS構成体験 - 手動運用の大変さを肌で感じる

## このフェーズの目標

**VPS構成の「リアルな大変さ」を体験し、以下を肌感で理解する：**

1. **手動運用の煩雑さ**: OSの設定、セキュリティ、アップデート、監視
2. **スケーラビリティの限界**: リソース不足、単一障害点
3. **属人化リスク**: 設定の再現性、ドキュメント化の重要性
4. **セキュリティリスク**: 自分で全て管理することの責任と恐怖

**所要時間**: 2-3日（初心者の場合）

## 体験の流れ

### Day 1: セットアップの大変さを体験
- VPS環境の構築（Docker Composeでシミュレート）
- 手動設定の煩雑さを実感
- セキュリティ設定の複雑さを体験

### Day 2: 運用の面倒さを体験
- アプリケーションのデプロイ
- 監視・ログ確認の手動作業
- 障害対応の困難さを体験

### Day 3: スケールの限界を体験
- リソース不足の発生
- 手動スケールの困難さ
- 学習記録の整理

---

## Step 1: VPS環境のセットアップ（手動作業の煩雑さを体験）

### 1.1 事前準備

```bash
# プロジェクトルートに移動
cd /home/suda/infra-test

# VPS構成ディレクトリに移動
cd infrastructure/vps

# 現在の構成を確認
ls -la
```

### 1.2 SSL証明書の手動作成（VPSでの典型的な作業）

```bash
# SSL証明書用ディレクトリを作成
mkdir -p ssl

# 自己署名証明書を作成（本来はLet's Encryptを使用）
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout ssl/key.pem \
    -out ssl/cert.pem \
    -subj "/C=JP/ST=Tokyo/L=Tokyo/O=Test/CN=localhost"

# 権限設定（セキュリティ重要）
chmod 600 ssl/key.pem
chmod 644 ssl/cert.pem
```

**体験ポイント**: 
- 証明書の手動作成の面倒さ
- 権限設定を間違えるリスク
- 有効期限管理の必要性

### 1.3 データベース初期化スクリプトの作成

```bash
# データベース初期化用ディレクトリを作成
mkdir -p init-scripts

# 初期化スクリプトを作成
cat > init-scripts/01-init.sql << 'EOF'
-- Strapi用データベースの初期化
-- VPSでは手動でこれらの設定を行う必要がある

-- データベースが存在しない場合は作成
SELECT 'CREATE DATABASE strapi_db'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'strapi_db')\gexec

-- ユーザーの権限設定
GRANT ALL PRIVILEGES ON DATABASE strapi_db TO strapi_user;

-- 接続制限の設定
ALTER DATABASE strapi_db CONNECTION LIMIT 20;

-- ログ設定
ALTER SYSTEM SET log_statement = 'all';
ALTER SYSTEM SET log_min_duration_statement = 1000;

-- 設定の再読み込み
SELECT pg_reload_conf();
EOF
```

**体験ポイント**:
- データベース設定の手動管理
- セキュリティ設定の複雑さ
- 設定ミスのリスク

### 1.4 監視スクリプトの作成（VPSでの手動監視）

```bash
# 監視用スクリプトディレクトリを作成
mkdir -p scripts

# システム監視スクリプト
cat > scripts/monitor.sh << 'EOF'
#!/bin/bash
# VPS手動監視スクリプト
# 本来は24時間365日これを監視する必要がある

echo "=== システム監視レポート $(date) ==="

# CPU使用率
echo "--- CPU使用率 ---"
top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1

# メモリ使用率
echo "--- メモリ使用率 ---"
free -h

# ディスク使用率
echo "--- ディスク使用率 ---"
df -h

# Docker コンテナ状態
echo "--- コンテナ状態 ---"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# ネットワーク接続
echo "--- ネットワーク接続 ---"
netstat -tuln | grep -E ':(80|443|1337|3000|5432)'

# ログの最新エラー
echo "--- 最新エラーログ ---"
docker logs vps-strapi --tail 5 2>&1 | grep -i error || echo "エラーなし"
docker logs vps-webapp --tail 5 2>&1 | grep -i error || echo "エラーなし"

echo "=== 監視完了 ==="
EOF

chmod +x scripts/monitor.sh
```

**体験ポイント**:
- 手動監視の大変さ
- 24時間365日の監視責任
- 異常検知の困難さ

### 1.5 バックアップスクリプトの作成

```bash
# バックアップスクリプト
cat > scripts/backup.sh << 'EOF'
#!/bin/bash
# VPS手動バックアップスクリプト
# 失敗したら全てのデータが失われるリスク

BACKUP_DIR="/tmp/backups"
DATE=$(date +%Y%m%d_%H%M%S)

echo "=== バックアップ開始 $(date) ==="

# バックアップディレクトリ作成
mkdir -p $BACKUP_DIR

# データベースバックアップ
echo "データベースバックアップ中..."
docker exec vps-postgres pg_dump -U strapi_user strapi_db > $BACKUP_DIR/db_backup_$DATE.sql
if [ $? -eq 0 ]; then
    echo "✓ データベースバックアップ完了"
else
    echo "✗ データベースバックアップ失敗"
    exit 1
fi

# アップロードファイルのバックアップ
echo "アップロードファイルバックアップ中..."
docker cp vps-strapi:/opt/app/public/uploads $BACKUP_DIR/uploads_$DATE
if [ $? -eq 0 ]; then
    echo "✓ アップロードファイルバックアップ完了"
else
    echo "✗ アップロードファイルバックアップ失敗"
fi

# 設定ファイルのバックアップ
echo "設定ファイルバックアップ中..."
cp -r . $BACKUP_DIR/config_$DATE

# バックアップサイズ確認
echo "--- バックアップサイズ ---"
du -sh $BACKUP_DIR/*

echo "=== バックアップ完了 $(date) ==="
echo "バックアップ場所: $BACKUP_DIR"
EOF

chmod +x scripts/backup.sh
```

**体験ポイント**:
- バックアップの手動管理
- 失敗時のリスク
- ストレージ容量の管理

---

## Step 2: アプリケーションのデプロイ（手動作業の体験）

### 2.1 環境変数の設定

```bash
# 環境変数ファイルを作成
cat > .env << 'EOF'
# VPS環境用の環境変数
# 本来はより安全な方法で管理すべき

# データベース設定
POSTGRES_DB=strapi_db
POSTGRES_USER=strapi_user
POSTGRES_PASSWORD=strapi_password

# Strapi設定
NODE_ENV=production
DATABASE_CLIENT=postgres
DATABASE_HOST=postgres
DATABASE_PORT=5432
DATABASE_NAME=strapi_db
DATABASE_USERNAME=strapi_user
DATABASE_PASSWORD=strapi_password
DATABASE_SSL=false

# セキュリティキー（本来はランダム生成）
JWT_SECRET=your-jwt-secret-key-change-this-in-production
ADMIN_JWT_SECRET=your-admin-jwt-secret-change-this-in-production
APP_KEYS=key1,key2,key3,key4
API_TOKEN_SALT=your-api-token-salt
TRANSFER_TOKEN_SALT=your-transfer-token-salt

# Next.js設定
NEXT_PUBLIC_STRAPI_URL=http://localhost:1337
EOF
```

**体験ポイント**:
- 環境変数の手動管理
- セキュリティキーの生成・管理
- 設定ミスのリスク

### 2.2 アプリケーションのビルドとデプロイ

```bash
# まず、Strapiアプリケーションを準備
cd ../../strapi-app

# Strapiアプリケーションが存在しない場合は作成
if [ ! -f "package.json" ]; then
    echo "Strapiアプリケーションを作成中..."
    npx create-strapi-app@latest . --quickstart --no-run
fi

# プロダクション用の設定を追加
cat > config/database.js << 'EOF'
module.exports = ({ env }) => ({
  connection: {
    client: 'postgres',
    connection: {
      host: env('DATABASE_HOST', 'localhost'),
      port: env.int('DATABASE_PORT', 5432),
      database: env('DATABASE_NAME', 'strapi'),
      user: env('DATABASE_USERNAME', 'strapi'),
      password: env('DATABASE_PASSWORD', 'strapi'),
      ssl: env.bool('DATABASE_SSL', false),
    },
  },
});
EOF

# VPS構成ディレクトリに戻る
cd ../infrastructure/vps

# Docker Composeでサービスを起動
echo "=== VPS環境の起動開始 ==="
docker-compose up -d

# 起動状況を確認
echo "=== 起動状況確認 ==="
docker-compose ps
```

**体験ポイント**:
- 手動でのサービス起動
- 依存関係の管理
- 起動順序の制御

### 2.3 手動での動作確認

```bash
# サービスの起動を待機
echo "サービスの起動を待機中..."
sleep 30

# 各サービスの動作確認
echo "=== 動作確認 ==="

# PostgreSQL接続確認
echo "PostgreSQL接続確認..."
docker exec vps-postgres pg_isready -U strapi_user -d strapi_db

# Strapi起動確認
echo "Strapi起動確認..."
curl -f http://localhost:1337/_health || echo "Strapi未起動"

# Webアプリ起動確認
echo "Webアプリ起動確認..."
curl -f http://localhost:3000 || echo "Webアプリ未起動"

# Nginx起動確認
echo "Nginx起動確認..."
curl -f http://localhost:80 || echo "Nginx未起動"
```

**体験ポイント**:
- 手動での動作確認の必要性
- 各サービスの依存関係
- トラブルシューティングの困難さ

---

## Step 3: 運用作業の体験（面倒さを実感）

### 3.1 ログ監視の手動作業

```bash
# ログ監視スクリプトを実行
./scripts/monitor.sh

# 各サービスのログを個別確認
echo "=== Strapiログ確認 ==="
docker logs vps-strapi --tail 20

echo "=== Webアプリログ確認 ==="
docker logs vps-webapp --tail 20

echo "=== PostgreSQLログ確認 ==="
docker logs vps-postgres --tail 20

echo "=== Nginxログ確認 ==="
docker logs vps-nginx --tail 20
```

**体験ポイント**:
- 複数サービスのログ確認の手間
- 問題の特定の困難さ
- 24時間監視の必要性

### 3.2 アプリケーションの更新作業

```bash
# アプリケーション更新のシミュレーション
echo "=== アプリケーション更新作業 ==="

# 1. サービス停止（ダウンタイム発生）
echo "サービス停止中..."
docker-compose stop strapi webapp

# 2. バックアップ実行
echo "バックアップ実行中..."
./scripts/backup.sh

# 3. アプリケーション更新（実際にはコードの変更）
echo "アプリケーション更新中..."
sleep 5

# 4. サービス再起動
echo "サービス再起動中..."
docker-compose up -d strapi webapp

# 5. 動作確認
echo "動作確認中..."
sleep 10
curl -f http://localhost:1337/_health && echo "✓ Strapi正常" || echo "✗ Strapi異常"
curl -f http://localhost:3000 && echo "✓ Webアプリ正常" || echo "✗ Webアプリ異常"
```

**体験ポイント**:
- 更新時のダウンタイム
- 手動作業の多さ
- 失敗時のリスク

### 3.3 障害対応の体験

```bash
# 障害シミュレーション
echo "=== 障害シミュレーション ==="

# データベース障害をシミュレート
echo "データベース障害発生..."
docker stop vps-postgres

# 障害検知（手動）
echo "障害検知中..."
curl -f http://localhost:1337/api/articles || echo "✗ API異常検知"

# 障害調査
echo "障害調査中..."
docker ps | grep postgres || echo "PostgreSQLコンテナが停止"

# 障害復旧
echo "障害復旧中..."
docker start vps-postgres

# 復旧確認
echo "復旧確認中..."
sleep 15
curl -f http://localhost:1337/api/articles && echo "✓ 復旧完了" || echo "✗ 復旧失敗"
```

**体験ポイント**:
- 障害検知の遅れ
- 手動復旧の困難さ
- ダウンタイムの長さ

---

## Step 4: スケーラビリティの限界を体験

### 4.1 リソース制限の設定

```bash
# リソース制限を追加したDocker Composeファイルを作成
cat > docker-compose.limited.yml << 'EOF'
version: '3.8'

services:
  postgres:
    extends:
      file: docker-compose.yml
      service: postgres
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 256M

  strapi:
    extends:
      file: docker-compose.yml
      service: strapi
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 512M

  webapp:
    extends:
      file: docker-compose.yml
      service: webapp
    deploy:
      resources:
        limits:
          cpus: '0.3'
          memory: 256M
EOF
```

### 4.2 負荷テストの実行

```bash
# 負荷テスト用スクリプト
cat > scripts/load_test.sh << 'EOF'
#!/bin/bash
# 簡単な負荷テスト

echo "=== 負荷テスト開始 ==="

# 同時接続数を増やしてテスト
for i in {1..50}; do
    curl -s http://localhost:1337/api/articles > /dev/null &
done

# リソース使用量を監視
echo "リソース使用量監視中..."
docker stats --no-stream

wait
echo "=== 負荷テスト完了 ==="
EOF

chmod +x scripts/load_test.sh

# 負荷テスト実行
./scripts/load_test.sh
```

**体験ポイント**:
- リソース不足の発生
- パフォーマンス劣化
- スケールアップの困難さ

---

## Step 5: 学習記録と振り返り

### 5.1 体験記録の作成

```bash
# VPS構成の体験記録を作成
cat >> ../../learning-log.md << 'EOF'

## Phase 2: VPS構成体験

### 実施日
- 開始: [日付を記入]
- 完了: [日付を記入]

### 詰まったポイント
#### セットアップ時
- [ ] SSL証明書の作成で詰まった
- [ ] Docker Composeの設定で詰まった
- [ ] 環境変数の設定で詰まった
- [ ] ネットワーク設定で詰まった

#### 運用時
- [ ] ログの確認方法が分からなかった
- [ ] 障害の原因特定に時間がかかった
- [ ] バックアップの実行で詰まった
- [ ] 更新作業でダウンタイムが発生した

### 肌で感じたデメリット
#### 手動運用の大変さ
- [ ] 設定作業の煩雑さ
- [ ] 手順書の必要性
- [ ] 作業ミスのリスク
- [ ] 24時間監視の負担

#### スケーラビリティの限界
- [ ] リソース不足の発生
- [ ] 手動スケールの困難さ
- [ ] 単一障害点のリスク
- [ ] 負荷分散の困難さ

#### セキュリティリスク
- [ ] 設定ミスのリスク
- [ ] アップデートの管理
- [ ] 証明書の管理
- [ ] アクセス制御の複雑さ

### 所要時間
- セットアップ: [時間]
- 運用作業: [時間]
- 障害対応: [時間]
- 負荷テスト: [時間]
- 合計: [時間]

### 感想・気づき
#### 面倒だったこと
- [記入]

#### 怖かったこと
- [記入]

#### 意外だったこと
- [記入]

#### VPSが向いている場面
- [記入]

#### VPSが向いていない場面
- [記入]

---
EOF
```

### 5.2 次のフェーズへの準備

```bash
# VPS環境のクリーンアップ
echo "=== VPS環境のクリーンアップ ==="
docker-compose down -v
docker system prune -f

echo "=== Phase 2 完了 ==="
echo "次は Phase 3: StrapiのみAWS構成 に進んでください"
echo "ドキュメント: docs/phase3-aws-strapi-only.md"
```

---

## 振り返りのポイント

### VPS構成で体験すべき「肌感」

1. **手動作業の煩雑さ**
   - 設定ファイルの手動管理
   - 証明書の手動更新
   - バックアップの手動実行

2. **運用の属人化リスク**
   - 手順書がないと再現できない
   - 担当者が変わると困る
   - ナレッジの共有が困難

3. **スケーラビリティの限界**
   - リソース不足への対応困難
   - 負荷分散の実装困難
   - 単一障害点のリスク

4. **セキュリティ管理の責任**
   - 全ての設定を自分で管理
   - 脆弱性対応の責任
   - アクセス制御の複雑さ

### 次のフェーズとの比較準備

- **同じ作業をAWSでやったらどうなるか？**
- **コストはどう変わるか？**
- **運用の負担はどう変わるか？**
- **スケーラビリティはどう改善されるか？**

これらの疑問を持ちながら、次のPhase 3に進んでください。

---

**お疲れ様でした！VPS構成の大変さを体験できましたね。次はAWS構成との違いを体験しましょう！** 