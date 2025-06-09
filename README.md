# インフラ構成テストプロジェクト

## 概要

このプロジェクトは、**3つの異なるインフラ構成を実際に体験し、それぞれのメリット・デメリットを「肌感」で理解する**ための学習環境です。

## 学習目標

- **理論と実践のギャップを埋める**: 実際に手を動かすことで、抽象的な比較では分からない本質的な違いを体験
- **現場感覚の獲得**: 「詰まった・困った・面倒だった・怖かった」という身体的な記憶を通じて深い理解を得る
- **提案力の向上**: 実体験に基づいた説得力のある技術提案ができるようになる

## 🎯 3つのインフラ構成

### 1. VPS構成（Traditional Server）
```
VPS Server
├── PostgreSQL (データベース)
├── Strapi CMS (バックエンド)
├── Next.js Web App (フロントエンド)
└── Nginx (リバースプロキシ)
```
- **コスト**: $5-20/月
- **難易度**: ⭐⭐☆☆☆
- **体験ポイント**: 手動運用の大変さ、スケーラビリティの限界、セキュリティリスク

### 2. AWS-Hybrid構成（Strapi専用AWS）
```
Hybrid Architecture
├── AWS ECS Fargate (Strapi)
├── AWS RDS PostgreSQL
├── AWS S3 (アセット)
└── Vercel/Local (Next.js Web App)
```
- **コスト**: $20-50/月
- **難易度**: ⭐⭐⭐☆☆
- **体験ポイント**: ネットワーク分断、セキュリティ設定、ハイブリッド構成の複雑さ

### 3. AWS-Full構成（全てAWS）
```
Full AWS Architecture
├── AWS ECS Fargate (Strapi + Next.js)
├── AWS RDS PostgreSQL
├── AWS S3 (アセット)
├── AWS CloudFront (CDN)
└── AWS Application Load Balancer
```
- **コスト**: $30-100/月
- **難易度**: ⭐⭐⭐⭐☆
- **体験ポイント**: AWSサービス連携の複雑さ、コスト管理、運用監視

## 📁 プロジェクト構成

```
infra-test/
├── applications/
│   ├── strapi-app/           # Strapi CMS本体
│   └── web-app/              # Next.js Webアプリ
├── infrastructure/
│   ├── vps/                  # VPS構成用設定
│   ├── aws-hybrid/           # AWS-Hybrid構成用IaC
│   └── aws-full/             # AWS-Full構成用IaC
├── docs/
│   ├── learning-phases/      # 学習フェーズ別ガイド
│   ├── configurations/       # 各構成の詳細ドキュメント
│   └── troubleshooting/      # トラブルシューティング
├── scripts/
│   ├── test-all-configurations.sh
│   └── setup-environment.sh
└── README.md                 # このファイル
```

## 🚀 クイックスタート

### 1. 環境準備
```bash
# 必要なツールのインストール確認
./scripts/setup-environment.sh

# 全構成の動作確認
./scripts/test-all-configurations.sh
```

### 2. 学習フェーズ
1. **Phase 0**: [即座開始ガイド](docs/learning-phases/phase0-immediate-start.md)
2. **Phase 1**: [基礎準備](docs/learning-phases/phase1-preparation.md)
3. **Phase 2**: [VPS構成体験](docs/learning-phases/phase2-vps.md)
4. **Phase 3**: [AWS-Hybrid構成体験](docs/learning-phases/phase3-aws-hybrid.md)
5. **Phase 4**: [AWS-Full構成体験](docs/learning-phases/phase4-aws-full.md)
6. **Phase 5**: [比較・まとめ](docs/learning-phases/phase5-comparison.md)

## 📚 詳細ドキュメント

- [VPS構成詳細](docs/configurations/vps-configuration.md)
- [AWS-Hybrid構成詳細](docs/configurations/aws-hybrid-configuration.md)
- [AWS-Full構成詳細](docs/configurations/aws-full-configuration.md)
- [トラブルシューティング](docs/troubleshooting/common-issues.md)

## 🎓 学習の進め方

1. **準備フェーズ**: 基本アプリケーションのセットアップ
2. **体験フェーズ**: 各構成での実際のデプロイと運用
3. **比較フェーズ**: 体験した内容の整理と比較
4. **まとめフェーズ**: 学んだことの言語化と提案資料作成

## 💡 体験すべき観点

各構成で以下の観点を必ず体験してください：

- **セットアップ時に詰まりやすいポイント**
- **運用・更新時に面倒なポイント**
- **障害時に困るポイント**
- **コストが見えにくい／爆発しやすいポイント**
- **セキュリティリスクが顕在化しやすいポイント**
- **スケール・冗長化の限界を感じるポイント**

## 🔧 技術スタック

- **Frontend**: Next.js 15, TypeScript, Tailwind CSS
- **Backend**: Strapi 5, Node.js
- **Database**: PostgreSQL
- **Infrastructure**: Docker, AWS (ECS, RDS, S3), Nginx
- **IaC**: Terraform
- **Monitoring**: AWS CloudWatch, Docker logs

## 📈 期待される学習成果

このプロジェクトを完了すると、以下の能力が身につきます：

1. **実体験に基づいた技術提案力**
2. **インフラ構成の適切な選択判断力**
3. **運用・保守の現実的な理解**
4. **コスト・セキュリティ・スケーラビリティの実感**
5. **クラウドとオンプレミスの使い分け能力**

---

**次のステップ**: [即座開始ガイド](docs/learning-phases/phase0-immediate-start.md) から学習を開始してください。 
