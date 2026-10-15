## run_specific_test.nim
## =================
##
## 特定のテストファイルを実行するためのツール
##

import std/[
  os, 
  strutils, 
  logging,
  parseopt
]

import ../../utils/shell
import ../../utils/fs

# ログ機能
var logger = newConsoleLogger(lvlInfo, "[$levelname] ")

proc logInfo*(msg: string) =
  info(msg)

proc logWarning*(msg: string) =
  warn(msg)

proc logError*(msg: string) =
  error(msg)

proc runTests*(testFiles: seq[string], 
               verbose = false, 
               outputFile = "", 
               generateReport = false,
               failFast = false,
               testDir = "tests"): bool =
  ## 指定されたテストファイルを実行
  
  if testFiles.len == 0:
    logError("No test files specified")
    return false
  
  # テスト出力ファイルの設定
  var testOutputPath = if outputFile.len > 0: outputFile else: "build/test_output.log"
  
  # 出力ディレクトリを確認
  let outDir = parentDir(testOutputPath)
  if outDir.len > 0:
    discard ensureDirExists(outDir)
  
  # 実行コマンドの設定
  var cmd = ""
  var cmdArgs = ""
  
  # fail-fastフラグの追加
  if failFast:
    cmdArgs &= " --bail"
  
  # テストファイルの一覧
  var testFileArgs = ""
  for testFile in testFiles:
    let testPath = if dirExists(testDir / testFile): 
                   testDir / testFile 
                 elif fileExists(testDir / testFile):
                   testDir / testFile
                 elif dirExists(testFile) or fileExists(testFile):
                   testFile
                 else:
                   # .nimが含まれていない場合は追加
                   if not testFile.endsWith(".nim"):
                     let testWithExt = testFile & ".nim"
                     if fileExists(testDir / testWithExt):
                       testDir / testWithExt
                     elif fileExists(testWithExt):
                       testWithExt
                     else:
                       testFile
                   else:
                     testFile
    
    testFileArgs &= " " & shellEscape(testPath)
  
  # プラットフォームに応じたコマンド設定
  when defined(windows):
    cmd = "scripts\\tests\\test.bat " & cmdArgs & testFileArgs
  else:
    cmd = "sh scripts/tests/test.sh " & cmdArgs & testFileArgs
  
  logInfo("Running tests: " & testFileArgs)
  
  # テスト実行
  var exitCode: int
  var output: string
  
  if outputFile.len > 0:
    # 出力ファイルにリダイレクト
    let (code, cmdOutput) = runCommand(cmd, verbose)
    exitCode = code
    output = cmdOutput
    
    # 出力ファイルに書き込み
    try:
      writeFile(testOutputPath, output)
      logInfo("Test output written to: " & testOutputPath)
    except:
      logError("Failed to write test output to: " & testOutputPath)
      logError(getCurrentExceptionMsg())
  else:
    # 直接表示
    exitCode = execProcessEnv(cmd)
  
  # 結果の判定
  let success = (exitCode == 0)
  
  if success:
    logInfo("Tests completed successfully")
  else:
    logError("Tests failed with exit code: " & $exitCode)
  
  # レポート生成
  if generateReport and outputFile.len > 0:
    logInfo("Generating test reports...")
    
    let reportCmd = when defined(windows):
      "scripts\\tests\\generate_test_report.bat --output=" & shellEscape(testOutputPath)
    else:
      "sh scripts/tests/generate_test_report.sh --output=" & shellEscape(testOutputPath)
    
    let reportCode = execProcessEnv(reportCmd)
    if reportCode != 0:
      logWarning("Failed to generate test reports")
  
  return success

proc showHelp() =
  echo "Run Specific Tests Tool"
  echo "Usage: run_specific_test [options] <test_file1> [test_file2] ..."
  echo "Options:"
  echo "  -h, --help              このヘルプを表示"
  echo "  -v, --verbose           詳細な出力を表示"
  echo "  -o, --output=FILE       テスト出力をFILEに保存"
  echo "  -r, --report            テストレポートを生成"
  echo "  -f, --fail-fast         最初のテスト失敗時に停止"
  echo "  -d, --test-dir=DIR      テストディレクトリ（デフォルト: tests）"
  quit(0)

proc main() =
  # コマンドライン引数の解析
  var verbose = false
  var outputFile = ""
  var generateReport = false
  var failFast = false
  var testDir = "tests"
  var testFiles: seq[string] = @[]
  
  for kind, key, val in getopt():
    case kind
    of cmdLongOption, cmdShortOption:
      case key
      of "help", "h":
        showHelp()
      of "verbose", "v":
        verbose = true
      of "output", "o":
        outputFile = val
      of "report", "r":
        generateReport = true
      of "fail-fast", "f":
        failFast = true
      of "test-dir", "d":
        testDir = val
      else:
        echo "Unknown option: " & key
    of cmdArgument:
      testFiles.add(key)
    of cmdEnd:
      break
  
  if testFiles.len == 0:
    echo "Error: No test files specified"
    echo "Run 'run_specific_test --help' for usage information"
    quit(1)
  
  # ログレベルの設定
  if verbose:
    logger.levelThreshold = lvlDebug
  else:
    logger.levelThreshold = lvlInfo
  
  # テスト実行
  let success = runTests(
    testFiles, 
    verbose, 
    outputFile, 
    generateReport,
    failFast,
    testDir
  )
  
  if not success:
    quit(1)

when isMainModule:
  main()