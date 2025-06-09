#!/bin/bash

# =============================================================================
# VPSサーバーへのデプロイスクリプト
# 実際のVPSサーバー（162.43.31.233）へのデプロイ用
# =============================================================================

set -e

# VPS情報
VPS_IP="162.43.31.233"
VPS_USER="root"
VPS_PASSWORD="hbt9m9pe"
DEPLOY_DIR="/opt/vps-app"
SSH_KEY="$HOME/.ssh/vps_key"

echo "==================================================================="
echo "🚀 VPSサーバーへのデプロイ開始"
echo "VPS IP: $VPS_IP"
echo "デプロイ先: $DEPLOY_DIR"
echo "SSH鍵: $SSH_KEY"
echo "==================================================================="

# SSH接続テスト
echo "📡 Step 1: VPSサーバーへの接続テスト..."
if ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$VPS_USER@$VPS_IP" "echo 'SSH接続成功'"; then
    echo "✅ VPSサーバーへの接続成功"
else
    echo "❌ VPSサーバーへの接続失敗"
    echo "以下を確認してください:"
    echo "1. VPSサーバーが起動しているか"
    echo "2. SSH公開鍵が正しく登録されているか"
    echo "3. IPアドレスが正しいか"
    echo ""
    echo "🔑 公開鍵をVPSサーバーに登録してください:"
    echo "$(cat ~/.ssh/vps_key.pub)"
    exit 1
fi

# 必要なパッケージのインストール確認
echo ""
echo "📦 Step 2: 必要なパッケージの確認・インストール..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$VPS_USER@$VPS_IP" << 'EOF'
# Dockerのインストール確認
if ! command -v docker &> /dev/null; then
    echo "Dockerをインストール中..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    systemctl start docker
    systemctl enable docker
fi

# Docker Composeのインストール確認
if ! command -v docker compose &> /dev/null; then
    echo "Docker Composeをインストール中..."
    apt update
    apt install -y docker-compose-plugin
fi

# その他必要なパッケージ
apt update
apt install -y git curl wget nano certbot

echo "✅ 必要なパッケージの確認完了"
EOF

# プロジェクトファイルの転送
echo ""
echo "📁 Step 3: プロジェクトファイルの転送..."

# デプロイディレクトリの作成
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$VPS_USER@$VPS_IP" "mkdir -p $DEPLOY_DIR"

# ファイル転送（rsyncを使用）
echo "ファイルを転送中..."
rsync -avz --delete \
    -e "ssh -i $SSH_KEY -o StrictHostKeyChecking=no" \
    --exclude='.git' \
    --exclude='node_modules' \
    --exclude='logs/*' \
    --exclude='.env' \
    ./ "$VPS_USER@$VPS_IP:$DEPLOY_DIR/"

echo "✅ ファイル転送完了"

# 環境変数ファイルの設定
echo ""
echo "⚙️ Step 4: 環境変数の設定..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$VPS_USER@$VPS_IP" << EOF
cd $DEPLOY_DIR
cp env.example .env

# 環境変数の自動設定
sed -i 's/your-secure-password-here/VPS2025_SecureDB_hbt9m9pe_Prod/' .env
sed -i 's/your-jwt-secret-key-change-this-in-production/vps-jwt-2025-a0207b71-4653-4c42-97c9-5798c9a5c98b-secure-key/' .env
sed -i 's/your-admin-jwt-secret-change-this-in-production/admin-jwt-vps-162-43-31-233-secure-admin-key-2025/' .env
sed -i 's/your-app-keys-change-this-in-production/app-key-1-vps2025,app-key-2-secure,app-key-3-production,app-key-4-final/' .env
sed -i 's/your-api-token-salt-change-this/api-salt-vps-162-43-31-233-production-2025/' .env
sed -i 's/your-transfer-token-salt-change-this/transfer-salt-vps-a0207b71-secure-2025/' .env
sed -i 's/your-domain.com/aruday1024.xvps.jp/' .env
sed -i 's/your-email@example.com/yuto.suda1024@gmail.com/' .env
sed -i 's/your-nextauth-secret-change-this/nextauth-vps-162-43-31-233-secure-2025/' .env
sed -i 's/your-production-strapi-api-token/strapi-api-token-vps-production-2025-secure/' .env

chmod 600 .env
echo "✅ 環境変数設定完了"
EOF

# アプリケーションのデプロイ
echo ""
echo "🚀 Step 5: アプリケーションのデプロイ..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$VPS_USER@$VPS_IP" << EOF
cd $DEPLOY_DIR

# 既存コンテナの停止
docker compose down -v 2>/dev/null || true

# Dockerイメージのビルド
echo "Dockerイメージをビルド中..."
docker compose build --no-cache

# アプリケーションの起動
echo "アプリケーションを起動中..."
docker compose up -d

# 起動待機
sleep 30

# 状態確認
echo "コンテナ状況:"
docker compose ps

echo "✅ アプリケーションデプロイ完了"
EOF

# SSL証明書の取得
echo ""
echo "🔐 Step 6: SSL証明書の取得..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$VPS_USER@$VPS_IP" << 'EOF'
cd /opt/vps-app

# Certbot用ディレクトリの作成
mkdir -p /var/www/certbot

# HTTP専用設定に一時切り替え
docker compose stop nginx
sed -i 's|nginx.conf|nginx-http.conf|g' docker-compose.yml
docker compose up -d nginx

# SSL証明書取得
sleep 10
certbot certonly --webroot \
    -w /var/www/certbot \
    -d aruday1024.xvps.jp \
    --email yuto.suda1024@gmail.com \
    --agree-tos \
    --non-interactive

if [ $? -eq 0 ]; then
    echo "✅ SSL証明書取得成功"
    
    # HTTPS設定に切り替え
    docker compose stop nginx
    sed -i 's|nginx-http.conf|nginx.conf|g' docker-compose.yml
    
    # SSL証明書をコンテナからアクセス可能にする
    sed -i '/\/var\/www\/certbot/a\      - /etc/letsencrypt:/etc/letsencrypt:ro' docker-compose.yml
    
    docker compose up -d nginx
    
    echo "✅ HTTPS設定完了"
else
    echo "⚠️ SSL証明書取得失敗 - HTTP接続のみ利用可能"
fi
EOF

echo ""
echo "==================================================================="
echo "🎉 VPSデプロイ完了！"
echo "==================================================================="
echo ""
echo "🌐 アクセス確認:"
echo "- HTTP: http://aruday1024.xvps.jp"
echo "- HTTPS: https://aruday1024.xvps.jp (SSL証明書取得成功時)"
echo "- Strapi管理画面: http://aruday1024.xvps.jp/admin"
echo ""
echo "📋 次のステップ:"
echo "1. ブラウザでアクセス確認"
echo "2. Strapi管理者アカウント作成"
echo "3. コンテンツの設定"
echo ""
echo "🔧 VPSサーバーへの直接アクセス:"
echo "ssh root@$VPS_IP"
echo "パスワード: $VPS_PASSWORD" 