'use client';

import { useState } from 'react';

interface FreeTierService {
  name: string;
  category: string;
  limits: {
    requests?: string;
    bandwidth?: string;
    storage?: string;
    buildTime?: string;
    memory?: string;
    cpu?: string;
  };
  pros: string[];
  cons: string[];
  cost: string;
  status: 'active' | 'testing' | 'inactive';
}

const freeTierServices: FreeTierService[] = [
  {
    name: "Vercel",
    category: "フロントエンド",
    limits: {
      requests: "100GB/月",
      bandwidth: "100GB/月",
      buildTime: "6000分/月",
      memory: "1GB",
    },
    pros: [
      "高速CDN",
      "自動デプロイ",
      "プレビュー環境",
      "ドメイン付き"
    ],
    cons: [
      "商用利用制限",
      "ビルド時間制限",
      "関数実行時間制限"
    ],
    cost: "無料",
    status: 'active'
  },
  {
    name: "Railway",
    category: "バックエンド",
    limits: {
      requests: "無制限",
      memory: "512MB",
      cpu: "共有",
      storage: "1GB"
    },
    pros: [
      "簡単デプロイ",
      "データベース付き",
      "ログ監視",
      "自動スケール"
    ],
    cons: [
      "月500時間制限",
      "メモリ制限",
      "スリープ機能"
    ],
    cost: "無料 (制限付き)",
    status: 'testing'
  },
  {
    name: "Supabase",
    category: "データベース",
    limits: {
      storage: "500MB",
      requests: "50,000/月",
      bandwidth: "2GB/月"
    },
    pros: [
      "PostgreSQL",
      "リアルタイム機能",
      "認証機能",
      "API自動生成"
    ],
    cons: [
      "ストレージ制限",
      "リクエスト制限",
      "7日間非アクティブで停止"
    ],
    cost: "無料",
    status: 'active'
  },
  {
    name: "Cloudinary",
    category: "画像ストレージ",
    limits: {
      storage: "25GB",
      bandwidth: "25GB/月",
      requests: "25,000/月"
    },
    pros: [
      "画像最適化",
      "変換機能",
      "CDN配信",
      "AI機能"
    ],
    cons: [
      "容量制限",
      "変換回数制限",
      "透かし表示"
    ],
    cost: "無料",
    status: 'active'
  },
  {
    name: "Oracle Cloud",
    category: "VPS",
    limits: {
      memory: "24GB",
      cpu: "4 OCPU",
      storage: "200GB",
      bandwidth: "10TB/月"
    },
    pros: [
      "高スペック",
      "永続無料",
      "完全制御",
      "複数インスタンス"
    ],
    cons: [
      "設定複雑",
      "サポート限定",
      "リージョン制限"
    ],
    cost: "永続無料",
    status: 'inactive'
  }
];

