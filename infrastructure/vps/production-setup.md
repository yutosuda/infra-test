# さくらVPS + ドメイン実装ガイド

## 🎯 目標
3つのインフラ構成を実際のVPS + ドメインで比較検証

## 📋 必要なリソース

### 1. さくらVPS
- **推奨プラン**: 2GB以上 (複数構成の並行テスト用)
- **OS**: Ubuntu 22.04 LTS
- **料金**: 月額1,738円〜

### 2. ドメイン
- **推奨**: `.com` または `.jp`
- **DNS管理**: CloudFlare (無料) または さくらのDNS
- **料金**: 年額1,000円〜3,000円

## 🚀 デプロイ手順

### Step 1: VPS初期設定
```bash
# VPS接続
ssh root@your-vps-ip

# 基本パッケージ更新
apt update && apt upgrade -y

# Docker & Docker Compose インストール
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
apt install docker-compose-plugin -y

# ファイアウォール設定
ufw allow 22    # SSH
ufw allow 80    # HTTP
ufw allow 443   # HTTPS
ufw enable
```

### Step 2: プロジェクトデプロイ
```bash
# プロジェクトクローン
git clone <your-repo> /opt/infra-test
cd /opt/infra-test/infrastructure/vps

# 本番用環境変数設定
cp .env.example .env.production
# ドメイン、SSL設定を編集

# Docker構成起動
docker-compose -f docker-compose.production.yml up -d
```

### Step 3: SSL証明書 + ドメイン設定
```bash
# Certbot インストール
apt install certbot python3-certbot-nginx -y

# SSL証明書取得
certbot --nginx -d vps.your-domain.com

# 自動更新設定
crontab -e
# 0 12 * * * /usr/bin/certbot renew --quiet
```

## 🌐 サブドメイン構成

### DNS設定 (CloudFlare推奨)
```
A    vps.your-domain.com      → VPS IP
A    aws.your-domain.com      → AWS ALB IP
CNAME hybrid.your-domain.com  → vercel-app.vercel.app
A    demo.your-domain.com     → VPS IP (比較ダッシュボード)
```

### Nginx設定 (マルチドメイン対応)
```nginx
# vps.your-domain.com - VPS構成
server {
    listen 443 ssl http2;
    server_name vps.your-domain.com;
    
    ssl_certificate /etc/letsencrypt/live/vps.your-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/vps.your-domain.com/privkey.pem;
    
    location / {
        proxy_pass http://webapp:3000;
        # プロキシ設定...
    }
    
    location /api/ {
        proxy_pass http://strapi:1337/api/;
        # API プロキシ設定...
    }
}

# demo.your-domain.com - 比較ダッシュボード
server {
    listen 443 ssl http2;
    server_name demo.your-domain.com;
    
    ssl_certificate /etc/letsencrypt/live/demo.your-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/demo.your-domain.com/privkey.pem;
    
    location / {
        proxy_pass http://demo-app:3001;
        # 比較ダッシュボード...
    }
}
```

## 📊 構成比較の実装

### 1. VPS構成 (vps.your-domain.com)
- **現在の実装**: そのまま利用
- **特徴**: 完全自己管理、低コスト
- **監視**: Docker stats, システムリソース

### 2. AWS構成 (aws.your-domain.com)
- **実装**: Terraform + ECS Fargate
- **特徴**: スケーラブル、マネージド
- **監視**: CloudWatch, X-Ray

### 3. ハイブリッド構成 (hybrid.your-domain.com)
- **フロント**: Vercel
- **バックエンド**: AWS ECS (Strapi)
- **DB**: Supabase
- **特徴**: 最適化された組み合わせ

### 4. 比較ダッシュボード (demo.your-domain.com)
- **リアルタイム監視**: 各構成のパフォーマンス
- **コスト比較**: 月額料金シミュレーション
- **レスポンス時間**: 実測値比較

## 💰 コスト見積もり

### 初期費用
- さくらVPS (2GB): 月額1,738円
- ドメイン (.com): 年額1,500円
- **合計**: 月額約2,000円

### AWS追加費用 (テスト用)
- ECS Fargate: 月額3,000円〜
- RDS (t3.micro): 月額2,000円〜
- ALB: 月額2,500円〜
- **AWS合計**: 月額7,500円〜

### 無料枠活用
- Vercel: 無料
- Supabase: 無料 (500MB)
- CloudFlare: 無料 (DNS + CDN)

## 🔧 監視・分析ツール

### パフォーマンス測定
```bash
# レスポンス時間測定
curl -w "@curl-format.txt" -o /dev/null -s https://vps.your-domain.com/
curl -w "@curl-format.txt" -o /dev/null -s https://aws.your-domain.com/
curl -w "@curl-format.txt" -o /dev/null -s https://hybrid.your-domain.com/

# 負荷テスト
ab -n 1000 -c 10 https://vps.your-domain.com/
```

### リソース監視
```bash
# VPS リソース監視
docker stats
htop
iotop

# ログ監視
docker-compose logs -f
tail -f /var/log/nginx/access.log
```

## 🎯 成功指標

### 技術指標
- **レスポンス時間**: < 500ms
- **可用性**: > 99.9%
- **スループット**: > 100 req/sec

### 体験指標
- **デプロイ時間**: VPS vs AWS vs Hybrid
- **運用負荷**: 監視・メンテナンス工数
- **スケーラビリティ**: 負荷増加時の対応

### コスト指標
- **初期費用**: セットアップコスト
- **運用費用**: 月額ランニングコスト
- **スケール費用**: トラフィック増加時のコスト

## 📅 実装スケジュール

### Week 1: 基盤構築
- [ ] さくらVPS契約・初期設定
- [ ] ドメイン取得・DNS設定
- [ ] VPS構成デプロイ・SSL設定

### Week 2: AWS構成実装
- [ ] Terraform設定調整
- [ ] AWS環境デプロイ
- [ ] サブドメイン設定

### Week 3: ハイブリッド構成
- [ ] Vercel設定
- [ ] AWS Strapi設定
- [ ] Supabase連携

### Week 4: 比較・分析
- [ ] 比較ダッシュボード実装
- [ ] パフォーマンステスト
- [ ] 最終評価・レポート

## 🚨 注意事項

### セキュリティ
- SSH鍵認証必須
- 不要ポートの閉鎖
- 定期的なセキュリティアップデート

### バックアップ
- データベースの定期バックアップ
- 設定ファイルのバージョン管理
- 災害復旧手順の文書化

### 監視
- アップタイム監視
- エラーログ監視
- リソース使用量アラート 