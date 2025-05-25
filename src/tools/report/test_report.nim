## test_report.nim
## ==============
##
## テスト結果のレポート生成ツール
##

import std/[
  os, 
  json, 
  strutils, 
  strformat, 
  times,
  parseutils,
  logging
]

import ../../utils/fs

# ログ機能
var logger = newConsoleLogger(lvlInfo, "[$levelname] ")

proc logInfo*(msg: string) =
  info(msg)

proc logWarning*(msg: string) =
  warn(msg)

proc logError*(msg: string) =
  error(msg)

type
  TestResult* = enum
    tPass = "pass",
    tFail = "fail",
    tSkip = "skip"

  TestCase* = object
    name*: string
    result*: TestResult
    duration*: float
    message*: string
    suite*: string
    file*: string
    line*: int

  TestReport* = object
    timestamp*: DateTime
    duration*: float
    passed*: int
    failed*: int
    skipped*: int
    total*: int
    cases*: seq[TestCase]

proc parseTestOutput*(output: string): TestReport =
  ## テスト出力を解析してレポートを生成
  # レポート初期化
  var report = TestReport(
    timestamp: now(),
    duration: 0.0,
    passed: 0,
    failed: 0,
    skipped: 0,
    total: 0,
    cases: @[]
  )
  
  var currentSuite = ""
  var lines = output.splitLines()
  
  for line in lines:
    # スイート名の解析
    if line.startsWith("[Suite]"):
      currentSuite = line.replace("[Suite]", "").strip()
      continue
      
    # テスト結果の解析
    if line.contains("[OK]") or line.contains("[FAILED]") or line.contains("[SKIPPED]"):
      var testCase = TestCase(
        suite: currentSuite,
        duration: 0.0,
        file: "",
        line: 0
      )
      
      # 結果タイプの解析
      if line.contains("[OK]"):
        testCase.result = tPass
        report.passed += 1
      elif line.contains("[FAILED]"):
        testCase.result = tFail
        report.failed += 1
      elif line.contains("[SKIPPED]"):
        testCase.result = tSkip
        report.skipped += 1
      
      # テスト名と実行時間の解析
      var parts = line.split(" ")
      for i, part in parts:
        if part == "[OK]" or part == "[FAILED]" or part == "[SKIPPED]":
          var name = parts[i+1..^1].join(" ").strip()
          # 実行時間と行番号を除去
          if name.contains("(") and name.contains(")") and name.contains("[") and name.contains("]"):
            name = name.split("(")[0].strip()
          testCase.name = name
          break
      
      # 実行時間の解析
      var durationPos = line.find("(")
      if durationPos >= 0:
        var durationEnd = line.find(")", durationPos)
        if durationEnd >= 0:
          var durationStr = line[durationPos+1 ..< durationEnd]
          if durationStr.endsWith("s"):
            discard parseFloat(durationStr[0..^2], testCase.duration)
      
      # ファイルと行番号の解析
      var fileLinePos = line.rfind(" [")
      if fileLinePos >= 0:
        var fileLineEnd = line.rfind("]")
        if fileLineEnd >= 0:
          var fileLineStr = line[fileLinePos+2 ..< fileLineEnd]
          var fileLine = fileLineStr.split(":")
          if fileLine.len >= 2:
            testCase.file = fileLine[0]
            discard parseInt(fileLine[1], testCase.line)
      
      report.cases.add(testCase)
      report.total += 1
  
  # 合計実行時間の計算
  for testCase in report.cases:
    report.duration += testCase.duration
  
  return report