export default function FreeTierPage() {
  const [selectedService, setSelectedService] = useState<FreeTierService | null>(null);
  const [limitTest, setLimitTest] = useState({
    requests: 0,
    bandwidth: 0,
    errors: 0
  });
  const [isTestingLimits, setIsTestingLimits] = useState(false);

  // 制限テストシミュレーション
  const testLimits = async () => {
    setIsTestingLimits(true);
    setLimitTest({ requests: 0, bandwidth: 0, errors: 0 });

    for (let i = 0; i < 50; i++) {
      await new Promise(resolve => setTimeout(resolve, 100));
      
      setLimitTest(prev => ({
        requests: prev.requests + 1,
        bandwidth: prev.bandwidth + Math.random() * 100,
        errors: Math.random() > 0.9 ? prev.errors + 1 : prev.errors
      }));
    }
    
    setIsTestingLimits(false);
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-green-50 to-blue-100 dark:from-gray-900 dark:to-gray-800">
      <div className="container mx-auto px-4 py-8">
        {/* ヘッダー */}
        <header className="text-center mb-12">
          <h1 className="text-4xl font-bold text-gray-800 dark:text-white mb-4">
            🆓 無料枠インフラ構成比較
          </h1>
          <p className="text-lg text-gray-600 dark:text-gray-300">
            無料枠サービスを活用したインフラ構成の制限と特徴を体験
          </p>
        </header>

        {/* 制限テストセクション */}
        <div className="bg-white dark:bg-gray-800 rounded-lg shadow-lg p-6 mb-8">
          <h2 className="text-xl font-semibold mb-4 text-gray-800 dark:text-white">
            無料枠制限テスト
          </h2>
          
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-4">
            <div className="text-center">
              <div className="text-2xl font-bold text-blue-600">{limitTest.requests}</div>
              <div className="text-sm text-gray-600">リクエスト数</div>
            </div>
            <div className="text-center">
              <div className="text-2xl font-bold text-green-600">{limitTest.bandwidth.toFixed(1)}KB</div>
              <div className="text-sm text-gray-600">帯域使用量</div>
            </div>
            <div className="text-center">
              <div className="text-2xl font-bold text-red-600">{limitTest.errors}</div>
              <div className="text-sm text-gray-600">エラー数</div>
            </div>
          </div>

          <button
            onClick={testLimits}
            disabled={isTestingLimits}
            className={`w-full py-2 px-4 rounded-lg font-medium transition-colors ${
              isTestingLimits
                ? 'bg-gray-400 cursor-not-allowed'
                : 'bg-blue-600 hover:bg-blue-700 text-white'
            }`}
          >
            {isTestingLimits ? '制限テスト実行中...' : '無料枠制限をテスト'}
          </button>
        </div>

        {/* サービス比較カード */}
        <div className="grid grid-cols-1 lg:grid-cols-2 xl:grid-cols-3 gap-6 mb-8">
          {freeTierServices.map((service, index) => (
            <div
              key={index}
              className={`bg-white dark:bg-gray-800 rounded-lg shadow-lg p-6 cursor-pointer transition-all duration-300 hover:shadow-xl ${
                service.status === 'active' ? 'ring-2 ring-green-500' : 
                service.status === 'testing' ? 'ring-2 ring-yellow-500' : ''
              } ${selectedService === service ? 'ring-2 ring-blue-500' : ''}`}
              onClick={() => setSelectedService(service)}
            >
              <div className="flex justify-between items-start mb-4">
                <div>
                  <h3 className="text-lg font-semibold text-gray-800 dark:text-white">
                    {service.name}
                  </h3>
                  <p className="text-sm text-gray-500">{service.category}</p>
                </div>
                <span className={`px-2 py-1 rounded-full text-xs font-medium ${
                  service.status === 'active' 
                    ? 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200'
                    : service.status === 'testing'
                    ? 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-200'
                    : 'bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-200'
                }`}>
                  {service.status === 'active' ? '利用中' : 
                   service.status === 'testing' ? 'テスト中' : '未使用'}
                </span>
              </div>
              
              <div className="space-y-2 text-sm text-gray-600 dark:text-gray-300 mb-4">
                {Object.entries(service.limits).map(([key, value]) => (
                  <div key={key} className="flex justify-between">
                    <span className="capitalize">{key}:</span>
                    <span className="font-medium">{value}</span>
                  </div>
                ))}
              </div>
              
              <div className="text-center">
                <span className="text-lg font-bold text-green-600">{service.cost}</span>
              </div>
            </div>
          ))}
        </div>

        {/* 詳細情報 */}
        {selectedService && (
          <div className="bg-white dark:bg-gray-800 rounded-lg shadow-lg p-6">
            <h2 className="text-2xl font-semibold mb-4 text-gray-800 dark:text-white">
              {selectedService.name} - 詳細分析
            </h2>
            
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div>
                <h3 className="text-lg font-semibold text-green-600 dark:text-green-400 mb-3">
                  メリット
                </h3>
                <ul className="space-y-2">
                  {selectedService.pros.map((pro, index) => (
                    <li key={index} className="flex items-start space-x-2">
                      <span className="text-green-500 mt-1">✓</span>
                      <span className="text-gray-700 dark:text-gray-300">{pro}</span>
                    </li>
                  ))}
                </ul>
              </div>
              
              <div>
                <h3 className="text-lg font-semibold text-red-600 dark:text-red-400 mb-3">
                  制限・デメリット
                </h3>
                <ul className="space-y-2">
                  {selectedService.cons.map((con, index) => (
                    <li key={index} className="flex items-start space-x-2">
                      <span className="text-red-500 mt-1">⚠</span>
                      <span className="text-gray-700 dark:text-gray-300">{con}</span>
                    </li>
                  ))}
                </ul>
              </div>
            </div>

            {/* 実装例 */}
            <div className="mt-6 p-4 bg-gray-100 dark:bg-gray-700 rounded-lg">
              <h4 className="font-semibold mb-2">実装コマンド例:</h4>
              <code className="text-sm">
                {selectedService.name === 'Vercel' && 'npx vercel --prod'}
                {selectedService.name === 'Railway' && 'railway deploy'}
                {selectedService.name === 'Supabase' && 'npx supabase start'}
                {selectedService.name === 'Cloudinary' && 'npm install cloudinary'}
                {selectedService.name === 'Oracle Cloud' && 'docker-compose up -d'}
              </code>
            </div>
          </div>
        )}

        {/* アクションボタン */}
        <div className="mt-8 text-center">
          <div className="space-x-4">
            <button className="bg-green-600 hover:bg-green-700 text-white font-medium py-2 px-6 rounded-lg transition-colors">
              無料枠構成をテスト
            </button>
            <button className="bg-blue-600 hover:bg-blue-700 text-white font-medium py-2 px-6 rounded-lg transition-colors">
              制限比較レポート
            </button>
            <button className="bg-purple-600 hover:bg-purple-700 text-white font-medium py-2 px-6 rounded-lg transition-colors">
              コスト計算機
            </button>
          </div>
        </div>
      </div>
    </div>
  );
} 