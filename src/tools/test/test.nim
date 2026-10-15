## test.nim
## ========
##
## テスト操作の実装
##

import os, strutils, osproc, sets, sequtils, algorithm
import ../../utils

type
  TestMode* = enum
    tmNormal,    # 通常のテスト
    tmVerbose,   # 詳細表示
    tmQuiet      # 最小限の出力
  
  TestConfig* = object
    mode*: TestMode           # テストモード
    pattern*: string          # テストファイルパターン
    singleTest*: string       # 単一のテストファイル
    buildDir*: string         # ビルドディレクトリのパス
    nimcacheDir*: string      # Nimキャッシュディレクトリ
    outputDir*: string        # テスト結果出力ディレクトリ

proc newTestConfig*(mode = tmNormal): TestConfig =
  ## テスト設定の作成
  result = TestConfig(
    mode: mode,
    pattern: "test_*.nim",
    singleTest: "",
    buildDir: "build",
    nimcacheDir: "build/nimcache",
    outputDir: "build/test_output"
  )

proc ensureDirExists*(path: string) =
  ## ディレクトリが存在することを確認し、存在しなければ作成
  if not dirExists(path):
    try:
      createDir(path)
    except:
      echo "Warning: Unable to create directory: ", path

proc runCommand*(cmd: string, verbose = false): tuple[exitCode: int, output: string] =
  ## コマンドを実行し、終了コードと出力を返す
  if verbose:
    echo "Executing: ", cmd
  
  # execCmdEx returns (output, exitCode), but we want (exitCode, output)
  let cmdResult = execCmdEx(cmd)
  result = (exitCode: cmdResult[1], output: cmdResult[0])
  
  if verbose and result.output.len > 0:
    echo result.output
  
  return result

proc findTestFiles*(pattern: string): seq[string] =
  ## 指定されたパターンに一致するテストファイルを検索
  result = @[]
  
  for file in walkFiles("tests/" & pattern):
    if file.endsWith(".nim") and not file.endsWith("testutils.nim") and not file.endsWith("test_all.nim"):
      result.add(file)
  
  # ソートして確実な順序に
  result.sort()

proc buildTestRunner*(config: TestConfig): bool =
  ## テストランナーをビルド
  let binDir = config.buildDir / "bin"
  ensureDirExists(binDir)
  ensureDirExists(config.nimcacheDir)
  
  let outFile = binDir / "testrunner"
  
  let cmd = utils.getNimCommand() & " c --nimcache:" & config.nimcacheDir &
            " --out:" & outFile & " src/testrunner.nim"
  
  if config.mode == tmVerbose:
    echo "Building test runner..."
  
  let (exitCode, _) = runCommand(cmd, config.mode == tmVerbose)
  
  if exitCode == 0 and config.mode == tmVerbose:
    echo "Test runner built at ", outFile
  
  return exitCode == 0

proc runSingleTest*(config: TestConfig): bool =
  ## 単一のテストを実行
  if config.singleTest.len == 0:
    echo "Error: No test file specified"
    return false
  
  # テストランナーが必要な場合はビルド
  if not buildTestRunner(config):
    return false
  
  ensureDirExists(config.outputDir)
  
  # テストランナーを使ってテストを実行
  let binDir = config.buildDir / "bin"
  var verboseFlag = if config.mode == tmVerbose: " --verbose" else: ""
  
  let cmd = binDir / "testrunner" & verboseFlag & " " & config.singleTest
  
  if config.mode == tmVerbose:
    echo "Running test: ", config.singleTest
  
  let (exitCode, output) = runCommand(cmd, config.mode == tmVerbose)
  
  if exitCode == 0:
    if config.mode != tmQuiet:
      echo "Test passed: ", config.singleTest
    return true
  else:
    echo "Test failed: ", config.singleTest
    if config.mode != tmVerbose and output.len > 0:
      echo output
    return false

proc runAllTests*(config: TestConfig): bool =
  ## すべてのテストを実行
  # テストランナーをビルド
  if not buildTestRunner(config):
    return false
  
  ensureDirExists(config.outputDir)
  
  # テストランナーを使ってすべてのテストを実行
  let binDir = config.buildDir / "bin"
  var verboseFlag = if config.mode == tmVerbose: " --verbose" else: ""
  
  let cmd = binDir / "testrunner" & verboseFlag
  
  if config.mode != tmQuiet:
    echo "Running all tests..."
  
  let (exitCode, output) = runCommand(cmd, config.mode == tmVerbose)
  
  if exitCode == 0:
    if config.mode != tmQuiet:
      echo "All tests passed"
    return true
  else:
    echo "Some tests failed"
    if config.mode != tmVerbose and output.len > 0:
      echo output
    return false

proc runTests*(config: TestConfig): bool =
  ## 指定された設定でテストを実行
  if config.singleTest.len > 0:
    return runSingleTest(config)
  else:
    return runAllTests(config)