proc generateHtmlReport*(report: TestReport, outputFile: string): bool =
  ## HTMLレポートの生成
  try:
    # 出力ディレクトリが存在しない場合は作成
    let outDir = parentDir(outputFile)
    if outDir.len > 0 and not dirExists(outDir):
      discard ensureDirExists(outDir)
    
    # Simple HTML report
    var html = """
    <!DOCTYPE html>
    <html>
    <head>
      <title>Test Report</title>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <style>
        body { font-family: 'Segoe UI', Tahoma, Arial, sans-serif; margin: 0; padding: 20px; color: #333; line-height: 1.6; }
        .header { margin-bottom: 20px; border-bottom: 1px solid #eee; padding-bottom: 10px; }
        .header h1 { margin-top: 0; color: #444; }
        .summary { display: flex; margin-bottom: 20px; flex-wrap: wrap; }
        .summary-item { margin-right: 20px; margin-bottom: 10px; padding: 10px; border-radius: 4px; min-width: 100px; text-align: center; }
        .pass { background-color: #dff0d8; color: #3c763d; }
        .fail { background-color: #f2dede; color: #a94442; }
        .skip { background-color: #fcf8e3; color: #8a6d3b; }
        .total { background-color: #d9edf7; color: #31708f; }
        table { width: 100%; border-collapse: collapse; margin-top: 20px; }
        th, td { text-align: left; padding: 12px 8px; border-bottom: 1px solid #ddd; }
        tr.pass td { background-color: rgba(223, 240, 216, 0.3); }
        tr.fail td { background-color: rgba(242, 222, 222, 0.3); }
        tr.skip td { background-color: rgba(252, 248, 227, 0.3); }
        tr:hover td { background-color: rgba(0, 0, 0, 0.05); }
        th { background-color: #f5f5f5; position: sticky; top: 0; box-shadow: 0 1px 1px rgba(0,0,0,0.1); }
        .duration { text-align: right; }
        .result-cell { text-align: center; }
        .result-pass { color: #3c763d; font-weight: bold; }
        .result-fail { color: #a94442; font-weight: bold; }
        .result-skip { color: #8a6d3b; font-weight: bold; }
        .file-info { font-size: 0.9em; color: #777; }
        @media (max-width: 768px) {
          .header, .summary { padding-left: 10px; padding-right: 10px; }
          th, td { padding: 8px 4px; }
          .summary-item { min-width: 80px; margin-right: 10px; }
        }
      </style>
    </head>
    <body>
      <div class="header">
        <h1>Test Report</h1>
        <div>Generated: $1</div>
        <div>Total Duration: $2 seconds</div>
      </div>
      <div class="summary">
        <div class="summary-item pass">Passed: $3</div>
        <div class="summary-item fail">Failed: $4</div>
        <div class="summary-item skip">Skipped: $5</div>
        <div class="summary-item total">Total: $6</div>
      </div>
      <table>
        <tr>
          <th>Suite</th>
          <th>Test</th>
          <th>Result</th>
          <th>Duration</th>
          <th>File Location</th>
        </tr>
    """ % [
      $report.timestamp,
      formatFloat(report.duration, ffDecimal, 3),
      $report.passed,
      $report.failed,
      $report.skipped,
      $report.total
    ]
    
    for testCase in report.cases:
      var rowClass = case testCase.result:
        of tPass: "pass"
        of tFail: "fail"
        of tSkip: "skip"
      
      var resultClass = case testCase.result:
        of tPass: "result-pass"
        of tFail: "result-fail"
        of tSkip: "result-skip"
      
      html &= """
        <tr class="$1">
          <td>$2</td>
          <td>$3</td>
          <td class="result-cell"><span class="$4">$5</span></td>
          <td class="duration">$6 s</td>
          <td class="file-info">$7:$8</td>
        </tr>
      """ % [
        rowClass,
        testCase.suite,
        testCase.name,
        resultClass,
        $testCase.result,
        formatFloat(testCase.duration, ffDecimal, 6),
        testCase.file,
        $testCase.line
      ]
    
    html &= """
      </table>
      <script>
        // Sort table functionality can be added here if needed
      </script>
    </body>
    </html>
    """
    
    writeFile(outputFile, html)
    return true
  except:
    logError("Error generating HTML report: " & getCurrentExceptionMsg())
    return false

