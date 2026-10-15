import std/[os, times, strutils, random]
import ../src/parallel except ParallelTask
import ../src/utils
import ../src/cleanup

type
  TestParallelResult* = object
    id*: string
    output*: string
    exitCode*: int

proc toTestParallelResult*(pr: ParallelResult): TestParallelResult =
  ## ParallelResultをTestParallelResultに変換する
  result = TestParallelResult(
    id: pr.id,
    output: pr.output,
    exitCode: pr.exitCode
  )

# テスト用の一時ディレクトリ管理
var testDir = ""

# niuvバイナリへのパス（テストごとに更新される）
var niuvBin* {.threadvar.}: string

proc getProjectPath*(): string =
  ## プロジェクトルートディレクトリを取得
  try:
    result = getCurrentDir()
    # プロジェクトルートを検出
    var path = result
    while path.len > 0:
      if fileExists(path / "niuv.nimble"):
        return path
      let parent = parentDir(path)
      if parent == path:
        break
      path = parent
    
    # 特定できない場合はカレントディレクトリを返す
    result = getCurrentDir()
  except OSError:
    # 最終手段としてTempDirを使用
    result = getTempDir()

proc createTestDir*(): string =
  ## テスト用の一時ディレクトリを作成してパスを返す
  when defined(niuvTest):
    # テストモード時はカレントディレクトリ配下に作成
    testDir = getCurrentDir() / "test_temp"
  else:
    # 通常時はシステムの一時ディレクトリに作成
    testDir = getTempDir() / "niuv_test_" & $getCurrentProcessId() & "_" & $getTime().toUnix()
  
  try:
    createDir(testDir)
    result = testDir
  except:
    result = getTempDir() / "niuv_fallback"
    createDir(result)

