'use client';

import { useState, useEffect } from 'react';

interface InfraConfig {
  name: string;
  frontend: string;
  backend: string;
  database: string;
  storage: string;
  status: 'active' | 'inactive' | 'testing';
  description: string;
  pros: string[];
  cons: string[];
}

const infraConfigs: InfraConfig[] = [
  {
    name: "パターン1: StrapiのみAWS",
    frontend: "Vercel",
    backend: "AWS (ECS Fargate + Strapi)",
    database: "Supabase",
    storage: "CloudFlare Images",
    status: 'inactive',
    description: "フロントエンドはVercelで高速配信、バックエンドのみAWSで運用",
    pros: [
      "フロントエンドの高速配信",
      "AWS運用コストを抑制",
      "Supabaseの高機能DB",
      "CloudFlareの高速画像配信"
    ],
    cons: [
      "複数サービス管理の複雑性",
      "サービス間の連携設定",
      "障害時の影響範囲が広い"
    ]
  },
  {
    name: "パターン2: フルAWS",
    frontend: "AWS (ECS Fargate + Next.js)",
    backend: "AWS (ECS Fargate + Strapi)",
    database: "AWS RDS",
    storage: "AWS S3",
    status: 'inactive',
    description: "全てのコンポーネントをAWSで統一管理",
    pros: [
      "AWS内での完全統合",
      "統一された監視・ログ",
      "スケーラビリティ",
      "セキュリティの一元管理"
    ],
    cons: [
      "高いランニングコスト",
      "AWS依存度が高い",
      "設定の複雑性",
      "オーバーエンジニアリングのリスク"
    ]
  },
  {
    name: "パターン3: VPS構成",
    frontend: "VPS (Docker + Next.js)",
    backend: "VPS (Docker + Strapi)",
    database: "VPS (PostgreSQL)",
    storage: "VPS (ローカルストレージ)",
    status: 'active',
    description: "単一VPSでの完全自己管理型構成",
    pros: [
      "低コスト",
      "完全なコントロール",
      "シンプルな構成",
      "学習効果が高い"
    ],
    cons: [
      "手動スケーリング",
      "単一障害点",
      "運用負荷が高い",
      "セキュリティ管理が必要"
    ]
  }
];

