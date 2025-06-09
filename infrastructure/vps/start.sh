#!/bin/bash

# 本番環境起動スクリプト
set -e

echo "🚀 VPS本番環境を起動しています..."

# 環境変数ファイルの確認
if [ ! -f ".env" ]; then
    echo "❌ .envファイルが見つかりません。env.exampleからコピーして設定してください。"
    exit 1
fi

# セキュリティチェック
echo "🔒 セキュリティ設定を確認しています..."
if grep -q "change-this" .env; then
    echo "❌ デフォルトのシークレットキーが検出されました。.envファイルを適切に設定してください。"
    exit 1
fi

# SSL証明書の確認
if [ ! -d "../../ssl" ] || [ ! "$(ls -A ../../ssl)" ]; then
    echo "⚠️  SSL証明書が見つかりません。自動セットアップを実行しますか？ (y/N)"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        ../../scripts/auto-ssl-setup.sh
    else
        echo "❌ SSL証明書が必要です。手動で設定するか、auto-ssl-setup.shを実行してください。"
        exit 1
    fi
fi

# Docker Composeで起動
echo "🐳 Dockerコンテナを起動しています..."
docker-compose up -d

# ヘルスチェック
echo "🔍 サービスの起動を確認しています..."
sleep 15

# PostgreSQL接続確認
echo "📊 PostgreSQL接続確認..."
docker-compose exec postgres pg_isready -U "${POSTGRES_USER:-strapi_user}" -d "${POSTGRES_DB:-strapi_db}"

# Strapi起動確認
echo "🎯 Strapi起動確認..."
curl -f http://localhost:1338/admin || echo "Strapiはまだ起動中です..."

# Next.js起動確認
echo "🌐 Next.js起動確認..."
curl -f http://localhost:3000 || echo "Next.jsはまだ起動中です..."

# Nginx設定確認
echo "🌐 Nginx設定確認..."
docker-compose exec nginx nginx -t

echo "✅ 本番環境が起動しました！"
echo ""
echo "📍 アクセス先:"
echo "  - Web App: https://${VPS_DOMAIN:-your-domain.com}"
echo "  - Strapi Admin: https://${VPS_DOMAIN:-your-domain.com}/admin"
echo "  - Monitoring: http://localhost:9100 (ローカルのみ)"
echo ""
echo "🛑 停止するには: docker-compose down"
echo "📊 ログ確認: docker-compose logs -f [service-name]" 