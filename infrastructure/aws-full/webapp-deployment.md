# フルAWS構成 + 既存web-app統合デプロイガイド

## 概要

この構成では、既存の`web-app`とStrapiの両方をAWS EC2インスタンス上で統合運用します。無料枠内でフルスタックWebアプリケーションを実現します。

## アーキテクチャ

```
Internet
    |
    v
[Elastic IP] → [EC2 t3.micro]
                    |
                    ├── Nginx (Port 80)
                    ├── Next.js web-app (Port 3000)
                    ├── Strapi CMS (Port 1337)
                    └── PM2 Process Manager
                    |
                    v
            [RDS PostgreSQL] + [S3 Assets]
```

## 前提条件

1. AWS CLI設定済み
2. Terraform >= 1.0
3. 既存web-appが動作可能
4. SSH キーペア

## デプロイ手順

### Step 1: 既存web-appの準備

#### 1.1 PostgreSQL対応の設定

```bash
# web-appディレクトリに移動
cd web-app

# Prismaスキーマを PostgreSQL用に更新
cat > prisma/schema.prisma << 'EOF'
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

// 既存のモデル定義をそのまま使用
// User, Event, EventParticipation, News, Setting モデル
EOF
```

#### 1.2 Next.js設定の最適化

```bash
# next.config.ts を本番用に更新
cat > next.config.ts << 'EOF'
import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // 本番環境最適化
  output: 'standalone',
  
  // 画像最適化
  images: {
    domains: ['localhost', 'your-s3-bucket.s3.amazonaws.com'],
    unoptimized: false,
  },
  
  // 実験的機能
  experimental: {
    serverComponentsExternalPackages: ['@prisma/client'],
  },
  
  // 環境変数
  env: {
    CUSTOM_KEY: process.env.CUSTOM_KEY,
  },
  
  // セキュリティヘッダー
  async headers() {
    return [
      {
        source: '/(.*)',
        headers: [
          {
            key: 'X-Frame-Options',
            value: 'DENY',
          },
          {
            key: 'X-Content-Type-Options',
            value: 'nosniff',
          },
          {
            key: 'Referrer-Policy',
            value: 'origin-when-cross-origin',
          },
        ],
      },
    ];
  },
};

export default nextConfig;
EOF
```

#### 1.3 環境変数テンプレート作成

```bash
# .env.example を作成
cat > .env.example << 'EOF'
# Node.js環境
NODE_ENV=production

# データベース接続（AWS RDS PostgreSQL）
DATABASE_URL=postgresql://username:password@host:5432/database

# NextAuth設定
NEXTAUTH_URL=http://your-domain.com
NEXTAUTH_SECRET=your-nextauth-secret

# Strapi API接続（同一サーバー）
NEXT_PUBLIC_STRAPI_URL=http://localhost:1337
STRAPI_API_TOKEN=your-strapi-api-token

# AWS設定
AWS_REGION=ap-northeast-1
AWS_S3_BUCKET=your-s3-bucket
EOF
```

### Step 2: AWS全体構成のカスタマイズ

#### 2.1 user-data.sh の拡張

