# Phase 1: 基礎準備 - 開発環境とアプリケーションのセットアップ

## このフェーズの目標

1. **開発環境の準備**: 必要なツールのインストールと動作確認
2. **Strapiアプリケーションの作成**: ヘッドレスCMSの基本理解
3. **Webアプリケーションの作成**: フロントエンドアプリケーションの基本理解
4. **ローカル環境での連携確認**: API通信の基本体験

**所要時間**: 1-2日（初心者の場合）

## Step 1: 開発環境の確認と準備

### 1.1 必要なツールの確認

まず、現在の環境を確認しましょう：

```bash
# 現在のディレクトリを確認
pwd

# Node.jsのバージョン確認
node --version
# 期待値: v18.0.0 以上

# npmのバージョン確認
npm --version
# 期待値: 8.0.0 以上

# Dockerの確認
docker --version
# 期待値: Docker version 20.0.0 以上

# Docker Composeの確認
docker-compose --version
# 期待値: docker-compose version 1.29.0 以上
```

### 1.2 ツールが不足している場合

#### Node.js のインストール（Ubuntu/WSL2の場合）
```bash
# Node.js 18.x のインストール
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# インストール確認
node --version
npm --version
```

#### Docker のインストール（Ubuntu/WSL2の場合）
```bash
# Dockerのインストール
sudo apt-get update
sudo apt-get install -y docker.io docker-compose

# Dockerサービスの開始
sudo systemctl start docker
sudo systemctl enable docker

# 現在のユーザーをdockerグループに追加（再ログイン必要）
sudo usermod -aG docker $USER
```

### 1.3 プロジェクト構造の確認

```bash
# プロジェクトのルートディレクトリにいることを確認
ls -la

# 期待される構造
# strapi-app/
# web-app/
# infrastructure/
# docs/
# README.md
```

## Step 2: Strapiアプリケーションの作成

### 2.1 Strapiとは？

**Strapi**は「ヘッドレスCMS」です：
- **CMS**: Content Management System（コンテンツ管理システム）
- **ヘッドレス**: 管理画面とフロントエンドが分離されている
- **API提供**: REST APIやGraphQL APIでデータを提供

### 2.2 Strapiプロジェクトの作成

```bash
# strapi-appディレクトリに移動
cd strapi-app

# Strapiプロジェクトを作成
npx create-strapi-app@latest . --quickstart

# 注意: 「.」は現在のディレクトリを意味します
# 既存のディレクトリが空でない場合はエラーになる可能性があります
```

**初回実行時の注意点**:
- インストールには5-10分程度かかります
- 完了すると自動的にブラウザが開きます（http://localhost:1337/admin）
- 管理者アカウントの作成画面が表示されます

### 2.3 Strapi管理者アカウントの作成

ブラウザで管理画面が開いたら：

1. **管理者アカウント情報を入力**:
   - First name: `Admin`
   - Last name: `User`
   - Email: `admin@example.com`
   - Password: `AdminPassword123!`（安全なパスワードを設定）

2. **アカウント作成**をクリック

3. **ダッシュボード**が表示されることを確認

### 2.4 サンプルコンテンツタイプの作成

学習用のシンプルなコンテンツタイプを作成します：

1. **Content-Type Builder**をクリック
2. **Create new collection type**をクリック
3. **Display name**: `Article`と入力
4. **Continue**をクリック
5. 以下のフィールドを追加：

   **Title フィールド**:
   - **Add another field** → **Text**
   - **Name**: `title`
   - **Advanced Settings** → **Required field**: チェック
   - **Finish**

   **Content フィールド**:
   - **Add another field** → **Rich Text**
   - **Name**: `content`
   - **Finish**

   **Published At フィールド**:
   - **Add another field** → **Date**
   - **Name**: `publishedAt`
   - **Finish**

6. **Save**をクリック
7. Strapiが再起動されます（1-2分待機）

### 2.5 サンプルデータの作成

1. **Content Manager**をクリック
2. **Article**をクリック
3. **Create new entry**をクリック
4. サンプルデータを入力：
   - **Title**: `初めての記事`
   - **Content**: `これは学習用のサンプル記事です。`
   - **PublishedAt**: 今日の日付
5. **Save**をクリック
6. **Publish**をクリック

### 2.6 API アクセス権限の設定

デフォルトでは、APIは外部からアクセスできません。設定を変更します：