export default function Home() {
  const [selectedConfig, setSelectedConfig] = useState<InfraConfig | null>(null);
  const [systemStatus, setSystemStatus] = useState({
    database: 'connected',
    api: 'healthy',
    storage: 'available'
  });

  useEffect(() => {
    // システム状態の監視をシミュレート
    const interval = setInterval(() => {
      setSystemStatus(prev => ({
        ...prev,
        api: Math.random() > 0.1 ? 'healthy' : 'warning'
      }));
    }, 5000);

    return () => clearInterval(interval);
  }, []);

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 dark:from-gray-900 dark:to-gray-800">
      <div className="container mx-auto px-4 py-8">
        {/* ヘッダー */}
        <header className="text-center mb-12">
          <h1 className="text-4xl font-bold text-gray-800 dark:text-white mb-4">
            インフラ構成比較デモ
          </h1>
          <p className="text-lg text-gray-600 dark:text-gray-300">
            3つの異なるインフラ構成パターンの特徴と違いを体験
          </p>
        </header>

        {/* システム状態 */}
        <div className="bg-white dark:bg-gray-800 rounded-lg shadow-lg p-6 mb-8">
          <h2 className="text-xl font-semibold mb-4 text-gray-800 dark:text-white">
            現在のシステム状態
          </h2>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div className="flex items-center space-x-2">
              <div className={`w-3 h-3 rounded-full ${
                systemStatus.database === 'connected' ? 'bg-green-500' : 'bg-red-500'
              }`}></div>
              <span className="text-gray-700 dark:text-gray-300">
                データベース: {systemStatus.database}
              </span>
            </div>
            <div className="flex items-center space-x-2">
              <div className={`w-3 h-3 rounded-full ${
                systemStatus.api === 'healthy' ? 'bg-green-500' : 'bg-yellow-500'
              }`}></div>
              <span className="text-gray-700 dark:text-gray-300">
                API: {systemStatus.api}
              </span>
            </div>
            <div className="flex items-center space-x-2">
              <div className={`w-3 h-3 rounded-full ${
                systemStatus.storage === 'available' ? 'bg-green-500' : 'bg-red-500'
              }`}></div>
              <span className="text-gray-700 dark:text-gray-300">
                ストレージ: {systemStatus.storage}
              </span>
            </div>
          </div>
        </div>

        {/* インフラ構成カード */}
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 mb-8">
          {infraConfigs.map((config, index) => (
            <div
              key={index}
              className={`bg-white dark:bg-gray-800 rounded-lg shadow-lg p-6 cursor-pointer transition-all duration-300 hover:shadow-xl ${
                config.status === 'active' ? 'ring-2 ring-green-500' : ''
              } ${selectedConfig === config ? 'ring-2 ring-blue-500' : ''}`}
              onClick={() => setSelectedConfig(config)}
            >
              <div className="flex justify-between items-start mb-4">
                <h3 className="text-lg font-semibold text-gray-800 dark:text-white">
                  {config.name}
                </h3>
                <span className={`px-2 py-1 rounded-full text-xs font-medium ${
                  config.status === 'active' 
                    ? 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200'
                    : config.status === 'testing'
                    ? 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-200'
                    : 'bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-200'
                }`}>
                  {config.status === 'active' ? '稼働中' : config.status === 'testing' ? 'テスト中' : '停止中'}
                </span>
              </div>
              
              <div className="space-y-2 text-sm text-gray-600 dark:text-gray-300">
                <div><strong>フロント:</strong> {config.frontend}</div>
                <div><strong>バックエンド:</strong> {config.backend}</div>
                <div><strong>DB:</strong> {config.database}</div>
                <div><strong>ストレージ:</strong> {config.storage}</div>
              </div>
              
              <p className="mt-4 text-sm text-gray-500 dark:text-gray-400">
                {config.description}
              </p>
            </div>
          ))}
        </div>

        {/* 詳細情報 */}
        {selectedConfig && (
          <div className="bg-white dark:bg-gray-800 rounded-lg shadow-lg p-6">
            <h2 className="text-2xl font-semibold mb-4 text-gray-800 dark:text-white">
              {selectedConfig.name} - 詳細分析
            </h2>
            
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div>
                <h3 className="text-lg font-semibold text-green-600 dark:text-green-400 mb-3">
                  メリット
                </h3>
                <ul className="space-y-2">
                  {selectedConfig.pros.map((pro, index) => (
                    <li key={index} className="flex items-start space-x-2">
                      <span className="text-green-500 mt-1">✓</span>
                      <span className="text-gray-700 dark:text-gray-300">{pro}</span>
          </li>
                  ))}
                </ul>
              </div>
              
              <div>
                <h3 className="text-lg font-semibold text-red-600 dark:text-red-400 mb-3">
                  デメリット
                </h3>
                <ul className="space-y-2">
                  {selectedConfig.cons.map((con, index) => (
                    <li key={index} className="flex items-start space-x-2">
                      <span className="text-red-500 mt-1">⚠</span>
                      <span className="text-gray-700 dark:text-gray-300">{con}</span>
          </li>
                  ))}
                </ul>
              </div>
            </div>
          </div>
        )}

        {/* アクションボタン */}
        <div className="mt-8 text-center">
          <div className="space-x-4">
            <button className="bg-blue-600 hover:bg-blue-700 text-white font-medium py-2 px-6 rounded-lg transition-colors">
              VPS構成をテスト
            </button>
            <button className="bg-gray-600 hover:bg-gray-700 text-white font-medium py-2 px-6 rounded-lg transition-colors">
              AWS構成をテスト
            </button>
            <button className="bg-purple-600 hover:bg-purple-700 text-white font-medium py-2 px-6 rounded-lg transition-colors">
              ハイブリッド構成をテスト
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