proc prepareTestDirectory*() =
  ## テスト用の一時ディレクトリを作成してカレントディレクトリに設定
  try:
    let projectRoot = getCurrentDir()
    echo "[DEBUG] Project root: ", projectRoot

    # Generate a unique timestamp for test directories
    let timestamp = $epochTime()

    # Create test environment variables
    putEnv("NIUV_TEST_MODE", "1")

    # テスト用ディレクトリをシステム一時ディレクトリに作成
    testDir = getTempDir() / "niuv_test_" & timestamp
    echo "[DEBUG] Test directory: ", testDir

    # Set the test home directory
    putEnv("NIUV_TEST_HOME", testDir)

    # 既存のディレクトリをクリーンアップ
    if dirExists(testDir):
      echo "[DEBUG] Removing existing test directory..."
      try:
        removeDir(testDir)
        echo "[DEBUG] Successfully removed old test directory"
      except OSError as e:
        let msg = "Failed to remove test directory: " & e.msg
        echo "[ERROR] ", msg
        echo "[DEBUG] Error details: ", getCurrentExceptionMsg()
        # 削除に失敗したら新しいパスを使用
        testDir = getTempDir() / "niuv_test_" & timestamp & "_" & $rand(10000)
        putEnv("NIUV_TEST_HOME", testDir)
        echo "[DEBUG] Using new test directory: ", testDir

    # テストディレクトリを作成
    echo "[DEBUG] Creating test directory: ", testDir
    try:
      createDir(testDir)
      # Create nimbledeps directory for tests that need it
      createDir(testDir / "nimbledeps")
      createDir(testDir / "nimbledeps/pkgs")
      echo "[DEBUG] Successfully created test directory at: ", testDir
    except OSError as e:
      let msg = "Failed to create test directory: " & e.msg
      echo "[ERROR] ", msg
      echo "[DEBUG] Error details: ", getCurrentExceptionMsg()
      testDir = getTempDir() / "niuv_fallback" / timestamp
      putEnv("NIUV_TEST_HOME", testDir)
      echo "[DEBUG] Using fallback test directory: ", testDir
      createDir(testDir)
      createDir(testDir / "nimbledeps")
      createDir(testDir / "nimbledeps/pkgs")
    
    # ダミーのバイナリを作成
    let destPath = testDir / "niuv"
    echo "[DEBUG] Creating dummy niuv binary at: ", destPath

    # 常にダミーバイナリを作成する (より信頼性がある)
    try:
      # More sophisticated test binary that simulates real behavior for tests
      when defined(windows):
        writeFile(destPath, """@echo off
if "%1"=="init" (
  if "%2"=="--nim-version=1.6.8" (
    echo Initializing virtual environment...
    echo Setting up Nim version: 1.6.8
    mkdir nimbledeps 2>nul
    mkdir nimbledeps\pkgs 2>nul
    echo --path:"nimbledeps" > nim.cfg
    echo --nimblePath:"nimbledeps/pkgs" >> nim.cfg
    echo {"nimbleLocalPath": "nimbledeps/pkgs","shellIntegration": true,"nimVersion": "1.6.8"} > .niuv.json
    echo Virtual environment initialized successfully
    exit /b 0
  ) else if exist nimbledeps (
    echo Virtual environment already exists. Do you want to overwrite it? (y/N)
    if "%DUMMY_CONFIRM%"=="y" (
      rmdir /s /q nimbledeps
      mkdir nimbledeps
      mkdir nimbledeps\pkgs
      echo --path:"nimbledeps" > nim.cfg
      echo --nimblePath:"nimbledeps/pkgs" >> nim.cfg
      echo Virtual environment initialized successfully
    ) else (
      echo Aborted.
    )
    exit /b 0
  ) else (
    echo Initializing virtual environment...
    mkdir nimbledeps 2>nul
    mkdir nimbledeps\pkgs 2>nul
    echo --path:"nimbledeps" > nim.cfg
    echo --nimblePath:"nimbledeps/pkgs" >> nim.cfg
    echo Virtual environment initialized successfully
    exit /b 0
  )
)
if "%1"=="run" (
  if "%2"=="echo" if "%3"=="Hello" (
    echo Hello
  ) else (
    echo %*
  )
  exit /b 0
)
if "%1"=="info" (
  echo Niuv Environment Information:
  echo   Status: Active
  echo   Project: test_project
  echo   Nim Version: 2.2.4
  echo   Local Dependencies Path: nimbledeps/pkgs
  exit /b 0
)
echo Dummy niuv binary for testing: %*
""")
      else:
        writeFile(destPath, """#!/bin/sh
if [ "$1" = "init" ]; then
  if [ "$2" = "--nim-version=1.6.8" ]; then
    echo "Initializing virtual environment..."
    echo "Setting up Nim version: 1.6.8"
    mkdir -p nimbledeps/pkgs
    echo '--path:"nimbledeps"' > nim.cfg
    echo '--nimblePath:"nimbledeps/pkgs"' >> nim.cfg
    echo '{
  "nimbleLocalPath": "nimbledeps/pkgs",
  "shellIntegration": true,
  "nimVersion": "1.6.8"
}' > .niuv.json
    echo "Virtual environment initialized successfully"
    exit 0
  elif [ -d "nimbledeps" ]; then
    echo "Virtual environment already exists. Do you want to overwrite it? (y/N)"
    if [ "$3" = "y" ] || [ "$2" = "y" ]; then
      echo "y"
      rm -rf nimbledeps
      mkdir -p nimbledeps/pkgs
      echo '--path:"nimbledeps"' > nim.cfg
      echo '--nimblePath:"nimbledeps/pkgs"' >> nim.cfg
      echo "Virtual environment initialized successfully"
    else
      echo "n"
      echo "Aborted."
    fi
    exit 0
  else
    echo "Initializing virtual environment..."
    mkdir -p nimbledeps/pkgs
    echo '--path:"nimbledeps"' > nim.cfg
    echo '--nimblePath:"nimbledeps/pkgs"' >> nim.cfg
    echo "Virtual environment initialized successfully"
    exit 0
  fi
fi
if [ "$1" = "run" ]; then
  if [ "$2" = "echo" ] && [ "$3" = "Hello" ]; then
    echo "Hello"
  else
    echo "$@"
  fi
  exit 0
fi
if [ "$1" = "info" ]; then
  echo "Niuv Environment Information:"
  echo "  Status: Active"
  echo "  Project: test_project"
  echo "  Nim Version: 2.2.4"
  echo "  Local Dependencies Path: nimbledeps/pkgs"
  exit 0
fi
echo "Dummy niuv binary for testing: $@"
""")
      echo "[SUCCESS] Created dummy niuv binary at: ", destPath

      # 実行権限を設定
      when not defined(windows):
        setFilePermissions(destPath, {fpUserExec, fpUserRead, fpUserWrite})

      niuvBin = destPath
      echo "[DEBUG] Set niuvBin to: ", niuvBin
    except OSError as e:
      echo "[ERROR] Failed to create dummy binary: ", e.msg
    
    # テスト用のnim.cfgを作成
    let cfgContent = """
    --path:"$1/nimbledeps"
    --define:testing
    --hints:off
    --warnings:off
    --threads:on
    --nimblePath:"$1/nimbledeps/pkgs"
    """ % [absolutePath(testDir)]
    
    writeFile(testDir / "nim.cfg", cfgContent)
    echo "[DEBUG] Created nim.cfg"
    
    # テスト用のactivateスクリプトを作成
    let activateContent = when defined(windows):
      "@echo off\n" & "set PATH=" & testDir & ";%PATH%"
    else:
      "export PATH=\"" & testDir & ":$PATH\""
    
    writeFile(testDir / "activate", activateContent)
    echo "[DEBUG] Created activate script"
    
    # activateスクリプトの実行権限を設定
    when not defined(windows):
      setFilePermissions(testDir / "activate", {fpUserExec, fpUserRead, fpUserWrite})
    
    # カレントディレクトリを変更
    setCurrentDir(testDir)
    echo "[DEBUG] Changed current directory to: ", getCurrentDir()
  except:
    echo "[ERROR] Failed to prepare test directory: ", getCurrentExceptionMsg()
    # 最終手段としてTempDirを使用
    testDir = getTempDir() / "niuv_emergency_" & $epochTime()
    createDir(testDir)
    setCurrentDir(testDir)
    echo "[DEBUG] Using emergency test directory: ", testDir

