# VPS構成詳細ガイド

## 概要

VPS（Virtual Private Server）構成は、1台または複数台の仮想サーバー上にすべてのコンポーネントを配置する従来型のインフラ構成です。

## 🏗️ アーキテクチャ

```
VPS Server (Ubuntu 22.04)
├── Nginx (リバースプロキシ・SSL終端)
├── Docker Compose
│   ├── Strapi CMS (Node.js)
│   ├── Next.js Web App
│   └── PostgreSQL Database
└── システム管理
    ├── SSL証明書 (Let's Encrypt)
    ├── ログローテーション
    ├── バックアップスクリプト
    └── 監視・アラート
```

## 📋 技術スタック

- **OS**: Ubuntu 22.04 LTS
- **Web Server**: Nginx 1.18+
- **Container**: Docker 24.0+, Docker Compose 2.0+
- **Backend**: Strapi 5.x (Node.js 20.x)
- **Frontend**: Next.js 15.x (React 18.x)
- **Database**: PostgreSQL 15.x
- **SSL**: Let's Encrypt (Certbot)
- **Monitoring**: Docker logs, Nginx logs

## 🚀 セットアップ手順

### 1. VPS初期設定

```bash
# システム更新
sudo apt update && sudo apt upgrade -y

# 必要なパッケージインストール
sudo apt install -y curl wget git vim ufw fail2ban

# ファイアウォール設定
sudo ufw allow ssh
sudo ufw allow http
sudo ufw allow https
sudo ufw enable

# Docker インストール
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Docker Compose インストール
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

### 2. アプリケーションデプロイ

```bash
# プロジェクトクローン
git clone <repository-url>
cd infra-test

# VPS構成でデプロイ
cd infrastructure/vps

# 環境変数設定
cp .env.example .env
vim .env  # 必要な値を設定

# Docker Compose起動
docker-compose up -d

