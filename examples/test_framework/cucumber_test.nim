## cucumber_test.nim
## ================
##
## cucumber_nim 統合アダプタの使用例
## カスタムレポートを使用してcucumberテストを実行
##

import std/[strutils, os]
import ../../src/cucumber_adapter
import ../../src/reporting

when isMainModule:
  # カスタムレポートフォーマッタを設定
  var formatters: seq[ReportFormatter] = @[]
  
  # コンソールフォーマッタ（デフォルト）
  formatters.add(newConsoleReportFormatter(
    colored = true,
    verbosityLevel = 2  # 詳細出力
  ))
  
  # レポートディレクトリの設定
  let reportDir = "cucumber_reports"
  if not dirExists(reportDir):
    createDir(reportDir)
  
  # HTML出力
  formatters.add(newHtmlReportFormatter(
    outputFile = reportDir / "cucumber_results.html",
    title = "Cucumber テスト実行レポート",
    cssStyle = """
      body { 
        font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
        padding: 20px;
        background-color: #f8f9fa; 
      }
      h1, h2 { 
        color: #28a745;
        border-bottom: 1px solid #ddd;
        padding-bottom: 10px;
      }
      .pass { color: #28a745; }
      .fail { color: #dc3545; }
      .skip { color: #ffc107; }
      .error { color: #6f42c1; }
      table { 
        box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        background-color: white;
      }
      th { 
        background-color: #28a745; 
        color: white;
      }
    """
  ))
  
  # JSON出力
  formatters.add(newJsonReportFormatter(
    outputFile = reportDir / "cucumber_results.json",
    prettify = true
  ))
  
  # cucumber アダプタを使用してテスト実行
  echo "Cucumberテストを拡張レポート形式で実行中..."
  
  let exitCode = main(formatters)
  
  echo "テスト実行完了、終了コード: " & $exitCode
  echo "レポートが以下に生成されました:"
  echo " - " & absolutePath(reportDir / "cucumber_results.json")
  echo " - " & absolutePath(reportDir / "cucumber_results.html")
  
  # 標準的なcucumberのコンソール出力に加えて拡張レポートが生成される
  quit(exitCode)