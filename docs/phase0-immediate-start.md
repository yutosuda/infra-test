# Phase 0: 今すぐ開始 - ローカル環境でのStrapi体験

## 🚀 **AWSアカウント不要！今すぐ開始できます**

まずはローカル環境でStrapiとNext.jsの連携を体験し、基本的な仕組みを理解しましょう。

### **所要時間**: 1-2時間
### **必要なもの**: 現在の環境のみ（追加アカウント不要）

---

## Step 1: Strapiアプリケーションの作成

```bash
# プロジェクトルートにいることを確認
pwd
# /home/suda/infra-test であることを確認

# Strapiアプリケーションを作成
cd strapi-app
npx create-strapi-app@latest . --quickstart

# 注意: 初回は5-10分程度かかります
# 完了すると自動的にブラウザが開きます
```

### **初回セットアップ**
1. **ブラウザが自動で開く**: `http://localhost:1337/admin`
2. **管理者アカウントを作成**:
   - First name: `Admin`
   - Last name: `User` 
   - Email: `admin@example.com`
   - Password: `AdminPassword123!`

### **サンプルコンテンツの作成**
1. **Content-Type Builder** → **Create new collection type**
2. **Display name**: `Article`
3. **フィールドを追加**:
   - **Text**: `title` (Required)
   - **Rich Text**: `content`
   - **Date**: `publishedAt`
4. **Save** → Strapiが再起動

### **API権限の設定**
1. **Settings** → **Users & Permissions Plugin** → **Roles**
2. **Public** → **Article**セクション
3. **find** と **findOne** にチェック
4. **Save**

### **サンプル記事の作成**
1. **Content Manager** → **Article** → **Create new entry**
2. データを入力:
   - Title: `初めての記事`
   - Content: `これは学習用のサンプル記事です。`
   - PublishedAt: 今日の日付
3. **Save** → **Publish**

---

## Step 2: Next.jsアプリケーションの作成

```bash
# 新しいターミナルを開く（Strapiは起動したまま）
cd /home/suda/infra-test/web-app

# Next.jsアプリケーションを作成
npx create-next-app@latest . --typescript --tailwind --eslint --app --src-dir --import-alias "@/*"

# 環境変数を設定
echo "NEXT_PUBLIC_STRAPI_URL=http://localhost:1337" > .env.local
```

### **Strapi連携コードの作成**

```bash
# APIクライアントを作成
mkdir -p src/lib
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

# 記事詳細ページを作成
mkdir -p src/app/articles/[id]
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

# Next.jsアプリケーションを起動
npm run dev
```

### **動作確認**
1. **Strapi**: `http://localhost:1337/admin` で管理画面
2. **Next.js**: `http://localhost:3000` でWebアプリ
3. **API**: `http://localhost:1337/api/articles` でJSON確認

---

## Step 3: 基本的な体験と記録

### **体験すべきポイント**
- [ ] Strapiでコンテンツを作成・編集
- [ ] WebアプリでAPIデータが表示されることを確認
- [ ] 記事の追加・削除・更新を試す
- [ ] API権限の変更を試す（Public権限を外すとどうなるか）

### **学習記録の開始**
```bash
# 学習記録ファイルを作成
cat > /home/suda/infra-test/learning-log.md << 'EOF'
# インフラ構成学習記録

## Phase 0: ローカル環境体験

### 実施日
- 開始: [今日の日付]
- 完了: [完了日]

### 体験内容
- [ ] Strapiのセットアップ
- [ ] Next.jsのセットアップ  
- [ ] API連携の確認
- [ ] コンテンツの作成・編集

### 詰まったポイント
- [詰まった内容と解決方法を記録]

### 所要時間
- Strapiセットアップ: [時間]
- Next.jsセットアップ: [時間]
- API連携: [時間]
- 合計: [時間]

### 感想
- [作業の感想、理解度など]

---
EOF
```

---

## 🎉 **Phase 0完了！次のステップ**

ローカル環境での基本的な仕組みが理解できたら、次のフェーズに進みましょう。

### **次の選択肢**
1. **VPS体験**: 手動運用の大変さを体験
2. **AWS体験**: クラウドの複雑さを体験

どちらから始めても構いませんが、**VPSから始めることをおすすめ**します。 