```bash
# infrastructure/aws-all/terraform/user-data-webapp.sh を作成
cat > infrastructure/aws-all/terraform/user-data-webapp.sh << 'EOF'
#!/bin/bash

# AWS全体構成 - 既存web-app統合版
# Strapi + Next.js web-app + PostgreSQL(RDS) + S3 構成

set -e

# ログ設定
LOG_FILE="/var/log/user-data.log"
exec > >(tee -a $LOG_FILE)
exec 2>&1

echo "=== AWS全体構成 + web-app統合 EC2初期化開始 $(date) ==="

# 変数設定（Terraformから渡される）
PROJECT_NAME="${project_name}"
DB_HOST="${db_host}"
DB_NAME="${db_name}"
DB_USERNAME="${db_username}"
DB_PASSWORD="${db_password}"
S3_BUCKET="${s3_bucket}"
AWS_REGION="${aws_region}"
STRAPI_PORT="${strapi_port}"
NEXTJS_PORT="${nextjs_port}"
LOG_GROUP="${log_group}"

# システム更新
echo "=== システム更新 ==="
dnf update -y

# 必要なパッケージのインストール
echo "=== 基本パッケージインストール ==="
dnf install -y \
    git \
    curl \
    wget \
    unzip \
    htop \
    nginx \
    postgresql15 \
    awscli \
    amazon-cloudwatch-agent

# Node.js 20.x インストール
echo "=== Node.js インストール ==="
curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
dnf install -y nodejs

# pnpm インストール
echo "=== pnpm インストール ==="
npm install -g pnpm

# PM2 インストール（プロセス管理）
echo "=== PM2 インストール ==="
npm install -g pm2

# アプリケーション用ユーザー作成
echo "=== アプリケーションユーザー作成 ==="
useradd -m -s /bin/bash appuser
usermod -aG wheel appuser

# アプリケーションディレクトリ作成
echo "=== ディレクトリ作成 ==="
mkdir -p /opt/apps/{strapi,webapp}
chown -R appuser:appuser /opt/apps

# GitHubからソースコード取得（実際の環境では適切なリポジトリを設定）
echo "=== アプリケーションコード取得 ==="
# 注意: 実際の運用では、プライベートリポジトリからクローンする
# ここでは、CodeCommitやS3からのダウンロードを想定

# 既存web-appのセットアップ
echo "=== 既存web-appセットアップ ==="
sudo -u appuser bash << 'WEBAPP_SETUP'
cd /opt/apps/webapp

# ログディレクトリ作成
mkdir -p logs

# 環境変数ファイル作成
cat > .env.local << EOF
NODE_ENV=production
PORT=${NEXTJS_PORT}

# データベース接続（AWS RDS）
DATABASE_URL=postgresql://${DB_USERNAME}:${DB_PASSWORD}@${DB_HOST}:5432/${DB_NAME}

# NextAuth設定
NEXTAUTH_URL=http://localhost:${NEXTJS_PORT}
NEXTAUTH_SECRET=nextauth-secret-$(openssl rand -hex 32)

# Strapi API接続（同一サーバー）
NEXT_PUBLIC_STRAPI_URL=http://localhost:${STRAPI_PORT}
STRAPI_API_TOKEN=strapi-api-token

# AWS設定
AWS_REGION=${AWS_REGION}
AWS_S3_BUCKET=${S3_BUCKET}
EOF

# package.jsonをコピー（実際の環境では適切な方法でソースを取得）
cat > package.json << 'EOF'
{
  "name": "web-app-aws",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "dev": "next dev --turbopack",
    "build": "next build",
    "start": "next start",
    "lint": "next lint"
  },
  "dependencies": {
    "@headlessui/react": "^2.2.4",
    "@heroicons/react": "^2.2.0",
    "@hookform/resolvers": "^5.0.1",
    "@next-auth/prisma-adapter": "^1.0.7",
    "@prisma/client": "^6.9.0",
    "@tanstack/react-query": "^5.80.6",
    "bcryptjs": "^3.0.2",
    "date-fns": "^4.1.0",
    "framer-motion": "^12.16.0",
    "jsonwebtoken": "^9.0.2",
    "lucide-react": "^0.513.0",
    "next": "15.3.3",
    "next-auth": "^4.24.11",
    "prisma": "^6.9.0",
    "react": "^19.0.0",
    "react-dom": "^19.0.0",
    "react-hook-form": "^7.57.0",
    "react-hot-toast": "^2.5.2",
    "zod": "^3.25.53",
    "zustand": "^5.0.5"
  },
  "devDependencies": {
    "@eslint/eslintrc": "^3",
    "@tailwindcss/postcss": "^4",
    "@types/node": "^20",
    "@types/react": "^19",
    "@types/react-dom": "^19",
    "eslint": "^9",
    "eslint-config-next": "15.3.3",
    "tailwindcss": "^4",
    "typescript": "^5"
  },
  "engines": {
    "node": ">=18.0.0"
  }
}
EOF

# 依存関係インストール
pnpm install

WEBAPP_SETUP

# Strapiアプリケーション設定
echo "=== Strapiアプリケーション設定 ==="
sudo -u appuser bash << 'STRAPI_SETUP'
cd /opt/apps/strapi

# ログディレクトリ作成
mkdir -p logs

# Strapi設定ファイル作成
cat > .env << EOF
NODE_ENV=production
HOST=0.0.0.0
PORT=${STRAPI_PORT}

# Database
DATABASE_CLIENT=postgres
DATABASE_HOST=${DB_HOST}
DATABASE_PORT=5432
DATABASE_NAME=${DB_NAME}
DATABASE_USERNAME=${DB_USERNAME}
DATABASE_PASSWORD=${DB_PASSWORD}
DATABASE_SSL=false

# Secrets
APP_KEYS=key1,key2,key3,key4
API_TOKEN_SALT=api-token-salt
ADMIN_JWT_SECRET=admin-jwt-secret
TRANSFER_TOKEN_SALT=transfer-token-salt
JWT_SECRET=jwt-secret

# AWS S3
AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
AWS_REGION=${AWS_REGION}
AWS_BUCKET=${S3_BUCKET}

# Upload provider
UPLOAD_PROVIDER=aws-s3
UPLOAD_S3_BUCKET=${S3_BUCKET}
UPLOAD_S3_REGION=${AWS_REGION}

# Admin panel
STRAPI_ADMIN_BACKEND_URL=http://localhost:${STRAPI_PORT}
EOF

# package.json作成
cat > package.json << 'EOF'
{
  "name": "strapi-aws-app",
  "version": "1.0.0",
  "description": "Strapi application for AWS deployment",
  "scripts": {
    "develop": "strapi develop",
    "start": "strapi start",
    "build": "strapi build",
    "strapi": "strapi"
  },
  "dependencies": {
    "@strapi/strapi": "^5.15.0",
    "@strapi/plugin-users-permissions": "^5.15.0",
    "@strapi/plugin-upload": "^5.15.0",
    "@strapi/provider-upload-aws-s3": "^5.15.0",
    "pg": "^8.16.0"
  },
  "engines": {
    "node": ">=18.0.0 <=22.x.x",
    "npm": ">=6.0.0"
  }
}
EOF

# 依存関係インストール
pnpm install

STRAPI_SETUP

# Nginx設定（web-app統合版）
echo "=== Nginx設定 ==="
cat > /etc/nginx/nginx.conf << 'EOF'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    client_max_body_size 100M;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss application/json;

    # Rate limiting
    limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
    limit_req_zone $binary_remote_addr zone=web:10m rate=30r/s;
    limit_req_zone $binary_remote_addr zone=admin:10m rate=5r/s;

    # Upstream servers
    upstream webapp {
        server 127.0.0.1:${NEXTJS_PORT};
    }

    upstream strapi {
        server 127.0.0.1:${STRAPI_PORT};
    }

    # Main server block
    server {
        listen 80 default_server;
        listen [::]:80 default_server;
        server_name _;

        # Security headers
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-XSS-Protection "1; mode=block" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header Referrer-Policy "no-referrer-when-downgrade" always;
        add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline' 'unsafe-eval'" always;

        # Strapi CMS Admin
        location /admin {
            limit_req zone=admin burst=10 nodelay;
            proxy_pass http://strapi;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_cache_bypass $http_upgrade;
        }

        # Strapi API
        location /api/strapi/ {
            limit_req zone=api burst=20 nodelay;
            rewrite ^/api/strapi/(.*) /api/$1 break;
            proxy_pass http://strapi;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_cache_bypass $http_upgrade;
        }

        # Strapi Uploads
        location /uploads/ {
            proxy_pass http://strapi;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            expires 1y;
            add_header Cache-Control "public, immutable";
        }

        # Next.js API Routes
        location /api/ {
            limit_req zone=api burst=15 nodelay;
            proxy_pass http://webapp;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_cache_bypass $http_upgrade;
        }

        # Next.js Static Files
        location /_next/static/ {
            proxy_pass http://webapp;
            proxy_set_header Host $host;
            expires 1y;
            add_header Cache-Control "public, immutable";
        }

        # Next.js Image Optimization
        location /_next/image {
            proxy_pass http://webapp;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        # Next.js Web App (メインアプリケーション)
        location / {
            limit_req zone=web burst=50 nodelay;
            proxy_pass http://webapp;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_cache_bypass $http_upgrade;
        }

        # Health check
        location /health {
            access_log off;
            return 200 "healthy\n";
            add_header Content-Type text/plain;
        }
    }
}
EOF

# PM2設定ファイル作成（web-app統合版）
echo "=== PM2設定 ==="
sudo -u appuser bash << 'PM2_SETUP'
cat > /opt/apps/ecosystem.config.js << 'EOF'
module.exports = {
  apps: [
    {
      name: 'webapp',
      cwd: '/opt/apps/webapp',
      script: 'pnpm',
      args: 'start',
      env: {
        NODE_ENV: 'production',
        PORT: process.env.NEXTJS_PORT || 3000
      },
      log_file: '/opt/apps/webapp/logs/webapp.log',
      error_file: '/opt/apps/webapp/logs/webapp-error.log',
      out_file: '/opt/apps/webapp/logs/webapp-out.log',
      instances: 1,
      exec_mode: 'fork',
      autorestart: true,
      watch: false,
      max_memory_restart: '400M'
    },
    {
      name: 'strapi',
      cwd: '/opt/apps/strapi',
      script: 'pnpm',
      args: 'start',
      env: {
        NODE_ENV: 'production',
        PORT: process.env.STRAPI_PORT || 1337
      },
      log_file: '/opt/apps/strapi/logs/strapi.log',
      error_file: '/opt/apps/strapi/logs/strapi-error.log',
      out_file: '/opt/apps/strapi/logs/strapi-out.log',
      instances: 1,
      exec_mode: 'fork',
      autorestart: true,
      watch: false,
      max_memory_restart: '400M'
    }
  ]
};
EOF
PM2_SETUP

# データベース初期化スクリプト
echo "=== データベース初期化 ==="
sudo -u appuser bash << 'DB_INIT'
cd /opt/apps/webapp

# データベース接続待機
echo "Waiting for database..."
until pg_isready -h ${DB_HOST} -p 5432 -U ${DB_USERNAME}; do
  echo "Database is unavailable - sleeping"
  sleep 5
done
echo "Database is ready!"

# Prismaマイグレーション実行
echo "Running Prisma migrations..."
npx prisma migrate deploy

# Prismaクライアント生成
echo "Generating Prisma client..."
npx prisma generate

# Next.jsアプリケーションビルド
echo "Building Next.js application..."
pnpm build

DB_INIT

# サービス有効化と開始
echo "=== サービス設定 ==="
systemctl enable nginx
systemctl start nginx

# PM2をsystemdサービスとして設定
sudo -u appuser bash << 'PM2_SERVICE'
cd /opt/apps
pm2 start ecosystem.config.js
pm2 save
pm2 startup systemd -u appuser --hp /home/appuser
PM2_SERVICE

# 初期化完了
echo "=== AWS全体構成 + web-app統合 EC2初期化完了 $(date) ==="
echo "Web App: http://localhost:80"
echo "Strapi Admin: http://localhost:80/admin"
echo "ログ: $LOG_FILE"

# 最終的なサービス状態確認
systemctl status nginx
sudo -u appuser pm2 status

echo "=== 初期化スクリプト終了 ==="
EOF
```

