# Strapi専用AWS構成 + 既存web-app連携ガイド

## 概要

この構成では、StrapiをAWS（ECS Fargate + RDS + S3）で運用し、既存の`web-app`をローカルまたは別のプラットフォーム（Vercel等）で運用します。

## アーキテクチャ

```
[Local/Vercel] Next.js web-app
        |
        | HTTPS API calls
        |
        v
[AWS ALB] → [ECS Fargate] Strapi
                |
                v
        [RDS PostgreSQL] + [S3 Assets]
```

## 前提条件

1. AWS CLI設定済み
2. Terraform >= 1.0
3. Node.js 20.x
4. 既存web-appが動作可能

## デプロイ手順

### Step 1: Strapi AWS環境のデプロイ

```bash
# Strapi専用AWS構成をデプロイ
cd infrastructure/aws-strapi-only
terraform init
terraform plan
terraform apply

# デプロイ後の情報を取得
STRAPI_URL=$(terraform output -raw strapi_url)
RDS_ENDPOINT=$(terraform output -raw rds_endpoint)
S3_BUCKET=$(terraform output -raw s3_bucket_name)

echo "Strapi URL: $STRAPI_URL"
echo "RDS Endpoint: $RDS_ENDPOINT"
echo "S3 Bucket: $S3_BUCKET"
```

### Step 2: web-appの環境設定

```bash
# web-appディレクトリに移動
cd ../../web-app

# 環境変数ファイル作成
cat > .env.local << EOF
# Node.js環境
NODE_ENV=development

# データベース接続（ローカル開発用）
DATABASE_URL="file:./prisma/dev.db"

# NextAuth設定
NEXTAUTH_URL=http://localhost:3000
NEXTAUTH_SECRET=your-nextauth-secret-here

# Strapi API接続（AWS）
NEXT_PUBLIC_STRAPI_URL=$STRAPI_URL
STRAPI_API_TOKEN=your-strapi-api-token

# AWS設定（必要に応じて）
AWS_REGION=ap-northeast-1
AWS_S3_BUCKET=$S3_BUCKET
EOF
```

### Step 3: Strapiの初期設定

```bash
# Strapi管理画面にアクセス
open $STRAPI_URL/admin

# 管理者アカウント作成
# 1. 管理画面で管理者アカウントを作成
# 2. Settings → API Tokens → Create new API Token
# 3. Token Type: Read-Only または Full access
# 4. 生成されたトークンを.env.localのSTRAPI_API_TOKENに設定
```

### Step 4: web-appでのStrapi連携設定

#### 4.1 Strapi APIクライアントの作成

```bash
# web-app/src/lib/strapi.ts を作成
cat > src/lib/strapi.ts << 'EOF'
const STRAPI_URL = process.env.NEXT_PUBLIC_STRAPI_URL || 'http://localhost:1337';
const STRAPI_TOKEN = process.env.STRAPI_API_TOKEN;

interface StrapiResponse<T> {
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

class StrapiClient {
  private baseURL: string;
  private token?: string;

  constructor(baseURL: string, token?: string) {
    this.baseURL = baseURL;
    this.token = token;
  }

  private async request<T>(endpoint: string, options: RequestInit = {}): Promise<T> {
    const url = `${this.baseURL}/api${endpoint}`;
    const headers: HeadersInit = {
      'Content-Type': 'application/json',
      ...options.headers,
    };

    if (this.token) {
      headers.Authorization = `Bearer ${this.token}`;
    }

    const response = await fetch(url, {
      ...options,
      headers,
    });

    if (!response.ok) {
      throw new Error(`Strapi API error: ${response.status} ${response.statusText}`);
    }

    return response.json();
  }

  // ニュース取得
  async getNews(params?: {
    page?: number;
    pageSize?: number;
    sort?: string;
    filters?: Record<string, any>;
  }): Promise<StrapiResponse<any[]>> {
    const searchParams = new URLSearchParams();
    
    if (params?.page) searchParams.set('pagination[page]', params.page.toString());
    if (params?.pageSize) searchParams.set('pagination[pageSize]', params.pageSize.toString());
    if (params?.sort) searchParams.set('sort', params.sort);
    
    if (params?.filters) {
      Object.entries(params.filters).forEach(([key, value]) => {
        searchParams.set(`filters[${key}]`, value);
      });
    }

    const query = searchParams.toString();
    return this.request(`/news${query ? `?${query}` : ''}`);
  }

  // 単一ニュース取得
  async getNewsById(id: string): Promise<StrapiResponse<any>> {
    return this.request(`/news/${id}`);
  }

  // イベント取得
  async getEvents(params?: {
    page?: number;
    pageSize?: number;
    sort?: string;
    filters?: Record<string, any>;
  }): Promise<StrapiResponse<any[]>> {
    const searchParams = new URLSearchParams();
    
    if (params?.page) searchParams.set('pagination[page]', params.page.toString());
    if (params?.pageSize) searchParams.set('pagination[pageSize]', params.pageSize.toString());
    if (params?.sort) searchParams.set('sort', params.sort);
    
    if (params?.filters) {
      Object.entries(params.filters).forEach(([key, value]) => {
        searchParams.set(`filters[${key}]`, value);
      });
    }

    const query = searchParams.toString();
    return this.request(`/tournaments${query ? `?${query}` : ''}`);
  }

  // 単一イベント取得
  async getEventById(id: string): Promise<StrapiResponse<any>> {
    return this.request(`/tournaments/${id}`);
  }
}

export const strapiClient = new StrapiClient(STRAPI_URL, STRAPI_TOKEN);
export default strapiClient;
EOF
```