proc generateJsonReport*(report: TestReport, outputFile: string): bool =
  ## JSONレポートの生成
  try:
    # 出力ディレクトリが存在しない場合は作成
    let outDir = parentDir(outputFile)
    if outDir.len > 0 and not dirExists(outDir):
      discard ensureDirExists(outDir)
    
    # JSONへの変換
    var jsonObj = %* {
      "timestamp": $report.timestamp,
      "duration": report.duration,
      "summary": {
        "passed": report.passed,
        "failed": report.failed,
        "skipped": report.skipped,
        "total": report.total
      },
      "tests": []
    }
    
    for testCase in report.cases:
      jsonObj["tests"].add(%* {
        "name": testCase.name,
        "suite": testCase.suite,
        "result": $testCase.result,
        "duration": testCase.duration,
        "file": testCase.file,
        "line": testCase.line
      })
    
    writeFile(outputFile, pretty(jsonObj))
    return true
  except:
    logError("Error generating JSON report: " & getCurrentExceptionMsg())
    return false

proc generateReport*(testOutputFile: string, jsonOutputFile = "", htmlOutputFile = ""): bool =
  ## テスト出力ファイルからレポートを生成
  try:
    # 入力ファイルの存在確認
    if not fileExists(testOutputFile):
      logError("Error: Test output file not found: " & testOutputFile)
      return false
    
    # テスト出力の読み込み
    let testOutput = readFile(testOutputFile)
    
    # テスト出力の解析
    let report = parseTestOutput(testOutput)
    
    # レポート生成
    var success = true
    
    if jsonOutputFile.len > 0:
      if not generateJsonReport(report, jsonOutputFile):
        success = false
        logError("Failed to generate JSON report")
      else:
        logInfo("JSON report generated: " & jsonOutputFile)
    
    if htmlOutputFile.len > 0:
      if not generateHtmlReport(report, htmlOutputFile):
        success = false
        logError("Failed to generate HTML report")
      else:
        logInfo("HTML report generated: " & htmlOutputFile)
    
    # サマリーの表示
    logInfo("Test Summary:")
    logInfo("  Passed: " & $report.passed)
    logInfo("  Failed: " & $report.failed)
    logInfo("  Skipped: " & $report.skipped)
    logInfo("  Total: " & $report.total)
    logInfo("  Duration: " & formatFloat(report.duration, ffDecimal, 3) & " seconds")
    
    return success
  except:
    logError("Error generating report: " & getCurrentExceptionMsg())
    return false

when isMainModule:
  # コマンドライン引数の処理
  let args = commandLineParams()
  
  if args.len < 1:
    echo "Usage: test_report <test_output_file> [json_output_file] [html_output_file]"
    echo "Options:"
    echo "  --help                このヘルプを表示"
    echo "  --json=<file>         JSON形式のレポートを出力するファイル"
    echo "  --html=<file>         HTML形式のレポートを出力するファイル"
    echo "  --verbose             詳細な出力を表示"
    quit(1)
  
  var testOutputFile = ""
  var jsonOutputFile = ""
  var htmlOutputFile = ""
  var verbose = false
  
  for arg in args:
    if arg.startsWith("--"):
      let option = arg[2..^1]
      if option == "help":
        echo "Usage: test_report <test_output_file> [json_output_file] [html_output_file]"
        echo "Options:"
        echo "  --help                このヘルプを表示"
        echo "  --json=<file>         JSON形式のレポートを出力するファイル"
        echo "  --html=<file>         HTML形式のレポートを出力するファイル"
        echo "  --verbose             詳細な出力を表示"
        quit(0)
      elif option.startsWith("json="):
        jsonOutputFile = option[5..^1]
      elif option.startsWith("html="):
        htmlOutputFile = option[5..^1]
      elif option == "verbose":
        verbose = true
    elif testOutputFile.len == 0:
      testOutputFile = arg
    elif jsonOutputFile.len == 0:
      jsonOutputFile = arg
    elif htmlOutputFile.len == 0:
      htmlOutputFile = arg
  
  # デフォルト値の設定
  if jsonOutputFile.len == 0:
    jsonOutputFile = "build/reports/test_report.json"
  
  if htmlOutputFile.len == 0:
    htmlOutputFile = "build/reports/test_report.html"
  
  # ログレベルの設定
  if verbose:
    logger.levelThreshold = lvlDebug
  else:
    logger.levelThreshold = lvlInfo
  
  # レポート生成
  if not generateReport(testOutputFile, jsonOutputFile, htmlOutputFile):
    quit(1)