#### 2.2 Terraform設定の更新

```bash
# main.tfのuser-dataを更新
sed -i 's/user-data.sh/user-data-webapp.sh/g' infrastructure/aws-all/terraform/main.tf
```

### Step 3: デプロイ実行

```bash
# AWS全体構成をデプロイ
cd infrastructure/aws-all
./deploy.sh

# デプロイ後の情報を取得
PUBLIC_IP=$(terraform output -raw ec2_public_ip)
WEB_APP_URL=$(terraform output -raw web_app_url)
STRAPI_ADMIN_URL=$(terraform output -raw strapi_admin_url)

echo "Public IP: $PUBLIC_IP"
echo "Web App: $WEB_APP_URL"
echo "Strapi Admin: $STRAPI_ADMIN_URL"
```

### Step 4: 動作確認

#### 4.1 基本接続確認

```bash
# ヘルスチェック
curl http://$PUBLIC_IP/health

# Web App確認
curl http://$PUBLIC_IP/

# Strapi Admin確認
curl http://$PUBLIC_IP/admin
```

#### 4.2 SSH接続での詳細確認

```bash
# EC2インスタンスにSSH接続
ssh -i ~/.ssh/aws-all-keypair.pem ec2-user@$PUBLIC_IP

# サービス状態確認
sudo systemctl status nginx
sudo -u appuser pm2 status

# ログ確認
sudo tail -f /var/log/user-data.log
sudo -u appuser tail -f /opt/apps/webapp/logs/webapp.log
sudo -u appuser tail -f /opt/apps/strapi/logs/strapi.log
```

