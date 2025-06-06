# インフラ構成体験学習プロジェクト

## 概要

このプロジェクトは、3つの異なるインフラ構成を実際に体験し、それぞれのメリット・デメリットを「肌感」で理解するための学習環境です。

## 学習目標

- **理論と実践のギャップを埋める**: 実際に手を動かすことで、抽象的な比較では分からない本質的な違いを体験
- **現場感覚の獲得**: 「詰まった・困った・面倒だった・怖かった」という身体的な記憶を通じて深い理解を得る
- **提案力の向上**: 実体験に基づいた説得力のある技術提案ができるようになる

## 3つのインフラ構成

### 1. StrapiのみAWS構成
- **Strapi**: AWS（ECS Fargate + RDS + S3）
- **Webアプリ**: ローカル or VPS
- **体験ポイント**: ネットワーク分断、セキュリティ設定、ハイブリッド構成の複雑さ

### 2. 全てAWS構成
- **Strapi**: AWS（ECS Fargate）
- **Webアプリ**: AWS（Amplify or ECS）
- **DB**: RDS
- **体験ポイント**: AWSサービス連携の複雑さ、コスト管理、運用監視

### 3. VPS構成
- **Strapi**: VPS
- **Webアプリ**: VPS
- **DB**: VPS上のPostgreSQL
- **体験ポイント**: 手動運用の大変さ、スケーラビリティの限界、セキュリティリスク

## プロジェクト構成

```
infra-test/
├── strapi-app/           # Strapi本体
├── web-app/              # Webアプリ（Next.js）
├── infrastructure/
│   ├── aws-strapi-only/  # StrapiのみAWS構成用
│   ├── aws-all/          # 全てAWS構成用
│   └── vps/              # VPS構成用
├── docs/                 # 各構成の詳細ドキュメント
└── README.md             # このファイル
```

## 学習の進め方

1. **準備フェーズ**: 基本アプリケーションのセットアップ
2. **体験フェーズ**: 各構成での実際のデプロイと運用
3. **比較フェーズ**: 体験した内容の整理と比較
4. **まとめフェーズ**: 学んだことの言語化と提案資料作成

## 次のステップ

`docs/getting-started.md` を参照して、学習を開始してください。 