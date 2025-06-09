# DNS設定・管理ガイド

## 🎯 概要

VPS環境でのDNS設定、更新、管理の包括的なガイドです。

## 📋 基本情報

### VPS情報
- **ドメイン**: aruday1024.xvps.jp
- **設定するサブドメイン**:
  - `aruday1024.xvps.jp` - メインサイト (VPS構成)
  - `aws.aruday1024.xvps.jp` - AWS構成比較用

## 🚀 初期DNS設定手順

### Step 1: VPSのIPアドレス確認

```bash
# VPS内でIPアドレス確認
curl -4 ifconfig.me
```

### Step 2: DNS設定

X Serverのドメイン管理画面で以下のレコードを設定：

#### Aレコード設定
```
ホスト名                 タイプ  値 (IPアドレス)      TTL
@                       A       [VPSのIPアドレス]    3600
aws                     A       [VPSのIPアドレス]    3600  (AWS比較用)
```

### Step 3: DNS設定確認

```bash
# メインドメイン確認
nslookup aruday1024.xvps.jp
dig aruday1024.xvps.jp

# サブドメイン確認
nslookup aws.aruday1024.xvps.jp
```

## 🔧 DNS更新手順

### IPアドレス変更時の手順

1. **管理画面でのAレコード更新**
   - XVPSの管理ポータルにアクセス
   - DNS設定画面で新しいIPアドレスに更新
   - 変更を保存

2. **DNS伝播確認**
```bash
# 複数のDNSサーバーで確認
dig @8.8.8.8 aruday1024.xvps.jp
dig @1.1.1.1 aruday1024.xvps.jp

# オンラインツールでの確認
# https://www.whatsmydns.net/
# https://dnschecker.org/
```

3. **SSL証明書の再取得**
```bash
# DNS更新確認後に実行
sudo certbot certonly --webroot \
  -w /var/www/certbot \
  -d aruday1024.xvps.jp \
  --email yuto.suda1024@gmail.com \
  --agree-tos --non-interactive
```

## 🔒 SSL/TLS設定

### Let's Encrypt証明書取得
```bash
# 初回取得
sudo certbot certonly --standalone -d aruday1024.xvps.jp

# 自動更新設定確認
sudo crontab -l | grep certbot
```

### 証明書更新
```bash
# 手動更新
sudo certbot renew

# 更新テスト
sudo certbot renew --dry-run
```

## 📊 設定確認チェックリスト

### DNS設定確認
- [ ] `aruday1024.xvps.jp` がVPSのIPアドレスを返す
- [ ] `aws.aruday1024.xvps.jp` がVPSのIPアドレスを返す

### SSL証明書確認
- [ ] HTTPS接続が正常に動作する
- [ ] 証明書の自動更新が設定されている

### アプリケーション確認
- [ ] `https://aruday1024.xvps.jp` でメインサイトにアクセス可能
- [ ] `https://aruday1024.xvps.jp/admin` でStrapi管理画面にアクセス可能

## 🚨 トラブルシューティング

### DNS設定が反映されない場合
```bash
# キャッシュクリア
sudo systemctl flush-dns  # Ubuntu

# 直接DNSサーバーに問い合わせ
dig @8.8.8.8 aruday1024.xvps.jp
```

### SSL証明書取得エラー
```bash
# Certbotログ確認
sudo tail -f /var/log/letsencrypt/letsencrypt.log

# ファイアウォール確認
sudo ufw status
sudo netstat -tlnp | grep :80
sudo netstat -tlnp | grep :443
```

## 📅 メンテナンススケジュール

### 自動化されているタスク
- SSL証明書更新: 毎日12:00
- システム更新: 毎週日曜日3:00

### 手動確認推奨
- 月1回: DNS設定確認
- 月1回: SSL証明書有効期限確認
- 週1回: アプリケーション動作確認

## 🔗 関連リンク

- [X Server VPS コントロールパネル](https://vps.xserver.ne.jp/)
- [Let's Encrypt](https://letsencrypt.org/)
- [SSL Labs SSL Test](https://www.ssllabs.com/ssltest/) 