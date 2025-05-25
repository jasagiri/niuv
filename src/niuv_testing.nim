## niuv_testing.nim
## ================
##
## niuvテスト実行とレポート生成機能の統合モジュール
## このモジュールは nim_boilerplate から移植されたテストツールを niuv に統合します
##

import std/[
  os, 
  strutils, 
  strformat, 
  times,
  parseopt,
  logging,
  sequtils
]

import 
  utils/fs,
  utils/shell,
  tools/test/run_specific_test,
  tools/report/test_report,
  test_types

# Import testkit adapter for configuration
import testkit_adapter

# Export types
export test_types

# ログ機能
var logger = newConsoleLogger(lvlInfo, "[$levelname] ")

proc logInfo*(msg: string) =
  info(msg)

proc logWarning*(msg: string) =
  warn(msg)

proc logError*(msg: string) =
  error(msg)

proc findTestFiles*(config: TestRunnerConfig): seq[string] =
  ## テストディレクトリからテストファイルを検索
  if not dirExists(config.testDir):
    logError(fmt"Test directory not found: {config.testDir}")
    return @[]
  
  var testFiles: seq[string] = @[]
  
  case config.mode
  of trmSingle:
    # 単一のテストファイルを実行
    for testFile in config.testFiles:
      if fileExists(config.testDir / testFile):
        testFiles.add(testFile)
      elif fileExists(testFile):
        testFiles.add(testFile)
      else:
        # .nimが含まれていない場合は追加
        let testWithExt = if testFile.endsWith(".nim"): testFile else: testFile & ".nim"
        if fileExists(config.testDir / testWithExt):
          testFiles.add(testWithExt)
        elif fileExists(testWithExt):
          testFiles.add(testWithExt)
        else:
          logWarning(fmt"Test file not found: {testFile}")
  
  of trmPattern:
    # パターンに一致するテストファイルを実行
    testFiles = findFiles(config.testDir, config.pattern, false).mapIt(
      relativePath(it, config.testDir)
    )
  
  of trmAll:
    # すべてのテストファイルを実行
    for kind, path in walkDir(config.testDir):
      if kind == pcFile and 
         path.endsWith(".nim") and 
         path.extractFilename.startsWith("test_"):
        testFiles.add(relativePath(path, config.testDir))
  
  return testFiles

proc runAndReport*(config: TestRunnerConfig): bool =
  ## テスト実行とレポート生成を統合 - TestKitConfigを使用
  # Load configuration from niuv.toml and merge with runtime config
  var tkConfig = loadTestKitConfigFromToml()
  tkConfig.verbose = config.verbose
  tkConfig.pattern = config.pattern
  tkConfig.failFast = config.failFast
  tkConfig.outputDir = config.outputDir
  tkConfig.generateReport = config.generateReport
  tkConfig.testDir = config.testDir
  tkConfig.backend = config.backend
  
  case tkConfig.backend
  of tbNiuv:
    # 従来のniuvバックエンドを使用
    let timestamp = now().format("yyyyMMddHHmmss")
    let testOutputFile = tkConfig.outputDir / fmt"test_output_{timestamp}.log"
    
    # テストファイルの検索
    let testFiles = findTestFiles(config)
    
    if testFiles.len == 0:
      logError("No test files found")
      return false
    
    # 出力ディレクトリの作成
    if not ensureDirExists(tkConfig.outputDir):
      logError(fmt"Failed to create output directory: {tkConfig.outputDir}")
      return false
    
    # テスト実行
    logInfo(fmt"Running {testFiles.len} test files...")
    
    let success = runTests(
      testFiles,
      tkConfig.verbose,
      testOutputFile,
      tkConfig.generateReport,
      tkConfig.failFast,
      tkConfig.testDir
    )
    
    # レポート生成（runTestsでレポート生成しない場合）
    if success and tkConfig.generateReport:
      logInfo("Generating test reports...")
      
      let jsonOutputFile = tkConfig.outputDir / fmt"test_report_{timestamp}.json"
      let htmlOutputFile = tkConfig.outputDir / fmt"test_report_{timestamp}.html"
      
      discard generateReport(testOutputFile, jsonOutputFile, htmlOutputFile)
    
    return success
    
  of tbTestKit:
    # nim-testkitバックエンドを使用
    when defined(niuvTestKit):
      # テストファイルの検索
      let testFiles = findTestFiles(config)
      
      if testFiles.len == 0:
        logError("No test files found")
        return false
      
      # 出力ディレクトリの作成
      if not ensureDirExists(tkConfig.outputDir):
        logError(fmt"Failed to create output directory: {tkConfig.outputDir}")
        return false
      
      # TestKitアダプターを初期化
      var adapter = initTestKitAdapter(tkConfig)
      
      # テスト実行
      return adapter.runWithTestKit(testFiles)
    else:
      logError("TestKit backend is not available. Compile with -d:niuvTestKit to enable.")
      return false

when isMainModule:
  # コマンドライン引数の解析
  var config = newTestRunnerConfig()
  var showHelpOnly = false
  
  for kind, key, val in getopt():
    case kind
    of cmdLongOption, cmdShortOption:
      case key
      of "help", "h":
        showHelpOnly = true
      of "verbose", "v":
        config.verbose = true
      of "output-dir", "o":
        config.outputDir = val
      of "report", "r":
        config.generateReport = true
      of "no-report":
        config.generateReport = false
      of "fail-fast", "f":
        config.failFast = true
      of "test-dir", "d":
        config.testDir = val
      of "pattern", "p":
        config.mode = trmPattern
        config.pattern = val
      of "backend", "b":
        case val.toLowerAscii()
        of "niuv":
          config.backend = tbNiuv
        of "testkit", "tk":
          config.backend = tbTestKit
        else:
          echo "Unknown backend: " & val & " (available: niuv, testkit)"
      else:
        echo "Unknown option: " & key
    of cmdArgument:
      # 引数があれば単一テストモードに設定
      if config.mode != trmPattern:
        config.mode = trmSingle
      config.testFiles.add(key)
    of cmdEnd:
      break
  
  if showHelpOnly:
    echo "niuv テストツール"
    echo "Usage: nim c -r src/niuv_testing.nim [options] [test_file1] [test_file2] ..."
    echo "Options:"
    echo "  -h, --help              このヘルプを表示"
    echo "  -v, --verbose           詳細な出力を表示"
    echo "  -o, --output-dir=DIR    テスト出力ディレクトリ (デフォルト: build/test_output)"
    echo "  -r, --report            テストレポートを生成 (デフォルト: true)"
    echo "  --no-report             テストレポートを生成しない"
    echo "  -f, --fail-fast         最初のテスト失敗時に停止"
    echo "  -d, --test-dir=DIR      テストディレクトリ (デフォルト: tests)"
    echo "  -p, --pattern=PATTERN   テストファイルのパターン (デフォルト: test_*.nim)"
    echo "  -b, --backend=BACKEND   テストバックエンド (niuv, testkit) (デフォルト: niuv)"
    quit(0)
  
  # ログレベルの設定
  if config.verbose:
    logger.levelThreshold = lvlDebug
  else:
    logger.levelThreshold = lvlInfo
  
  # テスト実行とレポート生成
  let success = runAndReport(config)
  
  if not success:
    quit(1)