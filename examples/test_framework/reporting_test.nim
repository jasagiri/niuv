## reporting_test.nim
## ================
##
## カスタムレポートフォーマッタの使用例
## 複数の出力形式を組み合わせてテスト結果を表示
##

import std/[strutils, os, streams]
import ../../src/test_enhanced
import ../../src/reporting

# レポートフォーマッタを設定
var formatters: seq[ReportFormatter] = @[]

# 1. コンソール出力（デフォルト、色付き）
formatters.add(newConsoleReportFormatter(
  colored = true,
  verbosityLevel = 2  # 詳細出力
))

# 2. JSON出力（ファイルに保存）
let reportDir = "reports"
if not dirExists(reportDir):
  createDir(reportDir)

formatters.add(newJsonReportFormatter(
  outputFile = reportDir / "test_results.json",
  prettify = true
))

# 3. HTML出力（ファイルに保存）
formatters.add(newHtmlReportFormatter(
  outputFile = reportDir / "test_results.html",
  title = "テスト実行レポート",
  cssStyle = """
    body { 
      font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
      padding: 20px;
      background-color: #f5f5f5; 
    }
    h1, h2 { 
      color: #333;
      border-bottom: 1px solid #ddd;
      padding-bottom: 10px;
    }
    .pass { 
      color: #28a745; 
      font-weight: bold;
    }
    .fail { 
      color: #dc3545; 
      font-weight: bold;
    }
    .skip { 
      color: #ffc107; 
      font-weight: bold;
    }
    .error { 
      color: #6f42c1; 
      font-weight: bold;
    }
    table { 
      box-shadow: 0 2px 4px rgba(0,0,0,0.1);
      background-color: white;
    }
    th { 
      background-color: #343a40; 
      color: white;
    }
    .summary {
      background-color: white;
      padding: 15px;
      border-radius: 5px;
      box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    }
  """
))

# テストフレームワークに全てのフォーマッタを設定
clearFormatters()  # デフォルトのフォーマッタをクリア
for fmt in formatters:
  addFormatter(fmt)

# いくつかのテストケースを実行
runTests:
  
  suite "数学関数":
    
    test "基本四則演算":
      check(1 + 1 == 2)
      check(5 - 3 == 2)
      check(3 * 4 == 12)
      check(10 / 2 == 5)
    
    test "高度な演算":
      check(2 ^ 3 == 8)
      check(sqrt(9.0) == 3.0)
      check(abs(-5) == 5)
  
  suite "文字列処理":
    
    test "文字列連結":
      let a = "Hello"
      let b = "World"
      check(a & " " & b == "Hello World")
    
    test "部分文字列":
      let s = "Testing is important"
      check(s.contains("Test"))
      check(s.startsWith("Test"))
      check(s[0..6] == "Testing")
    
    test "スキップするテストケース":
      skip()
      check(false)  # 実行されない
    
    test "意図的に失敗するテスト":
      # このテストは失敗しますが、レポートに表示されるはずです
      check(1 + 1 == 3)  # 明らかに失敗

when isMainModule:
  echo "テスト実行完了"
  echo "レポートが以下に生成されました:"
  echo " - " & absolutePath(reportDir / "test_results.json")
  echo " - " & absolutePath(reportDir / "test_results.html")