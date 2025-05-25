## reporting.nim
## =============
##
## カスタマイズ可能なテストレポート機能
## テスト結果のフォーマットと出力方法をカスタマイズできるインターフェースを提供します
##

import std/[
  strutils,
  strformat,
  terminal,
  times,
  os,
  tables,
  sets,
  json
]

# テスト結果の状態
type
  TestStatus* = enum
    Pass,    # テスト成功
    Fail,    # テスト失敗
    Skip,    # テストスキップ
    Error    # 実行エラー

  # テスト結果
  TestResult* = object
    name*: string            # テスト名
    suiteName*: string       # スイート名
    status*: TestStatus      # 状態
    message*: string         # メッセージ（エラー時）
    duration*: float         # 実行時間（秒）
    timestamp*: DateTime     # 実行時刻

  # テスト統計
  TestStatistics* = object
    total*: int
    passed*: int
    failed*: int
    skipped*: int
    errors*: int
    duration*: float
    timestamp*: DateTime
    suites*: CountTable[string]
    failedTests*: HashSet[string]

  # レポートフォーマッタのインターフェース
  ReportFormatter* = ref object of RootObj

  # 基本となるコンソールレポートフォーマッタ
  ConsoleReportFormatter* = ref object of ReportFormatter
    colored*: bool              # 色付き出力を使うかどうか
    showStackTrace*: bool       # スタックトレースを表示するかどうか
    verbosityLevel*: int        # 詳細レベル (0: 最小限, 1: 標準, 2: 詳細)

  # JSONレポートフォーマッタ
  JsonReportFormatter* = ref object of ReportFormatter
    outputFile*: string         # 出力ファイル名（空なら標準出力）
    prettify*: bool             # JSONを整形するかどうか

  # HTMLレポートフォーマッタ
  HtmlReportFormatter* = ref object of ReportFormatter
    outputFile*: string         # 出力ファイル名（必須）
    cssStyle*: string           # カスタムCSSスタイル
    title*: string              # レポートのタイトル

# レポートフォーマッタのメソッド
method beginTesting*(formatter: ReportFormatter) {.base.} =
  ## テスト開始時に呼ばれる
  discard

method endTesting*(formatter: ReportFormatter, stats: TestStatistics) {.base.} =
  ## テスト終了時に呼ばれる
  discard

method beginSuite*(formatter: ReportFormatter, suiteName: string) {.base.} =
  ## テストスイート開始時に呼ばれる
  discard

method endSuite*(formatter: ReportFormatter, suiteName: string) {.base.} =
  ## テストスイート終了時に呼ばれる
  discard

method reportTest*(formatter: ReportFormatter, result: TestResult) {.base.} =
  ## 個別のテスト結果を報告する
  discard

method writeReport*(formatter: ReportFormatter, stats: TestStatistics, results: seq[TestResult]) {.base.} =
  ## レポート全体を書き出す
  discard

# コンソールレポートフォーマッタの実装
method beginTesting*(formatter: ConsoleReportFormatter) =
  echo "テスト実行を開始します..."
  echo "----------------------------------------"

method endTesting*(formatter: ConsoleReportFormatter, stats: TestStatistics) =
  echo "----------------------------------------"
  echo "テスト実行が完了しました"
  echo fmt"合計: {stats.total} テスト, 成功: {stats.passed}, 失敗: {stats.failed}, " &
       fmt"スキップ: {stats.skipped}, エラー: {stats.errors}"
  echo fmt"実行時間: {stats.duration:.3f} 秒"
  
  if stats.failed > 0 or stats.errors > 0:
    echo "\n失敗したテスト:"
    for testName in stats.failedTests:
      echo "  - " & testName
  
  if formatter.verbosityLevel >= 1 and stats.suites.len > 0:
    echo "\nスイート別テスト数:"
    for suite, count in stats.suites:
      echo fmt"  {suite}: {count}"
  
  let successRate = if stats.total > 0: 
                      float(stats.passed) / float(stats.total) * 100.0
                    else:
                      0.0
  echo fmt"\n成功率: {successRate:.2f}%"

