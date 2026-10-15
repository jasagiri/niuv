# Niuv ツールエコシステムガイド

## 概要

Niuvは、Nimプロジェクトのための**仮想環境マネージャー**兼**タスクランナー**です。開発者が直接使用する**フロントエンドツール**として、様々なツールを統合的に管理します。

## エコシステムにおける役割

```
[開発者] ← 直接操作
    ↓
  [Niuv] ← フロントエンド
    ├─→ [環境管理] プロジェクト隔離
    ├─→ [パッケージ管理] 高速並列インストール
    └─→ [タスク委譲] 各ツールへの橋渡し
         ├─→ [ビルド] → nimble/build.nim → nim
         ├─→ [テスト] → nim-testkit/unittest
         └─→ [実装切替] → nim-implswitch
```

## Niuvの主要機能

### 1. 仮想環境管理
```bash
niuv init      # .niuv/ディレクトリ作成
niuv activate  # シェル環境の有効化
niuv shell     # サブシェルで実行
```

### 2. パッケージ管理
```bash
niuv install   # nimble.lockから高速インストール
niuv add pkg   # パッケージ追加
niuv update    # 依存関係更新
```

### 3. タスク委譲システム
```toml
# niuv.toml
[tool.niuv.delegation]
build = "nimble"    # ビルドはnimbleに委譲
test = "testkit"    # テストはnim-testkitに委譲
lint = "custom"     # カスタムスクリプトに委譲
```

## 他ツールとの統合

### nim-implswitchとの統合

```toml
[tool.niuv.testing]
# プロファイルベースの実装切り替え
profiles = ["mock", "real", "staging"]

[tool.niuv.testing.mock]
compile_flags = ["-d:useMocks"]
description = "開発用モック実装"

[tool.niuv.testing.real]
compile_flags = ["-d:useRealLibs"]
description = "本番ライブラリ使用"
environment = {
  DATABASE_URL = "postgres://localhost/test"
}
```

### nim-testkitとの統合

```toml
[tool.niuv.delegation]
test = "testkit"

[tool.niuv.testkit]
# nim-testkit固有の設定
categories = ["unit", "integration", "e2e"]
coverage = true
parallel = true
```

### ビルドシステムとの統合

```toml
[tool.niuv.delegation]
build = "custom"  # build.nimを使用

[tool.niuv.build]
# カスタムビルドスクリプトへの引数
profiles = {
  debug = ["--debugger:native", "--opt:none"],
  release = ["--opt:speed", "--danger"]
}
```

## 開発者ワークフロー

### 基本的な使い方

```bash
# 1. プロジェクト初期化
cd myproject
niuv init
niuv activate

# 2. 開発サイクル
niuv install              # 依存関係インストール
niuv test                 # テスト実行（デフォルト）
niuv test --profile=real  # 本番実装でテスト
niuv build                # ビルド
niuv run myapp           # アプリ実行

# 3. リリース準備
niuv test --profile=staging
niuv build --profile=release
```

### プロファイルの活用

```bash
# 開発時（高速、モック使用）
niuv test --profile=dev

# CI/CD（両方テスト）
niuv test --profile=mock
niuv test --profile=real

# 本番デプロイ
niuv build --profile=production
```

## 設定例：フルスタックプロジェクト

```toml
# niuv.toml
[package]
name = "myapp"
version = "1.0.0"

[tool.niuv]
nim_version = "2.2.0"
isolation = true

[tool.niuv.delegation]
build = "custom"
test = "testkit"
lint = "nimpretty"
docs = "nimdoc"

[tool.niuv.testing]
profiles = ["unit", "integration", "e2e"]

[tool.niuv.testing.unit]
compile_flags = ["-d:useMocks", "-d:testing"]
test_command = "nim c -r tests/unit/test_all.nim"

[tool.niuv.testing.integration]
compile_flags = ["-d:useRealLibs"]
test_command = "nim c -r tests/integration/test_all.nim"
services = ["postgres", "redis"]  # Docker services

[tool.niuv.testing.e2e]
compile_flags = ["-d:useRealLibs", "-d:release"]
test_command = "nim c -r tests/e2e/test_all.nim"
environment = {
  API_URL = "http://localhost:8080"
}

[dependencies]
# niuvが管理する依存関係
nim-implswitch = ">=0.0.1"
nim-testkit = ">=1.0.0"
```

## トラブルシューティング

### よくある質問

**Q: niuvとnimbleの違いは？**
A: niuvは仮想環境管理に特化し、実際のビルドはnimbleに委譲できます。両方使うことも、niuvだけ使うことも可能です。

**Q: nim-implswitchは必須？**
A: いいえ。モック/実装切り替えが必要な場合のみ使用します。

**Q: 既存プロジェクトでの導入は？**
A: `niuv init`で簡単に導入でき、既存のnimbleファイルもそのまま使えます。

## まとめ

- **Niuv**: 開発者が使うフロントエンドツール
- **役割**: 環境管理 + タスク委譲
- **利点**: 統一インターフェースで複数ツールを管理
- **柔軟性**: 必要なツールだけを選択的に使用可能