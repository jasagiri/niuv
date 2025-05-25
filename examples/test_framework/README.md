# テストフレームワーク使用例

このディレクトリには、niuvの拡張テストフレームワークの使用例が含まれています。

## 含まれるサンプル

### 1. 基本テスト (`basic_test.nim`)

power_assert_nim の自動拡張を使用した基本的なテスト例です。
詳細なアサーションメッセージを表示しながら、シンプルな単体テストを実行します。

```bash
nim c -r basic_test.nim
```

### 2. カスタムレポート形式 (`reporting_test.nim`)

複数のレポート形式（コンソール、JSON、HTML）を使用したテスト実行例です。
テスト結果をファイルに保存し、様々な形式でレポートを生成します。

```bash
nim c -r reporting_test.nim
```

### 3. Cucumber 統合 (`cucumber_test.nim`)

cucumber_nim と拡張テストフレームワークを統合した例です。
BDDスタイルのテストにカスタムレポート機能を適用します。

```bash
nim c -r cucumber_test.nim
```

## 機能

このテストフレームワークは以下の機能を提供します：

1. **強化されたアサーション**: power_assert_nim による詳細なアサーションメッセージ
2. **カスタマイズ可能なレポート**: コンソール、JSON、HTML形式でのレポート出力
3. **Cucumber統合**: BDDスタイルのテストとの統合
4. **統計情報**: テスト実行の詳細な統計情報

## 使い方の基本

1. プロジェクトに `src/test_enhanced.nim` をインポート
2. `runTests` テンプレート内にテストケースを記述
3. 必要に応じてカスタムレポートフォーマッタを設定

```nim
import test_enhanced
import reporting

# カスタムフォーマッタを追加（オプション）
addFormatter(newHtmlReportFormatter("report.html"))

# テストを実行
runTests:
  suite "My Tests":
    test "Example test":
      check(1 + 1 == 2)
```

## レポート出力カスタマイズ

```nim
# JSONレポート
addFormatter(newJsonReportFormatter("results.json"))

# HTML出力（カスタムCSS付き）
addFormatter(newHtmlReportFormatter(
  outputFile = "report.html",
  title = "マイプロジェクトテスト結果",
  cssStyle = "h1 { color: blue; }"
))
```