method beginSuite*(formatter: ConsoleReportFormatter, suiteName: string) =
  echo fmt"スイート: {suiteName}"

method endSuite*(formatter: ConsoleReportFormatter, suiteName: string) =
  if formatter.verbosityLevel >= 2:
    echo fmt"スイート完了: {suiteName}"

method reportTest*(formatter: ConsoleReportFormatter, result: TestResult) =
  var statusStr = ""
  var statusStyle = styleBright
  
  case result.status
  of Pass:
    statusStr = "[PASS]"
    if formatter.colored:
      statusStyle = styleBright + fgGreen
  of Fail:
    statusStr = "[FAIL]"
    if formatter.colored:
      statusStyle = styleBright + fgRed
  of Skip:
    statusStr = "[SKIP]"
    if formatter.colored:
      statusStyle = styleBright + fgYellow
  of Error:
    statusStr = "[ERROR]"
    if formatter.colored:
      statusStyle = styleBright + fgMagenta
  
  var testName = result.name
  if formatter.verbosityLevel >= 1 and result.suiteName.len > 0:
    testName = result.suiteName & "." & testName
  
  if formatter.colored:
    styledEcho(statusStyle, statusStr, resetStyle, " ", testName)
  else:
    echo statusStr & " " & testName
  
  if result.status in {Fail, Error} and result.message.len > 0:
    echo "  " & result.message.replace("\n", "\n  ")

# JSONレポートフォーマッタの実装
method writeReport*(formatter: JsonReportFormatter, stats: TestStatistics, results: seq[TestResult]) =
  var report = newJObject()
  
  # 統計情報
  var statsObj = newJObject()
  statsObj["total"] = %stats.total
  statsObj["passed"] = %stats.passed
  statsObj["failed"] = %stats.failed
  statsObj["skipped"] = %stats.skipped
  statsObj["errors"] = %stats.errors
  statsObj["duration"] = %stats.duration
  statsObj["timestamp"] = %($stats.timestamp)
  statsObj["successRate"] = %(if stats.total > 0: float(stats.passed) / float(stats.total) * 100.0 else: 0.0)
  
  # スイート情報
  var suitesObj = newJObject()
  for suite, count in stats.suites:
    suitesObj[suite] = %count
  statsObj["suites"] = suitesObj
  
  report["statistics"] = statsObj
  
  # テスト結果
  var resultsArray = newJArray()
  for result in results:
    var resultObj = newJObject()
    resultObj["name"] = %result.name
    resultObj["suiteName"] = %result.suiteName
    resultObj["status"] = %($result.status)
    resultObj["message"] = %result.message
    resultObj["duration"] = %result.duration
    resultObj["timestamp"] = %($result.timestamp)
    resultsArray.add(resultObj)
  
  report["results"] = resultsArray
  
  # 出力
  let jsonContent = if formatter.prettify: 
                      pretty(report)
                    else: 
                      $report
  
  if formatter.outputFile.len > 0:
    writeFile(formatter.outputFile, jsonContent)
  else:
    echo jsonContent

