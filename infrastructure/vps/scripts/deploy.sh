#!/bin/bash

# =============================================================================
# VPS デプロイスクリプト
# ドメイン: aruday1024.xvps.jp
# =============================================================================

set -e

echo "==================================================================="
echo "VPS デプロイ開始"
echo "ドメイン: aruday1024.xvps.jp"
echo "==================================================================="

# 現在のディレクトリ確認
echo "現在のディレクトリ: $(pwd)"

# 環境変数ファイル確認
if [ ! -f ".env" ]; then
    echo "❌ .env ファイルが見つかりません"
    echo ""
    echo "以下の手順で環境変数ファイルを作成してください:"
    echo "1. cp env.example .env"
    echo "2. vim .env  # 実際の値に編集"
    echo ""
    echo "必要な設定項目:"
    echo "- VPS_DOMAIN=aruday1024.xvps.jp"
    echo "- POSTGRES_PASSWORD (安全なパスワード)"
    echo "- JWT_SECRET (ランダム文字列)"
    echo "- ADMIN_JWT_SECRET (ランダム文字列)"
    echo "- APP_KEYS (4つのランダム文字列)"
    echo "- API_TOKEN_SALT (ランダム文字列)"
    echo "- TRANSFER_TOKEN_SALT (ランダム文字列)"
    exit 1
fi

echo "✅ 環境変数ファイル確認済み"

# Docker Composeファイル確認
if [ ! -f "docker-compose.yml" ]; then
    echo "❌ docker-compose.yml が見つかりません"
    exit 1
fi

echo "✅ Docker Compose設定確認済み"

# 環境変数読み込み
source .env
echo "✅ 環境変数読み込み完了"

# DNS設定確認
echo "🌐 DNS設定を確認中..."
if nslookup "$VPS_DOMAIN" > /dev/null 2>&1; then
    echo "✅ ドメイン $VPS_DOMAIN のDNS設定確認済み"
else
    echo "⚠️  ドメイン $VPS_DOMAIN のDNS設定が確認できません"
    echo "X Serverのドメイン管理画面で以下のAレコードを設定してください:"
    echo "@          A         [VPSのIPアドレス]"
    echo "aws        A         [VPSのIPアドレス]"
    echo ""
    echo "DNS設定後、伝播まで最大48時間かかる場合があります。"
    read -p "DNS設定済みで続行しますか？ (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "DNS設定完了後に再実行してください"
        exit 1
    fi
fi

# Dockerイメージビルド
echo "🔨 Dockerイメージをビルド中..."
docker compose build --no-cache
echo "✅ Dockerイメージビルド完了"

# 既存コンテナ停止
echo "🛑 既存のコンテナを停止中..."
docker compose down --remove-orphans 2>/dev/null || true
echo "✅ 既存コンテナ停止完了"

# アプリケーション起動
echo "🚀 アプリケーションを起動中..."
docker compose up -d
echo "✅ アプリケーション起動完了"

# 起動待機
echo "⏳ サービス起動を待機中..."
sleep 30

# ヘルスチェック
echo "🔍 ヘルスチェックを実行中..."

# コンテナ状況確認
echo "📊 コンテナ状況:"
docker compose ps

# ログ確認
echo ""
echo "📝 最新ログ:"
docker compose logs --tail=10

echo ""
echo "==================================================================="
echo "✅ デプロイ完了！"
echo "==================================================================="
echo ""
echo "🌐 アクセス情報:"
echo "メインサイト: https://$VPS_DOMAIN"
echo "Strapi管理画面: https://$VPS_DOMAIN/admin"
echo "AWS比較ページ: https://aws.$VPS_DOMAIN"
echo ""
echo "📋 次のステップ:"
echo "1. SSL証明書取得:"
echo "   sudo certbot --nginx -d $VPS_DOMAIN -d aws.$VPS_DOMAIN"
echo ""
echo "2. ログ確認:"
echo "   docker compose logs -f"
echo ""
echo "3. コンテナ管理:"
echo "   docker compose ps"
echo "   docker compose restart [service]"
echo ""
echo "⚠️  注意: 初回アクセス時は、Strapiの管理者アカウントを作成してください" 