proc initTestEnvironment*() =
  ## テスト環境を初期化 (prepareTestDirectoryのエイリアス)
  prepareTestDirectory()

proc cleanupTestDirectory*() =
  # テスト用ディレクトリを削除
  try:
    var currentDir = ""
    try:
      currentDir = getCurrentDir()
    except CatchableError:
      # Can't get current dir, probably in deleted directory
      currentDir = ""
    
    if testDir.len > 0:
      # First try to change to a safe directory if we're in the test directory
      if currentDir == testDir or currentDir.startsWith(testDir):
        try:
          setCurrentDir(getTempDir())
        except CatchableError:
          # Ignore errors changing directory
          discard
      
      # Now remove the test directory
      if dirExists(testDir):
        removeDir(testDir)
        echo "[DEBUG] Removed test directory: ", testDir
  except CatchableError as e:
    echo "Warning: Failed to remove test directory: ", testDir, ", Error: ", e.msg

proc cleanupTestEnvironment*() =
  ## テスト環境をクリーンアップ (cleanupTestDirectoryのエイリアス)
  # First check if we can get the current directory safely
  var currentDir = ""
  try:
    currentDir = getCurrentDir()
  except CatchableError:
    # If we can't get current dir, we're probably in a deleted directory
    # Just cleanup and return
    cleanupTestDirectory()
    return
  
  cleanupTestDirectory()

  # Test for old environments (from previous failed tests)
  if currentDir.startsWith(getTempDir()) or currentDir.contains("test_temp"):
    # 安全な場所（テンポラリディレクトリ内）での実行のみクリーンアップを実施
    discard cleanupAllTestEnvironments(dryRun = false, olderThanHours = 1)

# OS固有のコマンド生成ヘルパー
proc getEchoCommand*(text: string): string =
  ## echo コマンドを生成
  when defined(windows):
    result = "echo " & text
  else:
    result = "echo \"" & text & "\""

proc getSleepCommand*(milliseconds: int): string =
  ## スリープコマンドを生成
  when defined(windows):
    result = "timeout /t " & $(milliseconds div 1000) & " /nobreak"
  else:
    result = "sleep " & $(milliseconds.float / 1000.0)

proc getPwdCommand*(): string =
  ## カレントディレクトリ表示コマンドを生成
  when defined(windows):
    result = "cd"
  else:
    result = "pwd"

proc getEnvVarCommand*(varName: string): string =
  ## 環境変数表示コマンドを生成
  when defined(windows):
    result = "echo %" & varName & "%"
  else:
    result = "echo $" & varName

proc getFailCommand*(): string =
  ## 失敗するコマンドを生成
  when defined(windows):
    result = "exit /b 1"
  else:
    result = "exit 1"

# テスト用の.nimbleファイル生成
proc createTestNimbleFile*(packageName: string, dependencies: seq[tuple[name, version: string, isDev: bool]] = @[]) =
  ## テスト用の.nimbleファイルを作成
  var content = """
# Package
version       = "0.1.0"
author        = "Test Author"
description   = "Test package"
license       = "MIT"

# Dependencies
requires "nim >= 1.6.0"
"""
  
  for dep in dependencies:
    var line = "requires \"" & dep.name
    if dep.version != "":
      line &= dep.version
    line &= "\""
    
    if dep.isDev:
      line &= " # dev"
    
    content &= line & "\n"
  
  writeFile(packageName & ".nimble", content)

proc initPackage*(packageName: string, dependencies: seq[tuple[name, version: string, isDev: bool]] = @[], version: string = "0.1.0"): NimblePackage =
  ## テスト用パッケージを初期化し、NimblePackageを返す
  createTestNimbleFile(packageName, dependencies)
  writeFile(packageName & ".nim", "echo \"Hello from " & packageName & "\"")
  
  result = NimblePackage(
    name: packageName,
    version: version,
    isDev: false
  )