### Step 5: アプリケーション設定

#### 5.1 Strapi初期設定

```bash
# Strapi管理画面にアクセス
open http://$PUBLIC_IP/admin

# 管理者アカウント作成
# 1. 管理画面で管理者アカウントを作成
# 2. Content-Types Builder でコンテンツタイプを作成
# 3. Settings → API Tokens → Create new API Token
```

#### 5.2 web-app設定

```bash
# EC2インスタンス内で環境変数を更新
ssh -i ~/.ssh/aws-all-keypair.pem ec2-user@$PUBLIC_IP

# Strapi APIトークンを設定
sudo -u appuser bash -c "
cd /opt/apps/webapp
echo 'STRAPI_API_TOKEN=your-generated-token' >> .env.local
"

# アプリケーション再起動
sudo -u appuser pm2 restart webapp
```

## 運用・監視

### ログ監視

```bash
# CloudWatchログ確認
aws logs tail "/aws/ec2/aws-all-infra-test" --follow

# アプリケーションログ確認
ssh -i ~/.ssh/aws-all-keypair.pem ec2-user@$PUBLIC_IP
sudo -u appuser pm2 logs
```

### パフォーマンス監視

```bash
# リソース使用量確認
ssh -i ~/.ssh/aws-all-keypair.pem ec2-user@$PUBLIC_IP
htop
df -h
free -h
```