#### 4.2 React Queryフック作成

```bash
# web-app/src/hooks/useStrapi.ts を作成
cat > src/hooks/useStrapi.ts << 'EOF'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import strapiClient from '@/lib/strapi';

// ニュース関連フック
export function useNews(params?: {
  page?: number;
  pageSize?: number;
  sort?: string;
  filters?: Record<string, any>;
}) {
  return useQuery({
    queryKey: ['news', params],
    queryFn: () => strapiClient.getNews(params),
    staleTime: 5 * 60 * 1000, // 5分
  });
}

export function useNewsById(id: string) {
  return useQuery({
    queryKey: ['news', id],
    queryFn: () => strapiClient.getNewsById(id),
    enabled: !!id,
  });
}

// イベント関連フック
export function useEvents(params?: {
  page?: number;
  pageSize?: number;
  sort?: string;
  filters?: Record<string, any>;
}) {
  return useQuery({
    queryKey: ['events', params],
    queryFn: () => strapiClient.getEvents(params),
    staleTime: 5 * 60 * 1000, // 5分
  });
}

export function useEventById(id: string) {
  return useQuery({
    queryKey: ['events', id],
    queryFn: () => strapiClient.getEventById(id),
    enabled: !!id,
  });
}
EOF
```

### Step 5: web-appの起動と動作確認

```bash
# 依存関係インストール
npm install

# Prismaクライアント生成
npx prisma generate

# データベースマイグレーション（ローカル）
npx prisma migrate dev

# 開発サーバー起動
npm run dev
```

### Step 6: 動作確認

#### 6.1 基本接続確認

```bash
# Strapi API接続確認
curl -H "Authorization: Bearer $STRAPI_API_TOKEN" \
     "$STRAPI_URL/api/news"

# web-app接続確認
curl http://localhost:3000/api/health
```

#### 6.2 統合テスト

1. **Strapi管理画面でコンテンツ作成**
   - `$STRAPI_URL/admin` にアクセス
   - ニュース記事を作成・公開

2. **web-appでの表示確認**
   - `http://localhost:3000` にアクセス
   - Strapiから取得したコンテンツが表示されることを確認

## 本番環境での運用

### Vercelデプロイ

```bash
# Vercelプロジェクト作成
npx vercel

# 環境変数設定
vercel env add NEXT_PUBLIC_STRAPI_URL
vercel env add STRAPI_API_TOKEN
vercel env add NEXTAUTH_SECRET
vercel env add DATABASE_URL

# デプロイ
vercel --prod
```

### 環境変数設定

```bash
# Vercel環境変数（本番用）
NEXT_PUBLIC_STRAPI_URL=https://your-strapi-alb-url.com
STRAPI_API_TOKEN=your-production-api-token
NEXTAUTH_SECRET=your-production-nextauth-secret
DATABASE_URL=postgresql://user:pass@your-db-host:5432/dbname
```

## トラブルシューティング

### よくある問題

1. **CORS エラー**
   ```bash
   # Strapi設定で許可するオリジンを追加
   # config/middlewares.js で設定
   ```

2. **API Token認証エラー**
   ```bash
   # Strapiでトークンの権限を確認
   # Settings → API Tokens → 権限設定
   ```

3. **データベース接続エラー**
   ```bash
   # RDSセキュリティグループの確認
   aws ec2 describe-security-groups --group-ids sg-xxxxx
   ```

## 監視・ログ

### CloudWatch監視

```bash
# Strapi ECSログ確認
aws logs tail /ecs/strapi-task --follow

# ALBアクセスログ確認
aws s3 ls s3://your-alb-logs-bucket/
```

### パフォーマンス監視

```bash
# RDS監視
aws rds describe-db-instances --db-instance-identifier your-rds-instance

# ECS監視
aws ecs describe-services --cluster your-cluster --services strapi-service
```

## コスト最適化

### 無料枠使用量確認

```bash
# 現在の使用量確認
aws ce get-dimension-values \
  --dimension Key \
  --time-period Start=2024-01-01,End=2024-01-31

# 予算アラート設定
aws budgets create-budget \
  --account-id your-account-id \
  --budget file://budget.json
```

## セキュリティ

### API Token管理

1. **定期的なトークンローテーション**
2. **最小権限の原則**
3. **環境変数での管理**

### ネットワークセキュリティ

1. **ALBでのHTTPS強制**
2. **セキュリティグループの最小化**
3. **WAF設定**

## バックアップ・復旧

### RDSバックアップ

```bash
# 手動スナップショット作成
aws rds create-db-snapshot \
  --db-instance-identifier your-rds-instance \
  --db-snapshot-identifier manual-snapshot-$(date +%Y%m%d)
```

### S3バックアップ

```bash
# アセットバックアップ
aws s3 sync s3://your-strapi-bucket ./backup/
``` 