1. **Settings**をクリック
2. **Users & Permissions Plugin** → **Roles**をクリック
3. **Public**をクリック
4. **Article**セクションを展開
5. 以下にチェックを入れる：
   - **find** (記事一覧の取得)
   - **findOne** (個別記事の取得)
6. **Save**をクリック

### 2.7 API動作確認

新しいターミナルを開いて、APIが動作することを確認：

```bash
# 記事一覧の取得
curl http://localhost:1337/api/articles

# 期待される結果: JSON形式で記事データが返される
```

## Step 3: Webアプリケーションの作成

### 3.1 Next.jsアプリケーションの作成

```bash
# プロジェクトルートに戻る
cd ..

# web-appディレクトリに移動
cd web-app

# Next.jsプロジェクトを作成
npx create-next-app@latest . --typescript --tailwind --eslint --app --src-dir --import-alias "@/*"

# 注意: 各オプションの説明
# --typescript: TypeScriptを使用
# --tailwind: Tailwind CSSを使用
# --eslint: ESLintを使用
# --app: App Routerを使用（新しいルーティング方式）
# --src-dir: srcディレクトリを使用
# --import-alias: インポートエイリアスを設定
```

### 3.2 Strapiとの連携設定

#### 3.2.1 環境変数の設定

```bash
# .env.localファイルを作成
cat > .env.local << 'EOF'
NEXT_PUBLIC_STRAPI_URL=http://localhost:1337
EOF
```

#### 3.2.2 Strapi APIクライアントの作成

```bash
# APIクライアント用のディレクトリを作成
mkdir -p src/lib

# APIクライアントファイルを作成
cat > src/lib/strapi.ts << 'EOF'
const STRAPI_URL = process.env.NEXT_PUBLIC_STRAPI_URL || 'http://localhost:1337';

export interface Article {
  id: number;
  attributes: {
    title: string;
    content: string;
    publishedAt: string;
    createdAt: string;
    updatedAt: string;
  };
}

export interface StrapiResponse<T> {
  data: T;
  meta: {
    pagination?: {
      page: number;
      pageSize: number;
      pageCount: number;
      total: number;
    };
  };
}

export async function getArticles(): Promise<Article[]> {
  try {
    const response = await fetch(`${STRAPI_URL}/api/articles`);
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }
    const data: StrapiResponse<Article[]> = await response.json();
    return data.data;
  } catch (error) {
    console.error('Error fetching articles:', error);
    return [];
  }
}

export async function getArticle(id: string): Promise<Article | null> {
  try {
    const response = await fetch(`${STRAPI_URL}/api/articles/${id}`);
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }
    const data: StrapiResponse<Article> = await response.json();
    return data.data;
  } catch (error) {
    console.error('Error fetching article:', error);
    return null;
  }
}
EOF
```

#### 3.2.3 記事一覧ページの作成

```bash
# メインページを更新
cat > src/app/page.tsx << 'EOF'
import { getArticles } from '@/lib/strapi';
import Link from 'next/link';

export default async function Home() {
  const articles = await getArticles();

  return (
    <main className="container mx-auto px-4 py-8">
      <h1 className="text-3xl font-bold mb-8">記事一覧</h1>
      
      {articles.length === 0 ? (
        <div className="text-center py-8">
          <p className="text-gray-600">記事がありません。</p>
          <p className="text-sm text-gray-500 mt-2">
            Strapiの管理画面で記事を作成してください。
          </p>
        </div>
      ) : (
        <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-3">
          {articles.map((article) => (
            <div key={article.id} className="border rounded-lg p-6 hover:shadow-lg transition-shadow">
              <h2 className="text-xl font-semibold mb-2">
                <Link 
                  href={`/articles/${article.id}`}
                  className="text-blue-600 hover:text-blue-800"
                >
                  {article.attributes.title}
                </Link>
              </h2>
              <p className="text-gray-600 text-sm mb-4">
                公開日: {new Date(article.attributes.publishedAt).toLocaleDateString('ja-JP')}
              </p>
              <div 
                className="text-gray-700 line-clamp-3"
                dangerouslySetInnerHTML={{ 
                  __html: article.attributes.content.substring(0, 100) + '...' 
                }}
              />
            </div>
          ))}
        </div>
      )}
      
      <div className="mt-8 p-4 bg-blue-50 rounded-lg">
        <h3 className="font-semibold text-blue-800 mb-2">接続状況</h3>
        <p className="text-blue-700 text-sm">
          Strapi API: {process.env.NEXT_PUBLIC_STRAPI_URL}
        </p>
        <p className="text-blue-700 text-sm">
          記事数: {articles.length}件
        </p>
      </div>
    </main>
  );
}
EOF
```

