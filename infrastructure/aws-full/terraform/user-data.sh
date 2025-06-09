#!/bin/bash

# AWS全体構成 - EC2初期化スクリプト
# Strapi + Next.js + PostgreSQL(RDS) + S3 構成

set -e

# ログ設定
LOG_FILE="/var/log/user-data.log"
exec > >(tee -a $LOG_FILE)
exec 2>&1

echo "=== AWS全体構成 EC2初期化開始 $(date) ==="

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

# CloudWatch Logs エージェント設定
echo "=== CloudWatch Logs設定 ==="
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << EOF
{
    "logs": {
        "logs_collected": {
            "files": {
                "collect_list": [
                    {
                        "file_path": "/var/log/user-data.log",
                        "log_group_name": "$LOG_GROUP",
                        "log_stream_name": "user-data"
                    },
                    {
                        "file_path": "/opt/apps/strapi/logs/strapi.log",
                        "log_group_name": "$LOG_GROUP",
                        "log_stream_name": "strapi"
                    },
                    {
                        "file_path": "/opt/apps/webapp/logs/webapp.log",
                        "log_group_name": "$LOG_GROUP",
                        "log_stream_name": "webapp"
                    },
                    {
                        "file_path": "/var/log/nginx/access.log",
                        "log_group_name": "$LOG_GROUP",
                        "log_stream_name": "nginx-access"
                    },
                    {
                        "file_path": "/var/log/nginx/error.log",
                        "log_group_name": "$LOG_GROUP",
                        "log_stream_name": "nginx-error"
                    }
                ]
            }
        }
    }
}
EOF

# CloudWatch Logs エージェント開始
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config \
    -m ec2 \
    -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
    -s

# Gitリポジトリクローン（実際の環境では適切なリポジトリURLを設定）
echo "=== アプリケーションコード取得 ==="
# 注意: 実際の運用では、GitHubやCodeCommitからクローンする
# ここでは、ローカルファイルをコピーする想定でプレースホルダーを作成

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

# package.json作成（基本構成）
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

# Next.jsアプリケーション設定
echo "=== Next.jsアプリケーション設定 ==="
sudo -u appuser bash << 'WEBAPP_SETUP'
cd /opt/apps/webapp

# ログディレクトリ作成
mkdir -p logs

# Next.js設定ファイル作成
cat > .env.local << EOF
NODE_ENV=production
PORT=${NEXTJS_PORT}

# Strapi API
NEXT_PUBLIC_STRAPI_URL=http://localhost:${STRAPI_PORT}
STRAPI_API_TOKEN=

# Database (Prisma)
DATABASE_URL=postgresql://${DB_USERNAME}:${DB_PASSWORD}@${DB_HOST}:5432/${DB_NAME}

# NextAuth
NEXTAUTH_URL=http://localhost:${NEXTJS_PORT}
NEXTAUTH_SECRET=nextauth-secret

# AWS
AWS_REGION=${AWS_REGION}
AWS_S3_BUCKET=${S3_BUCKET}
EOF

# package.json作成（基本構成）
cat > package.json << 'EOF'
{
  "name": "webapp-aws",
  "version": "1.0.0",
  "description": "Next.js application for AWS deployment",
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "lint": "next lint"
  },
  "dependencies": {
    "next": "^15.3.3",
    "react": "^19.0.0",
    "react-dom": "^19.0.0",
    "@prisma/client": "^6.9.0",
    "prisma": "^6.9.0"
  },
  "engines": {
    "node": ">=18.0.0"
  }
}
EOF

# 依存関係インストール
pnpm install

WEBAPP_SETUP

# Nginx設定
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

    # Upstream servers
    upstream strapi {
        server 127.0.0.1:${STRAPI_PORT};
    }

    upstream webapp {
        server 127.0.0.1:${NEXTJS_PORT};
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
        add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;

        # Strapi API
        location /api/ {
            limit_req zone=api burst=20 nodelay;
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

        # Strapi Admin
        location /admin {
            limit_req zone=api burst=10 nodelay;
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

        # Next.js Web App
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

# PM2設定ファイル作成
echo "=== PM2設定 ==="
sudo -u appuser bash << 'PM2_SETUP'
cat > /opt/apps/ecosystem.config.js << 'EOF'
module.exports = {
  apps: [
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
    },
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
    }
  ]
};
EOF
PM2_SETUP

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

# ファイアウォール設定（必要に応じて）
echo "=== セキュリティ設定 ==="
# Amazon Linux 2023はデフォルトでfirewalldが無効なので、必要に応じて設定

# ヘルスチェック用スクリプト作成
echo "=== ヘルスチェックスクリプト作成 ==="
cat > /usr/local/bin/health-check.sh << 'EOF'
#!/bin/bash

# ヘルスチェックスクリプト
LOG_FILE="/var/log/health-check.log"

check_service() {
    local service_name=$1
    local port=$2
    local endpoint=$3
    
    if curl -f -s "http://localhost:$port$endpoint" > /dev/null; then
        echo "$(date): $service_name is healthy" >> $LOG_FILE
        return 0
    else
        echo "$(date): $service_name is unhealthy" >> $LOG_FILE
        return 1
    fi
}

# Strapi チェック
check_service "Strapi" "${STRAPI_PORT}" "/admin"

# Next.js チェック
check_service "Next.js" "${NEXTJS_PORT}" "/"

# Nginx チェック
check_service "Nginx" "80" "/health"
EOF

chmod +x /usr/local/bin/health-check.sh

# Cronジョブ設定（5分ごとにヘルスチェック）
echo "*/5 * * * * /usr/local/bin/health-check.sh" | crontab -

# 初期化完了
echo "=== AWS全体構成 EC2初期化完了 $(date) ==="
echo "Strapi: http://localhost:${STRAPI_PORT}"
echo "Next.js: http://localhost:${NEXTJS_PORT}"
echo "Nginx: http://localhost:80"
echo "ログ: $LOG_FILE"

# 最終的なサービス状態確認
systemctl status nginx
sudo -u appuser pm2 status

echo "=== 初期化スクリプト終了 ===" 