## scaffold.nim
## ============
##
## プロジェクト構造のスキャフォールド
##

import os, strutils

# ファイルシステムユーティリティ
proc ensureDirExists*(path: string): bool =
  ## ディレクトリが存在することを確認し、必要に応じて作成
  result = true
  
  if not dirExists(path):
    try:
      createDir(path)
    except:
      echo "Warning: Unable to create directory: ", path
      result = false

type
  ScaffoldType* = enum
    stModule,    # モジュール
    stProject,   # プロジェクト
    stTest       # テストファイル

  ScaffoldConfig* = object
    name*: string               # プロジェクト/モジュール名
    type*: ScaffoldType         # スキャフォールドタイプ
    includeTests*: bool         # テストを含めるか
    includeExamples*: bool      # 例を含めるか
    baseDir*: string            # 基本ディレクトリ
    authorName*: string         # 作者名
    description*: string        # 説明
    nimVersion*: string         # Nimバージョン
    dryRun*: bool               # 実際にファイルを作成しないで表示のみ

proc newScaffoldConfig*(name: string, scaffoldType = stModule): ScaffoldConfig =
  ## スキャフォールド設定の作成
  result = ScaffoldConfig(
    name: name,
    type: scaffoldType,
    includeTests: true,
    includeExamples: true,
    baseDir: ".",
    authorName: "jasagiri",
    description: "A " & name & " module/project",
    nimVersion: "1.6.0",
    dryRun: false
  )

proc generateModuleFile(config: ScaffoldConfig, filePath: string): bool =
  ## モジュールファイルの生成
  let content = """## $1.nim
## $2
##
## $3
##

import os, strutils

when isMainModule:
  echo "Module $1 loaded"
""" % [config.name, repeat("=", config.name.len + 4), config.description]
  
  if config.dryRun:
    echo "Would create file: ", filePath
    echo "Content:"
    echo content
    return true
  
  try:
    let dir = filePath.splitFile.dir
    if not dirExists(dir):
      createDir(dir)
    
    writeFile(filePath, content)
    return true
  except:
    echo "Error creating file: ", filePath
    echo getCurrentExceptionMsg()
    return false

proc generateNimbleFile(config: ScaffoldConfig, filePath: string): bool =
  ## Nimbleファイルの生成
  let content = """# Package
version       = "0.1.0"
author        = "$1"
description   = "$2"
license       = "MIT"
srcDir        = "src"
bin           = @["$3"]
binDir        = "build/bin"

# Dependencies
requires "nim >= $4"

# Tasks
task test, "Run tests":
  # Execute tests
  exec "nim c -r --nimcache:build/nimcache tests/test_all.nim"

task clean, "Clean build artifacts":
  exec "nim c -r src/tools/clean/clean_wrapper.nim"

task buildAll, "Build everything":
  exec "nim c -r src/tools/build/build_wrapper.nim all"
""" % [config.authorName, config.description, config.name, config.nimVersion]
  
  if config.dryRun:
    echo "Would create file: ", filePath
    echo "Content:"
    echo content
    return true
  
  try:
    let dir = filePath.splitFile.dir
    if not dirExists(dir):
      createDir(dir)
    
    writeFile(filePath, content)
    return true
  except:
    echo "Error creating file: ", filePath
    echo getCurrentExceptionMsg()
    return false

proc generateTestFile(config: ScaffoldConfig, filePath: string): bool =
  ## テストファイルの生成
  let moduleNameParts = config.name.split('_')
  let moduleNameCamel = moduleNameParts.mapIt(it.capitalize).join("")
  
  let content = """## test_$1.nim
## $2
##
## $3のテスト
##

import unittest
import ../vendor/power_assert_nim/src/power_assert

when defined(nimTest):
  import $1
else:
  import ../src/$1

suite "$4 Tests":
  
  setup:
    # テストの準備
    discard
  
  teardown:
    # テストの後処理
    discard
  
  test "Basic functionality":
    # 基本機能のテスト
    check(true)
""" % [config.name, repeat("=", config.name.len + 9), config.description, moduleNameCamel]
  
  if config.dryRun:
    echo "Would create file: ", filePath
    echo "Content:"
    echo content
    return true
  
  try:
    let dir = filePath.splitFile.dir
    if not dirExists(dir):
      createDir(dir)
    
    writeFile(filePath, content)
    return true
  except:
    echo "Error creating file: ", filePath
    echo getCurrentExceptionMsg()
    return false

proc generateTestAllFile(config: ScaffoldConfig, filePath: string): bool =
  ## テスト実行ファイルの生成
  let content = """## test_all.nim
## =========
##
## すべてのテストを実行
##

import unittest
import os, strutils
import ../vendor/power_assert_nim/src/power_assert

# インポートするテストファイル
import test_$1

when isMainModule:
  echo "Running all tests for $2"
""" % [config.name, config.name]
  
  if config.dryRun:
    echo "Would create file: ", filePath
    echo "Content:"
    echo content
    return true
  
  try:
    let dir = filePath.splitFile.dir
    if not dirExists(dir):
      createDir(dir)
    
    writeFile(filePath, content)
    return true
  except:
    echo "Error creating file: ", filePath
    echo getCurrentExceptionMsg()
    return false