# HTMLレポートフォーマッタの実装
method writeReport*(formatter: HtmlReportFormatter, stats: TestStatistics, results: seq[TestResult]) =
  # 基本のHTMLテンプレート
  var html = fmt"""<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>{formatter.title}</title>
  <style>
    body {{ font-family: Arial, sans-serif; margin: 20px; }}
    .summary {{ margin-bottom: 20px; }}
    .stats {{ margin-bottom: 20px; }}
    .pass {{ color: green; }}
    .fail {{ color: red; }}
    .skip {{ color: orange; }}
    .error {{ color: purple; }}
    table {{ border-collapse: collapse; width: 100%; }}
    th, td {{ border: 1px solid #ddd; padding: 8px; text-align: left; }}
    th {{ background-color: #f2f2f2; }}
    tr:nth-child(even) {{ background-color: #f9f9f9; }}
    .message {{ font-family: monospace; white-space: pre-wrap; }}
    {formatter.cssStyle}
  </style>
</head>
<body>
  <h1>{formatter.title}</h1>
  
  <div class="summary">
    <h2>テスト結果サマリー</h2>
    <p>
      合計: <strong>{stats.total}</strong> テスト、
      成功: <strong class="pass">{stats.passed}</strong>、
      失敗: <strong class="fail">{stats.failed}</strong>、
      スキップ: <strong class="skip">{stats.skipped}</strong>、
      エラー: <strong class="error">{stats.errors}</strong>
    </p>
    <p>実行時間: {stats.duration:.3f} 秒</p>
    <p>成功率: {(if stats.total > 0: float(stats.passed) / float(stats.total) * 100.0 else: 0.0):.2f}%</p>
  </div>
  
  <div class="stats">
    <h2>スイート別テスト数</h2>
    <table>
      <tr>
        <th>スイート名</th>
        <th>テスト数</th>
      </tr>
"""
  
  # スイート情報の追加
  for suite, count in stats.suites:
    html.add(fmt"""
      <tr>
        <td>{suite}</td>
        <td>{count}</td>
      </tr>""")
  
  html.add("""
    </table>
  </div>
  
  <div class="results">
    <h2>テスト結果</h2>
    <table>
      <tr>
        <th>スイート</th>
        <th>テスト名</th>
        <th>状態</th>
        <th>実行時間</th>
        <th>メッセージ</th>
      </tr>
""")
  
  # テスト結果の追加
  for result in results:
    let statusClass = case result.status
                      of Pass: "pass"
                      of Fail: "fail"
                      of Skip: "skip"
                      of Error: "error"
    
    html.add(fmt"""
      <tr>
        <td>{result.suiteName}</td>
        <td>{result.name}</td>
        <td class="{statusClass}">{$result.status}</td>
        <td>{result.duration:.3f}秒</td>
        <td class="message">{result.message}</td>
      </tr>""")
  
  html.add("""
    </table>
  </div>
</body>
</html>
""")
  
  # HTMLファイルに書き出し
  writeFile(formatter.outputFile, html)

# フォーマッタインスタンスの作成関数
proc newConsoleReportFormatter*(colored = true, showStackTrace = false, verbosityLevel = 1): ConsoleReportFormatter =
  ## 新しいコンソールレポートフォーマッタを作成
  ConsoleReportFormatter(
    colored: colored,
    showStackTrace: showStackTrace, 
    verbosityLevel: verbosityLevel
  )

proc newJsonReportFormatter*(outputFile = "", prettify = true): JsonReportFormatter =
  ## 新しいJSONレポートフォーマッタを作成
  JsonReportFormatter(
    outputFile: outputFile,
    prettify: prettify
  )

proc newHtmlReportFormatter*(outputFile: string, title = "テスト実行レポート", cssStyle = ""): HtmlReportFormatter =
  ## 新しいHTMLレポートフォーマッタを作成
  HtmlReportFormatter(
    outputFile: outputFile,
    title: title,
    cssStyle: cssStyle
  )

# テスト統計の作成と更新
proc newTestStatistics*(): TestStatistics =
  ## 新しいテスト統計オブジェクトを作成
  result = TestStatistics(
    total: 0,
    passed: 0,
    failed: 0,
    skipped: 0,
    errors: 0,
    duration: 0.0,
    timestamp: now(),
    suites: initCountTable[string](),
    failedTests: initHashSet[string]()
  )

proc updateStatistics*(stats: var TestStatistics, result: TestResult) =
  ## テスト結果に基づいて統計を更新
  stats.total.inc
  
  case result.status
  of Pass:
    stats.passed.inc
  of Fail:
    stats.failed.inc
    if result.suiteName.len > 0:
      stats.failedTests.incl(result.suiteName & "." & result.name)
    else:
      stats.failedTests.incl(result.name)
  of Skip:
    stats.skipped.inc
  of Error:
    stats.errors.inc
    if result.suiteName.len > 0:
      stats.failedTests.incl(result.suiteName & "." & result.name)
    else:
      stats.failedTests.incl(result.name)
  
  if result.suiteName.len > 0:
    stats.suites.inc(result.suiteName)
  
  stats.duration += result.duration