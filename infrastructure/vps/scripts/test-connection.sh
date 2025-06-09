#!/bin/bash

# =============================================================================
# VPSサーバー接続テストスクリプト
# =============================================================================

VPS_IP="162.43.31.233"
VPS_USER="root"
VPS_PASSWORD="hbt9m9pe"
SSH_KEY="$HOME/.ssh/vps_key"

echo "==================================================================="
echo "🔍 VPSサーバー接続テスト"
echo "VPS IP: $VPS_IP"
echo "==================================================================="

echo ""
echo "📡 Test 1: 公開鍵認証でのSSH接続テスト..."
if ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$VPS_USER@$VPS_IP" "echo 'SSH公開鍵認証成功'" 2>/dev/null; then
    echo "✅ 公開鍵認証成功！"
    AUTH_METHOD="publickey"
else
    echo "❌ 公開鍵認証失敗"
    
    echo ""
    echo "📡 Test 2: パスワード認証でのSSH接続テスト..."
    if sshpass -p "$VPS_PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$VPS_USER@$VPS_IP" "echo 'SSHパスワード認証成功'" 2>/dev/null; then
        echo "✅ パスワード認証成功！"
        AUTH_METHOD="password"
    else
        echo "❌ パスワード認証も失敗"
        echo ""
        echo "🔧 対処方法:"
        echo "1. VPSサーバーが起動しているか確認"
        echo "2. ファイアウォール設定確認（ポート22が開放されているか）"
        echo "3. X serverパネルでSSH設定を確認"
        echo "4. Webコンソール経由で直接設定"
        exit 1
    fi
fi

echo ""
echo "🎉 接続成功！使用認証方式: $AUTH_METHOD"
echo ""
echo "📋 次のステップ:"
if [ "$AUTH_METHOD" = "publickey" ]; then
    echo "- 公開鍵認証が有効です"
    echo "- ./scripts/vps-deploy.sh でデプロイ実行可能"
else
    echo "- パスワード認証が有効です"
    echo "- ./scripts/vps-deploy-password.sh でデプロイ実行可能"
fi
echo "" 