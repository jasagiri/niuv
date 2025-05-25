# Package
version       = "0.0.0"
author        = "jasagiri"
description   = "Nim Virtual Environment Manager"
license       = "MIT"
srcDir        = "src"
bin           = @["niuv"]
binDir        = "build/bin"

# Dependencies
requires "nim >= 2.2.0"
requires "parsetoml >= 0.7.2"
requires "weave >= 0.4.10"
requires "results >= 0.3.0"

# Note: power_assert and cucumber_nim dependencies have been removed
# Tests now use standard unittest framework

requires "http://github.com/jasagiri/nim-lang-core.git"
requires "http://github.com/jasagiri/nim-libaspects.git"
# requires "http://github.com/jasagiri/nim-design-pattern.git"
requires "http://github.com/jasagiri/nim-testkit.git"

# ============= タスク定義 =============
import std/strformat

# テスト関連タスク
task test, "Run all tests":
  # スクリプトベースのテスト実行
  when defined(windows):
    exec "scripts\\run_tests.bat"
  else:
    exec "sh scripts/run_tests.sh"

task testOne, "Run a specific test":
  var testFile = paramStr(3)
  if testFile.len > 0:
    when defined(windows):
      exec "scripts\\tests\\run_specific_test.bat " & testFile
    else:
      exec "sh scripts/tests/run_specific_test.sh " & testFile
  else:
    echo "Please specify a test file to run"
    echo "Example: nimble testOne test_config.nim"

# BDD/Feature テスト関連
task features, "Run BDD feature tests":
  when defined(windows):
    exec "scripts\\features\\run_features.bat"
  else:
    exec "sh scripts/features/run_features.sh"

task featureOne, "Run a specific feature test":
  var feature = paramStr(3)
  if feature.len > 0:
    when defined(windows):
      exec "scripts\\features\\run_features.bat --pattern=" & feature
    else:
      exec "sh scripts/features/run_features.sh --pattern=" & feature
  else:
    echo "Please specify a feature file to run"
    echo "Example: nimble featureOne env.feature"

# ビルド関連タスク
task build, "Build the niuv executable":
  when defined(windows):
    exec "scripts\\build\\build.bat"
  else:
    exec "sh scripts/build/build.sh"

task buildTest, "Build a test without running it":
  var testFile = paramStr(3)
  if testFile.len > 0:
    when defined(windows):
      exec "scripts\\compile_tests.bat " & testFile
    else:
      exec "sh scripts/compile_tests.sh " & testFile
  else:
    echo "Please specify a test file to build"
    echo "Example: nimble buildTest tests/test_config.nim"

task buildAllTests, "Build all tests without running them":
  when defined(windows):
    exec "scripts\\compile_tests.bat"
  else:
    exec "sh scripts/compile_tests.sh"

task buildExamples, "Build all examples without running them":
  when defined(windows):
    exec "scripts\\compile_examples.bat"
  else:
    exec "sh scripts/compile_examples.sh"

# クリーンアップ関連タスク
task clean, "Clean build artifacts":
  when defined(windows):
    exec "scripts\\clean\\clean.bat"
  else:
    exec "sh scripts/clean/clean.sh"

task cleanall, "Clean all artifacts including nimbledeps":
  when defined(windows):
    exec "scripts\\clean\\clean.bat --all"
  else:
    exec "sh scripts/clean/clean.sh --all"

task cleanup, "Remove unnecessary files":
  echo "Removing unnecessary files..."
  when defined(windows):
    exec "scripts\\cleanup\\cleanup_files.bat"
  else:
    exec "sh scripts/cleanup/cleanup_files.sh"

task moveScripts, "Move scripts to standard locations":
  echo "Moving scripts to standard locations..."
  when defined(windows):
    exec "scripts\\cleanup\\move_cucumber_scripts.bat"
  else:
    exec "sh scripts/cleanup/move_cucumber_scripts.sh"

# ドキュメント関連タスク
task doc, "Generate documentation":
  when defined(windows):
    exec "scripts\\docs\\docs.bat"
  else:
    exec "sh scripts/docs/docs.sh"

# レポート関連タスク
task testReport, "Generate HTML and JSON test reports":
  when defined(windows):
    exec "scripts\\tests\\generate_test_report.bat"
  else:
    exec "sh scripts/tests/generate_test_report.sh"

