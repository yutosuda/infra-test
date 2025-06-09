# VPS構成 - AWS比較用インフラ環境

このディレクトリは、VPS（Virtual Private Server）環境でのインフラ構成を管理し、AWS構成との比較を目的としています。

## 📁 ディレクトリ構造

```
infrastructure/vps/
├── configs/               # 設定ファイル
│   ├── docker/           # Dockerファイル
│   │   ├── Dockerfile.strapi
│   │   └── Dockerfile.webapp
│   └── nginx/            # Nginx設定
│       └── nginx.conf
├── scripts/              # 実行スクリプト
│   ├── auto-ssl-setup.sh
│   └── deploy.sh
├── docs/                 # ドキュメント
│   ├── DNS-GUIDE.md
│   ├── production-setup.md
│   └── INFRASTRUCTURE-COMPARISON-ACCESS.md
├── init-scripts/         # データベース初期化
├── logs/                 # ログファイル
├── ssl/                  # SSL証明書
├── logrotate.conf/       # ログローテーション設定
├── docker-compose.yml    # Docker Compose設定
├── env.example          # 環境変数テンプレート
├── start.sh             # 起動スクリプト
├── init-db.sql          # データベース初期化SQL
└── README.md            # このファイル
```

## 🚀 クイックスタート

### 1. 環境変数の設定

```bash
cd infrastructure/vps
cp env.example .env
# .envファイルを編集（重要！）
vim .env
```

### 2. デプロイ実行

```bash
chmod +x scripts/deploy.sh
./scripts/deploy.sh
```

**アクセス先:**
- Web App: https://aruday1024.xvps.jp
- Strapi Admin: https://aruday1024.xvps.jp/admin
- AWS比較ページ: https://aws.aruday1024.xvps.jp

## 🔧 環境の特徴

### VPS構成
- **目的**: AWS構成との比較・検証
- **特徴**: 
  - SSL/TLS対応
  - セキュリティ強化
  - ヘルスチェック
  - ログローテーション
  - 監視機能
  - シンプルな単一環境構成

## 📋 前提条件

- Docker & Docker Compose
- ドメイン（aruday1024.xvps.jp）
- SSL証明書（Let's Encrypt）

## 🔒 セキュリティ設定

### 必須設定

1. **環境変数の設定**
   ```bash
   cp env.example .env
   # 以下を必ず変更:
   # - POSTGRES_PASSWORD
   # - JWT_SECRET
   # - ADMIN_JWT_SECRET
   # - APP_KEYS
   # - VPS_DOMAIN
   ```

2. **SSL証明書の設定**
   ```bash
   # 自動設定
   ./scripts/auto-ssl-setup.sh
   ```

## 🛠️ 運用コマンド

### 基本操作
```bash
# 起動
docker compose up -d

# 停止
docker compose down

# ログ確認
docker compose logs -f [service-name]

# 再起動
docker compose restart [service-name]
```

### メンテナンス
```bash
# データベースバックアップ
docker compose exec postgres pg_dump -U strapi_user strapi_db > backup.sql

# SSL証明書更新
./scripts/auto-ssl-setup.sh --renew
```

## 📊 監視・ログ

### アクセス可能な監視エンドポイント
- **Node Exporter**: http://localhost:9100 (ローカルのみ)
- **Nginx ログ**: `logs/` ディレクトリ
- **アプリケーションログ**: `docker compose logs`

### ログファイル
- `logs/access.log` - Nginxアクセスログ
- `logs/error.log` - Nginxエラーログ
- Docker Composeログ - アプリケーションログ

## 🔧 トラブルシューティング

### よくある問題

1. **ポート競合**
   ```bash
   # 使用中のポートを確認
   sudo netstat -tulpn | grep :80
   sudo netstat -tulpn | grep :443
   ```

2. **SSL証明書エラー**
   ```bash
   # 証明書の確認
   openssl x509 -in ssl/cert.pem -text -noout
   ```

3. **データベース接続エラー**
   ```bash
   # PostgreSQL接続確認
   docker compose exec postgres pg_isready -U strapi_user -d strapi_db
   ```

## 📚 関連ドキュメント

- [DNS設定ガイド](docs/DNS-GUIDE.md)
- [本番環境セットアップ](docs/production-setup.md)
- [インフラ比較アクセス](docs/INFRASTRUCTURE-COMPARISON-ACCESS.md)

## 🎯 AWS構成との比較ポイント

このVPS構成を通じて以下の比較検証が可能です：

1. **インフラ管理**
   - VPS: 手動設定・管理
   - AWS: マネージドサービス活用

2. **スケーラビリティ**
   - VPS: 垂直スケーリング中心
   - AWS: 水平・垂直スケーリング

3. **運用コスト**
   - VPS: 固定費用
   - AWS: 従量課金

4. **セキュリティ**
   - VPS: 自己管理
   - AWS: マネージドセキュリティ

5. **可用性**
   - VPS: 単一サーバー
   - AWS: マルチAZ・リージョン

## 💡 次のステップ

1. VPS環境での動作確認
2. AWS構成との性能比較
3. 運用課題の洗い出し
4. コスト比較分析 