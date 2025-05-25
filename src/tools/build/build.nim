## build.nim
## =========
##
## ビルド操作の実装
##

import os, strutils, osproc, sets, sequtils

type
  BuildMode* = enum
    bmDebug,    # デバッグビルド
    bmRelease   # リリースビルド
  
  BuildTarget* = enum
    btMain,     # メイン実行ファイル
    btTest,     # 単一のテストファイル
    btAllTests, # すべてのテスト
    btExamples, # 例
    btAll       # すべて

  BuildConfig* = object
    mode*: BuildMode        # ビルドモード
    target*: BuildTarget    # ビルド対象
    verbose*: bool          # 詳細な情報を表示
    buildDir*: string       # ビルドディレクトリのパス
    nimcacheDir*: string    # Nimキャッシュディレクトリ
    srcDir*: string         # ソースディレクトリ
    targetFile*: string     # ビルド対象のファイル（btTestの場合）
    defines*: HashSet[string] # 追加の定義

proc newBuildConfig*(mode = bmRelease, target = btMain, verbose = false): BuildConfig =
  ## ビルド設定の作成
  result = BuildConfig(
    mode: mode,
    target: target,
    verbose: verbose,
    buildDir: "build",
    nimcacheDir: "build/nimcache",
    srcDir: "src",
    targetFile: "",
    defines: ["release"].toHashSet
  )

  # ビルドモードに応じた設定
  if mode == bmDebug:
    result.defines.excl("release")

proc ensureDirExists*(path: string) =
  ## ディレクトリが存在することを確認し、存在しなければ作成
  if not dirExists(path):
    try:
      createDir(path)
    except:
      echo "Warning: Unable to create directory: ", path

proc runCommand*(cmd: string, verbose = false): bool =
  ## コマンドを実行し、成功したかどうかを返す
  if verbose:
    echo "Executing: ", cmd
  
  let (output, exitCode) = execCmdEx(cmd)
  
  if exitCode != 0:
    echo "Command failed with exit code ", exitCode
    echo "Output: ", output
    return false
  
  if verbose:
    echo output
  
  return true

proc buildMain*(config: BuildConfig): bool =
  ## メイン実行ファイルをビルド
  let binDir = config.buildDir / "bin"
  ensureDirExists(binDir)
  ensureDirExists(config.nimcacheDir)
  
  let outFile = binDir / "niuv"
  var defines = ""
  
  for define in config.defines:
    defines &= " -d:" & define
  
  let cmd = "nim c" & defines & " --nimcache:" & config.nimcacheDir &
            " --out:" & outFile & " " & config.srcDir & "/niuv.nim"
  
  if config.verbose:
    echo "Building main executable..."
  
  let success = runCommand(cmd, config.verbose)
  
  if success and config.verbose:
    echo "Main executable built at ", outFile
  
  return success

proc buildTest*(config: BuildConfig): bool =
  ## 単一のテストファイルをビルド
  if config.targetFile.len == 0:
    echo "Error: No test file specified"
    return false
  
  let testsDir = config.buildDir / "tests"
  ensureDirExists(testsDir)
  ensureDirExists(config.nimcacheDir)
  
  let testName = config.targetFile.splitFile.name
  let outFile = testsDir / testName
  var defines = ""
  
  for define in config.defines:
    defines &= " -d:" & define
  
  let cmd = "nim c" & defines & " --nimcache:" & config.nimcacheDir &
            " --out:" & outFile & " " & config.targetFile
  
  if config.verbose:
    echo "Building test: ", testName
  
  let success = runCommand(cmd, config.verbose)
  
  if success and config.verbose:
    echo "Test built at ", outFile
  
  return success

proc buildTestRunner*(config: BuildConfig): bool =
  ## テストランナーをビルド
  let binDir = config.buildDir / "bin"
  ensureDirExists(binDir)
  ensureDirExists(config.nimcacheDir)
  
  let outFile = binDir / "testrunner"
  var defines = ""
  
  for define in config.defines:
    defines &= " -d:" & define
  
  let cmd = "nim c" & defines & " --nimcache:" & config.nimcacheDir &
            " --out:" & outFile & " " & config.srcDir & "/testrunner.nim"
  
  if config.verbose:
    echo "Building test runner..."
  
  let success = runCommand(cmd, config.verbose)
  
  if success and config.verbose:
    echo "Test runner built at ", outFile
  
  return success

proc buildAllTests*(config: BuildConfig): bool =
  ## すべてのテストファイルをビルド
  # まずテストランナーをビルド
  if not buildTestRunner(config):
    return false
  
  let testsDir = config.buildDir / "tests"
  ensureDirExists(testsDir)
  ensureDirExists(config.nimcacheDir)
  
  # テストランナーを使ってすべてのテストをビルド
  let binDir = config.buildDir / "bin"
  let cmd = binDir / "testrunner" & " --output:" & testsDir
  
  if config.verbose:
    echo "Building all tests..."
  
  let success = runCommand(cmd, config.verbose)
  
  if success and config.verbose:
    echo "All tests built in ", testsDir
  
  return success

proc buildExamples*(config: BuildConfig): bool =
  ## 例をビルド
  let examplesDir = config.buildDir / "examples"
  ensureDirExists(examplesDir)
  ensureDirExists(config.nimcacheDir)
  
  if config.verbose:
    echo "Building all examples..."
  
  var success = true
  var defines = ""
  
  for define in config.defines:
    defines &= " -d:" & define
  
  # examples ディレクトリ内の .nim ファイルを検索
  for example in walkFiles("examples/*.nim"):
    let name = example.splitFile.name
    let outFile = examplesDir / name
    
    let cmd = "nim c" & defines & " --nimcache:" & config.nimcacheDir &
              " --out:" & outFile & " " & example
    
    if config.verbose:
      echo "Building example: ", name
    
    let result = runCommand(cmd, config.verbose)
    if not result:
      success = false
  
  if success and config.verbose:
    echo "All examples built in ", examplesDir
  
  return success

proc buildAll*(config: BuildConfig): bool =
  ## すべてをビルド
  var success = true
  
  # メイン実行ファイルをビルド
  if not buildMain(config):
    success = false
  
  # すべてのテストをビルド
  if not buildAllTests(config):
    success = false
  
  # 例をビルド
  if not buildExamples(config):
    success = false
  
  if success and config.verbose:
    echo "All components built successfully!"
  
  return success

proc build*(config: BuildConfig): bool =
  ## 指定されたターゲットをビルド
  case config.target
  of btMain:
    return buildMain(config)
  of btTest:
    return buildTest(config)
  of btAllTests:
    return buildAllTests(config)
  of btExamples:
    return buildExamples(config)
  of btAll:
    return buildAll(config)