task featureReport, "Generate feature test reports":
  var format = paramStr(3)
  var output = paramStr(4)
  
  when defined(windows):
    var cmd = "scripts\\reports\\feature_report.bat"
    if format.len > 0:
      cmd.add(" " & format)
      if output.len > 0:
        cmd.add(" " & output)
    exec cmd
  else:
    var cmd = "sh scripts/reports/feature_report.sh"
    if format.len > 0:
      cmd.add(" " & format)
      if output.len > 0:
        cmd.add(" " & output)
    exec cmd

# カバレッジ関連タスク
task coverage, "Generate test coverage report":
  when defined(windows):
    exec "scripts\\coverage\\coverage.bat"
  else:
    exec "bash scripts/coverage/coverage.sh"

# CI関連タスク
task ci, "Run CI workflow (clean, build, test)":
  when defined(windows):
    exec "scripts\\ci\\ci_script.bat"
  else:
    exec "sh scripts/ci/ci_script.sh"

# スキャフォールド関連タスク
task scaffold, "Scaffold a new module or project":
  var name = paramStr(3)
  if name.len > 0:
    # scaffoldはsrcベースのまま（スクリプト化されていない）
    exec "nim c -r src/templates/scaffold.nim " & name
  else:
    echo "Please specify a name for the module or project"
    echo "Example: nimble scaffold mymodule"

# 複合タスク
task testWithReport, "Run tests and generate reports":
  # テスト実行
  when defined(windows):
    exec "scripts\\run_tests.bat"
    exec "scripts\\tests\\generate_test_report.bat"
  else:
    exec "sh scripts/run_tests.sh"
    exec "sh scripts/tests/generate_test_report.sh"

task fullTest, "Run all tests with reports and coverage":
  echo "Running full test suite with reports and coverage..."
  
  # クリーンアップ
  exec "nimble clean"
  
  # テスト実行
  exec "nimble test"
  
  # レポート生成
  exec "nimble testReport"
  
  # カバレッジ生成
  exec "nimble coverage"

# デバッグ/実験タスク
task demo, "Run various demo scripts":
  echo "Running demos..."
  when defined(windows):
    exec "scripts\\demo\\run_cancellation_demo.bat"
  else:
    exec "sh scripts/demo/run_cancellation_demo.sh"

# ユーティリティタスク
task checkScripts, "Check if all required scripts exist":
  let requiredScripts = @[
    "scripts/run_tests",
    "scripts/build/build",
    "scripts/clean/clean",
    "scripts/docs/docs",
    "scripts/coverage/coverage",
    "scripts/tests/run_specific_test",
    "scripts/tests/generate_test_report",
    "scripts/features/run_features",
    "scripts/reports/feature_report",
    "scripts/compile_tests",
    "scripts/compile_examples",
    "scripts/ci/ci_script",
    "scripts/cleanup/cleanup_files",
    "scripts/cleanup/move_cucumber_scripts",
    "scripts/demo/run_cancellation_demo"
  ]
  
  var missing = 0
  for script in requiredScripts:
    let ext = when defined(windows): ".bat" else: ".sh"
    let fullPath = script & ext
    if not fileExists(fullPath):
      echo "Missing: " & fullPath
      missing += 1
  
  if missing > 0:
    echo &"{missing} scripts are missing!"
  else:
    echo "All required scripts are present."

# ヘルプタスク  
task help, "Show available tasks":
  echo """
Available tasks:
  
Build:
  build          - Build the niuv executable
  buildTest      - Build a specific test without running
  buildAllTests  - Build all tests without running
  buildExamples  - Build all examples without running
  
Test:
  test          - Run all tests
  testOne       - Run a specific test
  features      - Run BDD feature tests
  featureOne    - Run a specific feature test
  
Clean:
  clean         - Clean build artifacts
  cleanall      - Clean all including nimbledeps
  cleanup       - Remove unnecessary files
  moveScripts   - Move scripts to standard locations
  
Documentation:
  doc           - Generate documentation
  
Reports:
  testReport    - Generate test reports
  featureReport - Generate feature test reports
  coverage      - Generate test coverage report
  
CI/CD:
  ci            - Run CI workflow
  
Utility:
  scaffold      - Scaffold a new module
  demo          - Run demo scripts
  checkScripts  - Check if required scripts exist
  help          - Show this help message
  
Composite:
  testWithReport - Run tests and generate reports
  fullTest      - Full test suite with coverage
"""
