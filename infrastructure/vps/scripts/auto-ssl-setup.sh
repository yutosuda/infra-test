#!/bin/bash

# =============================================================================
# 自動SSL証明書取得・HTTPS設定スクリプト
# DNS更新完了後に実行
# =============================================================================

# 環境変数の読み込み
source .env

# 色付きメッセージ用の設定
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 設定値
DOMAIN="$VPS_DOMAIN"
DEMO_DOMAIN="demo.$VPS_DOMAIN"
EMAIL="$LETSENCRYPT_EMAIL"
WEBROOT_PATH="$SSL_WEBROOT_PATH"

echo "=================================================================="
echo "🔐 自動SSL証明書取得・HTTPS設定スクリプト"
echo "メインドメイン: $DOMAIN"
echo "デモドメイン: $DEMO_DOMAIN"
echo "メールアドレス: $EMAIL"
echo "=================================================================="

# DNS更新確認
echo ""
echo "🔍 Step 1: DNS更新状況の確認..."
echo "----------------------------------"

./check-dns-update.sh
dns_status=$?

if [ $dns_status -ne 0 ]; then
    echo -e "${RED}❌ DNS更新が完了していません。先にDNS設定を更新してください。${NC}"
    echo ""
    echo "DNS更新手順:"
    echo "1. VPSプロバイダーの管理画面にアクセス"
    echo "2. $DOMAIN のAレコードを $REQUIRED_DNS_IP に変更"
    echo "3. DNS伝播を待機（5-30分）"
    echo "4. ./check-dns-update.sh で確認"
    exit 1
fi

echo -e "${GREEN}✅ DNS更新が完了しています。SSL証明書取得を開始します。${NC}"

# Webroot ディレクトリの確認・作成
echo ""
echo "📁 Step 2: Webroot ディレクトリの準備..."
echo "----------------------------------"

if [ ! -d "$WEBROOT_PATH" ]; then
    echo "Webroot ディレクトリを作成中: $WEBROOT_PATH"
    sudo mkdir -p "$WEBROOT_PATH"
    sudo chown -R $USER:$USER "$WEBROOT_PATH"
fi

echo -e "${GREEN}✅ Webroot ディレクトリ準備完了${NC}"

# HTTP接続テスト
echo ""
echo "🌐 Step 3: HTTP接続テスト..."
echo "----------------------------------"

echo "メインドメインのテスト..."
http_status=$(curl -H "Host: $DOMAIN" -s -o /dev/null -w "%{http_code}" http://localhost/health)
if [ "$http_status" = "200" ]; then
    echo -e "${GREEN}✅ メインドメイン HTTP接続 OK${NC}"
else
    echo -e "${RED}❌ メインドメイン HTTP接続失敗 (Status: $http_status)${NC}"
    echo "Nginxサービスを確認してください。"
    exit 1
fi

# SSL証明書取得
echo ""
echo "🔐 Step 4: SSL証明書の取得..."
echo "----------------------------------"

echo "Let's Encrypt証明書を取得中..."
echo "ドメイン: $DOMAIN"
echo "メール: $EMAIL"

# メインドメインのみで証明書取得（デモドメインは後で追加）
sudo certbot certonly --webroot \
    -w "$WEBROOT_PATH" \
    -d "$DOMAIN" \
    --email "$EMAIL" \
    --agree-tos \
    --non-interactive \
    --expand

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ SSL証明書取得成功${NC}"
else
    echo -e "${RED}❌ SSL証明書取得失敗${NC}"
    echo ""
    echo "トラブルシューティング:"
    echo "1. DNS設定を再確認: ./check-dns-update.sh"
    echo "2. ファイアウォール設定を確認"
    echo "3. Certbotログを確認: sudo tail -f /var/log/letsencrypt/letsencrypt.log"
    exit 1
fi

# 証明書ファイルの確認
echo ""
echo "📋 Step 5: 証明書ファイルの確認..."
echo "----------------------------------"

CERT_PATH="/etc/letsencrypt/live/$DOMAIN"
if [ -f "$CERT_PATH/fullchain.pem" ] && [ -f "$CERT_PATH/privkey.pem" ]; then
    echo -e "${GREEN}✅ 証明書ファイル確認完了${NC}"
    echo "証明書パス: $CERT_PATH"
    
    # 証明書の詳細情報
    echo ""
    echo "証明書情報:"
    sudo openssl x509 -in "$CERT_PATH/fullchain.pem" -text -noout | grep -E "(Subject:|DNS:|Not After)"
else
    echo -e "${RED}❌ 証明書ファイルが見つかりません${NC}"
    exit 1
fi

# Docker Compose設定の更新
echo ""
echo "🔧 Step 6: HTTPS設定への切り替え..."
echo "----------------------------------"

echo "Nginxを停止中..."
docker compose -f docker-compose.production.yml stop nginx

echo "Nginx設定をHTTPS用に変更中..."
# nginx-production.confを使用するように設定を戻す
sed -i 's|./nginx-http-only.conf:/etc/nginx/nginx.conf:ro|./nginx-production.conf:/etc/nginx/nginx.conf:ro|g' docker-compose.production.yml
sed -i 's|- ./logs:/var/log/nginx|- ./logs:/var/log/nginx\n      - /etc/letsencrypt:/etc/letsencrypt:ro|g' docker-compose.production.yml

echo "Nginxを再起動中..."
docker compose -f docker-compose.production.yml up -d nginx

# HTTPS接続テスト
echo ""
echo "🔒 Step 7: HTTPS接続テスト..."
echo "----------------------------------"

echo "HTTPS接続テスト中..."
sleep 10  # Nginxの起動を待機

https_status=$(curl -k -s -o /dev/null -w "%{http_code}" https://localhost/health)
if [ "$https_status" = "200" ]; then
    echo -e "${GREEN}✅ HTTPS接続テスト成功${NC}"
else
    echo -e "${YELLOW}⚠️ HTTPS接続テスト失敗 (Status: $https_status)${NC}"
    echo "Nginxログを確認してください:"
    echo "docker compose -f docker-compose.production.yml logs nginx --tail=20"
fi

# 証明書自動更新の設定
echo ""
echo "🔄 Step 8: 証明書自動更新の設定..."
echo "----------------------------------"

# Certbot自動更新タイマーの確認
if systemctl is-enabled certbot.timer >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Certbot自動更新タイマーが有効です${NC}"
else
    echo "Certbot自動更新タイマーを有効化中..."
    sudo systemctl enable certbot.timer
    sudo systemctl start certbot.timer
fi

# 最終確認
echo ""
echo "🎉 Step 9: 最終確認..."
echo "----------------------------------"

echo "サービス状況:"
docker compose -f docker-compose.production.yml ps --format "table {{.Name}}\t{{.Status}}"

echo ""
echo "=================================================================="
echo "🎊 SSL証明書取得・HTTPS設定完了！"
echo ""
echo "🌐 アクセス確認:"
echo "- メインサイト: https://$DOMAIN"
echo "- 管理画面: https://$DOMAIN/admin"
echo "- API: https://$DOMAIN/api"
echo "- ヘルスチェック: https://$DOMAIN/health"
echo ""
echo "📋 次のステップ:"
echo "1. 外部からのHTTPS接続テスト"
echo "2. SSL証明書の有効期限確認"
echo "3. 自動更新の動作確認"
echo ""
echo "🔧 トラブルシューティング:"
echo "- Nginxログ: docker compose logs nginx"
echo "- Certbotログ: sudo tail -f /var/log/letsencrypt/letsencrypt.log"
echo "- DNS確認: ./check-dns-update.sh"
echo "==================================================================" 