#### 3.2.4 個別記事ページの作成

```bash
# 記事詳細ページ用のディレクトリを作成
mkdir -p src/app/articles/[id]

# 記事詳細ページを作成
cat > src/app/articles/[id]/page.tsx << 'EOF'
import { getArticle } from '@/lib/strapi';
import Link from 'next/link';
import { notFound } from 'next/navigation';

interface Props {
  params: {
    id: string;
  };
}

export default async function ArticlePage({ params }: Props) {
  const article = await getArticle(params.id);

  if (!article) {
    notFound();
  }

  return (
    <main className="container mx-auto px-4 py-8">
      <Link 
        href="/"
        className="text-blue-600 hover:text-blue-800 mb-4 inline-block"
      >
        ← 記事一覧に戻る
      </Link>
      
      <article className="max-w-3xl">
        <h1 className="text-4xl font-bold mb-4">
          {article.attributes.title}
        </h1>
        
        <div className="text-gray-600 mb-8">
          <p>公開日: {new Date(article.attributes.publishedAt).toLocaleDateString('ja-JP')}</p>
          <p>更新日: {new Date(article.attributes.updatedAt).toLocaleDateString('ja-JP')}</p>
        </div>
        
        <div 
          className="prose max-w-none"
          dangerouslySetInnerHTML={{ __html: article.attributes.content }}
        />
      </article>
    </main>
  );
}
EOF
```

### 3.3 Webアプリケーションの起動と確認

```bash
# 開発サーバーを起動
npm run dev
```

ブラウザで `http://localhost:3000` を開いて、以下を確認：

1. **記事一覧が表示される**
2. **記事をクリックすると詳細ページに移動する**
3. **Strapiで作成した記事が正しく表示される**

## Step 4: 動作確認とトラブルシューティング

### 4.1 正常動作の確認項目

- [ ] Strapi管理画面にアクセスできる（http://localhost:1337/admin）
- [ ] Strapi APIが応答する（curl http://localhost:1337/api/articles）
- [ ] Next.jsアプリが起動する（http://localhost:3000）
- [ ] WebアプリでStrapi記事が表示される
- [ ] 記事の詳細ページが表示される

### 4.2 よくあるトラブルと解決方法

#### Strapiが起動しない
```bash
# ポートが使用されている場合
sudo lsof -i :1337
# 該当プロセスを終了してから再起動

# 依存関係の問題
cd strapi-app
rm -rf node_modules package-lock.json
npm install
```

#### Next.jsでAPIが取得できない
```bash
# CORSエラーの場合、Strapiの設定を確認
# strapi-app/config/middlewares.js を確認

# 環境変数の確認
cat web-app/.env.local
```

#### 記事が表示されない
1. Strapi管理画面で記事が**Published**状態か確認
2. **Settings** → **Roles** → **Public**でAPI権限が設定されているか確認

### 4.3 学習記録の開始

この段階で、学習記録を開始しましょう：

```bash
# 学習記録ファイルを作成
cat > learning-log.md << 'EOF'
# インフラ構成学習記録

## Phase 1: 基礎準備

### 実施日
- 開始: [日付を記入]
- 完了: [日付を記入]

### 詰まったポイント
- [詰まった内容と解決方法を記録]

### 学んだこと
- [新しく理解したことを記録]

### 所要時間
- Strapi セットアップ: [時間]
- Next.js セットアップ: [時間]
- API連携: [時間]
- 合計: [時間]

### 感想
- [作業の感想、難易度、理解度など]

---
EOF
```

## 次のステップ

Phase 1が完了したら、以下のドキュメントに進んでください：

- **VPS構成を体験したい場合**: `docs/phase2-vps.md`
- **AWS構成から始めたい場合**: `docs/phase3-aws-strapi-only.md`

**おすすめの順序**: VPS → StrapiのみAWS → 全てAWS

---

**お疲れ様でした！基礎準備が完了しました。実際のインフラ構成の体験に進みましょう！** 