proc generateExampleFile(config: ScaffoldConfig, filePath: string): bool =
  ## 例ファイルの生成
  let content = """## $1_example.nim
## $2
##
## $3の使用例
##

import os, strutils
when defined(nimExample):
  import $1
else:
  import ../src/$1

echo "$3の使用例"

# 以下に例を記述
""" % [config.name, repeat("=", config.name.len + 12), config.description]
  
  if config.dryRun:
    echo "Would create file: ", filePath
    echo "Content:"
    echo content
    return true
  
  try:
    let dir = filePath.splitFile.dir
    if not dirExists(dir):
      createDir(dir)
    
    writeFile(filePath, content)
    return true
  except:
    echo "Error creating file: ", filePath
    echo getCurrentExceptionMsg()
    return false

proc generateFeatureFile(config: ScaffoldConfig, filePath: string): bool =
  ## Gherkin featureファイルの生成
  let moduleNameParts = config.name.split('_')
  let moduleNameTitle = moduleNameParts.mapIt(it.capitalize).join(" ")
  
  let content = """Feature: $1
  As a developer
  I want to use the $2 module
  So that I can $3

  Background:
    Given I have imported the $2 module
    And I have initialized the necessary components

  Scenario: Basic usage
    When I call the main function
    Then it should return the expected result
    And no errors should be thrown

  Scenario: Edge case handling
    Given I have provided invalid input
    When I call the main function
    Then it should handle the error gracefully
    And return an appropriate error message
""" % [moduleNameTitle, config.name, config.description.toLowerAscii]
  
  if config.dryRun:
    echo "Would create file: ", filePath
    echo "Content:"
    echo content
    return true
  
  try:
    let dir = filePath.splitFile.dir
    if not dirExists(dir):
      createDir(dir)
    
    writeFile(filePath, content)
    return true
  except:
    echo "Error creating file: ", filePath
    echo getCurrentExceptionMsg()
    return false

proc generateStepsFile(config: ScaffoldConfig, filePath: string): bool =
  ## ステップファイルの生成
  let moduleNameParts = config.name.split('_')
  let moduleNameTitle = moduleNameParts.mapIt(it.capitalize).join(" ")
  
  let content = """## ${1}_steps.nim
## $2
##
## $3のBDDステップ定義
##

import ../vendor/cucumber_nim/src/cucumber_nim
import ../vendor/power_assert_nim/src/power_assert

when defined(nimTest):
  import $1
else:
  import ../../src/$1

# 状態を保持するグローバル変数
var
  initialized = false
  result = ""
  errorMessage = ""

# 前提条件
step(stGiven, "I have imported the $1 module"):
  # このステップは自動的に満たされる（インポート済み）
  result = true

step(stGiven, "I have initialized the necessary components"):
  initialized = true
  result = true

step(stGiven, "I have provided invalid input"):
  # 無効な入力を準備
  result = true

# アクション
step(stWhen, "I call the main function"):
  if initialized:
    result = "success"
  else:
    errorMessage = "Components not initialized"
    result = false

# 検証
step(stThen, "it should return the expected result"):
  check(result == "success")
  result = true

step(stThen, "no errors should be thrown"):
  check(errorMessage == "")
  result = true

step(stThen, "it should handle the error gracefully"):
  # エラー処理のテスト
  result = true

step(stThen, "return an appropriate error message"):
  check(errorMessage.len > 0)
  result = true
""" % [config.name, repeat("=", config.name.len + 10), moduleNameTitle]
  
  if config.dryRun:
    echo "Would create file: ", filePath
    echo "Content:"
    echo content
    return true
  
  try:
    let dir = filePath.splitFile.dir
    if not dirExists(dir):
      createDir(dir)
    
    writeFile(filePath, content)
    return true
  except:
    echo "Error creating file: ", filePath
    echo getCurrentExceptionMsg()
    return false

proc generateReadmeFile(config: ScaffoldConfig, filePath: string): bool =
  ## READMEファイルの生成
  let content = """# $1

## 概要
$2

## 機能
- 機能1
- 機能2
- 機能3

## インストール
```bash
nimble install $1
```

## 使用方法
```nim
import $1

# 以下に使用例を記述
```

## テスト
```bash
# ユニットテスト実行
nimble test

# BDDテスト実行
nimble features
```

## ドキュメント
詳細なドキュメントは docs/ ディレクトリを参照してください。

## ライセンス
MIT License
""" % [config.name, config.description]
  
  if config.dryRun:
    echo "Would create file: ", filePath
    echo "Content:"
    echo content
    return true
  
  try:
    let dir = filePath.splitFile.dir
    if not dirExists(dir):
      createDir(dir)
    
    writeFile(filePath, content)
    return true
  except:
    echo "Error creating file: ", filePath
    echo getCurrentExceptionMsg()
    return false

