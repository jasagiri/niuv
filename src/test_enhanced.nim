## test_enhanced.nim
## =================
## 
## カスタマイズ可能なテストフレームワークの中心モジュール
## power_assert_nim による強化されたアサーションとカスタムレポート機能を統合
##

import std/[
  unittest,
  macros,
  tables,
  strutils,
  strformat,
  times,
  os,
  terminal
]

# Note: power_assert_nim has been removed, using standard unittest assertions

# カスタムレポート機能をインポート
import reporting

# 実行中のテスト情報を保持
var
  currentSuite* = ""
  testResults*: seq[TestResult] = @[]
  testStats* = newTestStatistics()
  startTime*: float
  formatters*: seq[ReportFormatter] = @[]

# デフォルトのコンソールフォーマッタを追加
formatters.add(newConsoleReportFormatter())

# テスト実行の計測
proc startTimer*() =
  startTime = epochTime()

proc endTimer*(): float =
  result = epochTime() - startTime

# フォーマッタの追加
proc addFormatter*(formatter: ReportFormatter) =
  ## レポートフォーマッタを追加する
  formatters.add(formatter)

proc removeFormatter*(formatter: ReportFormatter) =
  ## レポートフォーマッタを削除する
  var newFormatters: seq[ReportFormatter] = @[]
  for fmt in formatters:
    if fmt != formatter:
      newFormatters.add(fmt)
  formatters = newFormatters

proc clearFormatters*() =
  ## すべてのフォーマッタをクリアする
  formatters = @[]

# テスト実行前の設定
proc beginTesting*() =
  ## テスト実行を開始する
  testResults = @[]
  testStats = newTestStatistics()
  
  for formatter in formatters:
    formatter.beginTesting()

# テストスイートの定義
template suite*(name: string, body: untyped) =
  ## テストスイートを定義する
  block:
    let oldSuiteName = currentSuite
    currentSuite = name
    
    for formatter in formatters:
      formatter.beginSuite(name)
    
    # 元のunittestのsuiteを使わず直接実装
    body
    
    for formatter in formatters:
      formatter.endSuite(name)
    
    currentSuite = oldSuiteName

# テスト定義
template test*(name: string, body: untyped) =
  ## テストケースを定義する
  block:
    var testResult = TestResult(
      name: name,
      suiteName: currentSuite,
      status: Pass,
      message: "",
      timestamp: now()
    )
    
    startTimer()
    
    try:
      # テスト実行
      body
      
      testResult.status = Pass
    except SkipError:
      testResult.status = Skip
      testResult.message = getCurrentExceptionMsg()
    except:
      testResult.status = Fail
      testResult.message = getCurrentExceptionMsg()
    
    testResult.duration = endTimer()
    
    # 結果の記録
    testResults.add(testResult)
    updateStatistics(testStats, testResult)
    
    # レポート出力
    for formatter in formatters:
      formatter.reportTest(testResult)

# テスト終了の処理
proc endTesting*() =
  ## テスト実行を終了し、最終レポートを生成する
  for formatter in formatters:
    formatter.endTesting(testStats)
    formatter.writeReport(testStats, testResults)

# テストの実行とレポート生成を自動化するテンプレート
template runTests*(body: untyped) =
  ## すべてのテストを実行し、結果をレポートする
  beginTesting()
  body
  endTesting()
  
  # 失敗したテストがあれば終了コードを設定
  when not defined(js):
    if testStats.failed > 0 or testStats.errors > 0:
      quit(1)

# unittest との互換性のための定義（power_assert_nim では上書きされる）
when false:
  template check*(condition: untyped) =
    ## check テンプレート - power_assert_nim で上書きされる
    discard

  template require*(condition: untyped) =
    ## require テンプレート - power_assert_nim で上書きされる
    discard
    
  template expectError*(errorType: typedesc, code: untyped) =
    ## expectError テンプレート - power_assert_nim で上書きされる
    discard