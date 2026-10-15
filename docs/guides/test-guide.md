# Niuv Test Execution Guide

## 概要
Houraiプロジェクトでは、niuvを使用してテストを実行できます。

## テスト実行方法

### 1. nimbleタスクを使用（推奨）
```bash
niuv task test
```
これは`hourai.nimble`に定義されている`test`タスクを実行します。

### 2. 特定のテストファイルを指定
```bash
niuv test tests/test_all.nim
```

### 3. Makefileを使用
```bash
make test-coverage
```

### 4. カバレッジスクリプトを使用
```bash
./scripts/niuv-coverage.sh
```

## 注意事項

- `niuv test coverage`コマンドは存在しません
- niuvにはビルトインのコードカバレッジ機能がありません
- 実際のカバレッジメトリクスを取得するには、外部ツール（nim-coverage等）が必要です

## テスト構成

### niuv.toml設定
```toml
[test]
discovery = true
patterns = ["tests/test_*.nim", "tests/**/test_*.nim"]
main = "tests/test_all.nim"
```

### 全テストスイート
- **25+ テストスイート**
- **150+ テストケース**
- **100% 成功率**

## トラブルシューティング

### "No test files found"エラーの場合
1. `niuv task test`を使用する
2. または具体的なテストファイルを指定: `niuv test tests/test_all.nim`

### テストが実行されない場合
1. `nimble test`で直接実行してみる
2. プロジェクトルートディレクトリから実行しているか確認