proc scaffoldModule*(config: ScaffoldConfig): bool =
  ## モジュールのスキャフォールド
  var success = true
  let baseDir = config.baseDir / config.name
  
  # ディレクトリ構造の作成
  let dirs = [
    baseDir,
    baseDir / "src",
    baseDir / "tests",
    baseDir / "tests/specs",
    baseDir / "tests/steps",
    baseDir / "examples",
    baseDir / "docs",
    baseDir / "build/bin",
    baseDir / "build/tests",
    baseDir / "build/examples",
    baseDir / "build/nimcache",
    baseDir / "build/test_output"
  ]
  
  echo "Creating directory structure..."
  for dir in dirs:
    if config.dryRun:
      echo "Would create directory: ", dir
    else:
      if not ensureDirExists(dir):
        success = false
  
  # モジュールファイルの作成
  echo "Creating module files..."
  if not generateModuleFile(config, baseDir / "src" / (config.name & ".nim")):
    success = false
  
  # Nimbleファイルの作成
  echo "Creating Nimble file..."
  if not generateNimbleFile(config, baseDir / (config.name & ".nimble")):
    success = false
  
  # テストファイルの作成
  if config.includeTests:
    echo "Creating test files..."
    if not generateTestFile(config, baseDir / "tests" / ("test_" & config.name & ".nim")):
      success = false
    
    if not generateTestAllFile(config, baseDir / "tests" / "test_all.nim"):
      success = false
      
    # Featureファイルの作成
    echo "Creating feature files..."
    if not generateFeatureFile(config, baseDir / "tests/specs" / (config.name & ".feature")):
      success = false
      
    if not generateStepsFile(config, baseDir / "tests/steps" / (config.name & "_steps.nim")):
      success = false
  
  # 例ファイルの作成
  if config.includeExamples:
    echo "Creating example files..."
    if not generateExampleFile(config, baseDir / "examples" / (config.name & "_example.nim")):
      success = false
  
  # READMEファイルの作成
  echo "Creating README file..."
  if not generateReadmeFile(config, baseDir / "README.md"):
    success = false
  
  return success

proc scaffoldProject*(config: ScaffoldConfig): bool =
  ## プロジェクトのスキャフォールド
  return scaffoldModule(config)  # 現時点ではモジュールと同じ

proc scaffold*(config: ScaffoldConfig): bool =
  ## スキャフォールドを生成
  case config.type
  of stModule:
    return scaffoldModule(config)
  of stProject:
    return scaffoldProject(config)
  of stTest:
    # テストファイルのみ生成
    let baseDir = config.baseDir
    echo "Creating test file..."
    return generateTestFile(config, baseDir / "tests" / ("test_" & config.name & ".nim"))

when isMainModule:
  import parseopt
  
  proc showHelp() =
    echo "Scaffold Tool - プロジェクト構造のスキャフォールド"
    echo "Usage: scaffold [options] <name>"
    echo "Options:"
    echo "  --type=MODULE|PROJECT|TEST  スキャフォールドタイプ (デフォルト: MODULE)"
    echo "  --no-tests                  テストを含めない"
    echo "  --no-examples               例を含めない"
    echo "  --base-dir=DIR              基本ディレクトリ (デフォルト: 現在のディレクトリ)"
    echo "  --author=NAME               作者名"
    echo "  --description=DESC          説明"
    echo "  --nim-version=VERSION       Nimバージョン (デフォルト: 1.6.0)"
    echo "  --dry-run                   実際にファイルを作成しないで表示のみ"
    echo "  --help                      このヘルプを表示"
    quit(0)
  
  proc parseScaffoldType(typ: string): ScaffoldType =
    case typ.toLowerAscii
    of "module": stModule
    of "project": stProject
    of "test": stTest
    else: stModule
  
  # 引数解析
  var name = ""
  var config = newScaffoldConfig(name)
  
  for kind, key, val in getopt():
    case kind
    of cmdLongOption, cmdShortOption:
      case key
      of "type", "t":
        config.type = parseScaffoldType(val)
      of "no-tests":
        config.includeTests = false
      of "no-examples":
        config.includeExamples = false
      of "base-dir", "d":
        config.baseDir = val
      of "author", "a":
        config.authorName = val
      of "description", "desc":
        config.description = val
      of "nim-version", "n":
        config.nimVersion = val
      of "dry-run":
        config.dryRun = true
      of "help", "h":
        showHelp()
      else:
        echo "Unknown option: ", key
        showHelp()
    of cmdArgument:
      name = key
    of cmdEnd:
      break
  
  if name.len == 0:
    echo "Error: Name is required"
    showHelp()
  
  config.name = name
  
  # スキャフォールド実行
  let success = scaffold(config)
  
  if success:
    if config.dryRun:
      echo "Dry run completed. No files were created."
    else:
      echo "Scaffold generated successfully at: ", absolutePath(config.baseDir / config.name)
    quit(0)
  else:
    echo "Error: Failed to generate scaffold"
    quit(1)