### データベース管理

```bash
# Prismaマイグレーション
ssh -i ~/.ssh/aws-all-keypair.pem ec2-user@$PUBLIC_IP
sudo -u appuser bash -c "
cd /opt/apps/webapp
npx prisma migrate deploy
npx prisma db seed  # シードデータがある場合
"
```

## トラブルシューティング

### よくある問題

1. **アプリケーション起動失敗**
   ```bash
   # PM2ログ確認
   sudo -u appuser pm2 logs webapp
   sudo -u appuser pm2 logs strapi
   ```

2. **データベース接続エラー**
   ```bash
   # RDS接続確認
   pg_isready -h $RDS_ENDPOINT -p 5432 -U $DB_USERNAME
   ```

3. **メモリ不足**
   ```bash
   # メモリ使用量確認
   free -h
   sudo -u appuser pm2 monit
   ```

## セキュリティ強化

### SSL/TLS設定

```bash
# Let's Encrypt証明書取得
sudo dnf install -y certbot python3-certbot-nginx
sudo certbot --nginx -d your-domain.com
```

### ファイアウォール設定

```bash
# セキュリティグループの更新
aws ec2 authorize-security-group-ingress \
  --group-id sg-xxxxx \
  --protocol tcp \
  --port 443 \
  --cidr 0.0.0.0/0
```

## バックアップ・復旧

### データベースバックアップ

```bash
# RDSスナップショット作成
aws rds create-db-snapshot \
  --db-instance-identifier aws-all-infra-test-postgres \
  --db-snapshot-identifier manual-snapshot-$(date +%Y%m%d)
```

### アプリケーションバックアップ

```bash
# アプリケーションファイルバックアップ
ssh -i ~/.ssh/aws-all-keypair.pem ec2-user@$PUBLIC_IP
sudo tar -czf /tmp/apps-backup-$(date +%Y%m%d).tar.gz /opt/apps
```

## スケーリング

### 垂直スケーリング

```bash
# インスタンスタイプ変更（有料）
# variables.tfで設定変更後、terraform apply
```

### 水平スケーリング

```bash
# Application Load Balancer + Auto Scaling Group
# 別途ALB構成を追加
```

## コスト監視

### 使用量確認

```bash
# AWS Cost Explorer
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity MONTHLY \
  --metrics BlendedCost
```

### 予算アラート

```bash
# 予算設定
aws budgets create-budget \
  --account-id your-account-id \
  --budget file://budget.json
```
EOF 