# SSL証明書設定
sudo ./auto-ssl-setup.sh your-domain.com
```

### 3. Nginx設定

```nginx
# /etc/nginx/sites-available/your-app
server {
    listen 80;
    server_name your-domain.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name your-domain.com;

    ssl_certificate /etc/letsencrypt/live/your-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your-domain.com/privkey.pem;

    # Strapi API
    location /api/ {
        proxy_pass http://localhost:1337;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Strapi Admin
    location /admin/ {
        proxy_pass http://localhost:1337;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Next.js Web App
    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

## 🔧 運用・保守

### 日常的な保守作業

```bash
# システム更新
sudo apt update && sudo apt upgrade -y

# Docker イメージ更新
docker-compose pull
docker-compose up -d

# ログ確認
docker-compose logs -f

# ディスク使用量確認
df -h
docker system df

# 不要なDockerリソース削除
docker system prune -f
```

### バックアップ

```bash
# データベースバックアップ
docker-compose exec postgres pg_dump -U strapi_user strapi_db > backup_$(date +%Y%m%d_%H%M%S).sql

# アプリケーションファイルバックアップ
tar -czf app_backup_$(date +%Y%m%d_%H%M%S).tar.gz \
  docker-compose.yml \
  .env \
  nginx/ \
  uploads/

# 自動バックアップスクリプト
cat > /home/user/backup.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/home/user/backups"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# DB backup
docker-compose exec -T postgres pg_dump -U strapi_user strapi_db > $BACKUP_DIR/db_$DATE.sql

# Files backup
tar -czf $BACKUP_DIR/files_$DATE.tar.gz uploads/

# Keep only last 7 days
find $BACKUP_DIR -name "*.sql" -mtime +7 -delete
find $BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete
EOF

chmod +x /home/user/backup.sh

# Cron設定（毎日2時にバックアップ）
echo "0 2 * * * /home/user/backup.sh" | crontab -
```

### 監視・アラート

```bash
# システムリソース監視スクリプト
cat > /home/user/monitor.sh << 'EOF'
#!/bin/bash

# CPU使用率チェック
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
if (( $(echo "$CPU_USAGE > 80" | bc -l) )); then
    echo "High CPU usage: $CPU_USAGE%" | mail -s "Server Alert" admin@example.com
fi

# メモリ使用率チェック
MEM_USAGE=$(free | grep Mem | awk '{printf("%.1f", $3/$2 * 100.0)}')
if (( $(echo "$MEM_USAGE > 80" | bc -l) )); then
    echo "High memory usage: $MEM_USAGE%" | mail -s "Server Alert" admin@example.com
fi

# ディスク使用率チェック
DISK_USAGE=$(df / | tail -1 | awk '{print $5}' | cut -d'%' -f1)
if [ $DISK_USAGE -gt 80 ]; then
    echo "High disk usage: $DISK_USAGE%" | mail -s "Server Alert" admin@example.com
fi

# Docker コンテナ状態チェック
if ! docker-compose ps | grep -q "Up"; then
    echo "Some containers are down" | mail -s "Server Alert" admin@example.com
fi
EOF

chmod +x /home/user/monitor.sh

# 5分毎に監視実行
echo "*/5 * * * * /home/user/monitor.sh" | crontab -
```

## 🔒 セキュリティ設定

### SSH設定強化

```bash
# SSH設定編集
sudo vim /etc/ssh/sshd_config

# 推奨設定
Port 2222  # デフォルトポート変更
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
MaxAuthTries 3

# 設定反映
sudo systemctl restart ssh
```

### Fail2ban設定

```bash
# Fail2ban設定
sudo vim /etc/fail2ban/jail.local

[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3

[sshd]
enabled = true
port = 2222

[nginx-http-auth]
enabled = true

[nginx-limit-req]
enabled = true

# 設定反映
sudo systemctl restart fail2ban
```

### SSL証明書自動更新

```bash
# Certbot自動更新設定
echo "0 12 * * * /usr/bin/certbot renew --quiet" | sudo crontab -

# 更新テスト
sudo certbot renew --dry-run
```

## 📊 パフォーマンス最適化

### Nginx最適化

```nginx
# /etc/nginx/nginx.conf
worker_processes auto;
worker_connections 1024;

gzip on;
gzip_vary on;
gzip_min_length 1024;
gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

# キャッシュ設定
location ~* \.(jpg|jpeg|png|gif|ico|css|js)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
}
```

### PostgreSQL最適化

```sql
-- postgresql.conf 最適化
shared_buffers = 256MB
effective_cache_size = 1GB
maintenance_work_mem = 64MB
checkpoint_completion_target = 0.9
wal_buffers = 16MB
default_statistics_target = 100
random_page_cost = 1.1
effective_io_concurrency = 200
```

## 🚨 トラブルシューティング

### よくある問題と解決方法

1. **コンテナが起動しない**
   ```bash
   # ログ確認
   docker-compose logs container_name
   
   # リソース確認
   docker system df
   free -h
   
   # 再起動
   docker-compose restart container_name
   ```

2. **SSL証明書エラー**
   ```bash
   # 証明書状態確認
   sudo certbot certificates
   
   # 手動更新
   sudo certbot renew --force-renewal
   
   # Nginx設定確認
   sudo nginx -t
   ```

3. **データベース接続エラー**
   ```bash
   # PostgreSQL状態確認
   docker-compose exec postgres pg_isready -U strapi_user
   
   # 接続テスト
   docker-compose exec postgres psql -U strapi_user -d strapi_db
   ```

4. **高負荷時の対応**
   ```bash
   # プロセス確認
   top
   htop
   
   # ネットワーク確認
   netstat -tulpn
   
   # ログ確認
   tail -f /var/log/nginx/access.log
   ```

## 💰 コスト最適化

### リソース使用量監視

```bash
# 月次リソースレポート
cat > /home/user/monthly_report.sh << 'EOF'
#!/bin/bash
echo "=== Monthly Resource Report ===" > /tmp/report.txt
echo "Date: $(date)" >> /tmp/report.txt
echo "" >> /tmp/report.txt

echo "CPU Usage (last 30 days average):" >> /tmp/report.txt
sar -u 1 1 >> /tmp/report.txt

echo "Memory Usage:" >> /tmp/report.txt
free -h >> /tmp/report.txt

echo "Disk Usage:" >> /tmp/report.txt
df -h >> /tmp/report.txt

echo "Network Usage (last 30 days):" >> /tmp/report.txt
vnstat -m >> /tmp/report.txt

mail -s "Monthly Server Report" admin@example.com < /tmp/report.txt
EOF
```

### コスト削減のポイント

1. **リソース最適化**
   - 不要なDockerイメージ削除
   - ログローテーション設定
   - 定期的なシステムクリーンアップ

2. **帯域幅最適化**
   - 画像圧縮
   - CDN利用検討
   - キャッシュ設定最適化

3. **バックアップ最適化**
   - 差分バックアップ
   - 古いバックアップ自動削除
   - 外部ストレージ利用

## 📈 スケーリング戦略

### 垂直スケーリング（スペックアップ）

```bash
# 現在のリソース使用状況確認
htop
iotop
nethogs

# VPSプラン変更後の設定調整
# Docker Compose リソース制限調整
vim docker-compose.yml
```

### 水平スケーリング（サーバー追加）

```bash
# ロードバランサー設定
# Nginx upstream設定
upstream app_servers {
    server 192.168.1.10:3000;
    server 192.168.1.11:3000;
}

# データベース分離
# 読み取り専用レプリカ設定
```

---

**注意**: VPS構成は手動運用が中心となるため、定期的な保守作業とセキュリティ更新が重要です。 