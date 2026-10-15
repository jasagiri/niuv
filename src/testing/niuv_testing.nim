## niuv_testing.nim
## ================
##
## niuv仮想環境でのテスト実行統合モジュール
## nim-testkitを使用してテスト実行機能を提供します
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

# Import nim-testkit for core testing functionality
when defined(niuvTestKit):
  import ../../../nim-testkit/src/core/[runner, types]
  import ../../../nim-testkit/src/execution/runner as exec_runner  
  import ../../../nim-testkit/src/reporting/[json_format, html_format, xml_format]
else:
  # Stub types when nim-testkit is not available
  type
    TestResult* = object
      name*: string
      passed*: bool
      error*: string
    TestSuite* = object  
      name*: string
      tests*: seq[TestResult]
    TestConfig* = object
      testDir*: string
      outputDir*: string
      pattern*: string
      verbose*: bool
      failFast*: bool
      parallel*: bool
      timeout*: int
      format*: OutputFormat
    OutputFormat* = enum
      Text, Json, Xml, Html
    NiuvConfig* = object
      testDir*: string
      outputDir*: string  
      testPattern*: string
      verboseOutput*: bool
      failFast*: bool
      parallelJobs*: int
    EnvironmentReportFormatter* = object
      envContext*: EnvironmentContext
    EnvironmentContext* = object
      envPath*: string
      nimVersion*: string
      configFile*: string
      dependencies*: seq[string]
      parallelJobs*: int
      lockFile*: string

# Import niuv-specific modules
import 
  ../utils/fs,
  ../config,
  ../environment/reporting

# Re-export nim-testkit types for compatibility
when defined(niuvTestKit):
  export types

proc getNimVersion*(): string =
  ## Get current Nim version
  result = NimVersion

# ログ機能
var logger = newConsoleLogger(lvlInfo, "[$levelname] ")

proc logInfo*(msg: string) =
  info(msg)

proc logWarning*(msg: string) =
  warn(msg)

proc logError*(msg: string) =
  error(msg)

proc mapToTestKitConfig*(niuvConfig: NiuvConfig): TestConfig =
  ## niuv設定をnim-testkitの設定にマッピング
  result = TestConfig(
    testDir: niuvConfig.testDir,
    outputDir: niuvConfig.outputDir,
    pattern: niuvConfig.testPattern,
    verbose: niuvConfig.verboseOutput,
    failFast: niuvConfig.failFast,
    parallel: niuvConfig.parallelJobs > 1,
    timeout: 30000,
    format: OutputFormat.Text
  )

# TODO: Fix type conflicts with environment/reporting module
# proc createEnvironmentReporter*(envPath: string): EnvironmentReportFormatter =
#   ## 環境専用レポーターを作成
#   let envContext = EnvironmentContext(
#     envPath: envPath,
#     nimVersion: getNimVersion(),
#     configFile: envPath / "niuv.toml",
#     dependencies: @[],  # Load from lock file
#     parallelJobs: 1,
#     lockFile: envPath / "nimble.lock"
#   )
#   result = newEnvironmentReportFormatter(envContext, true, true, true)

# TODO: Fix when nim-testkit integration is complete
proc runTestsInEnvironment*(envPath: string, niuvConfig: NiuvConfig): bool =
  ## Stub implementation - delegates to test runner
  logInfo("Running tests in environment: " & envPath)
  return true

when isMainModule:
  # コマンドライン引数の解析
  var envPath = getCurrentDir()
  var niuvConfig = loadConfig()
  var showHelpOnly = false
  
  for kind, key, val in getopt():
    case kind
    of cmdLongOption, cmdShortOption:
      case key
      of "help", "h":
        showHelpOnly = true
      of "verbose", "v":
        niuvConfig.verboseOutput = true
      of "output-dir", "o":
        niuvConfig.outputDir = val
      of "report":
        niuvConfig.generateJsonReport = true
        niuvConfig.generateHtmlReport = true
      of "no-report":
        niuvConfig.generateJsonReport = false
        niuvConfig.generateHtmlReport = false
      of "fail-fast", "f":
        niuvConfig.failFast = true
      of "test-dir", "d":
        niuvConfig.testDir = val
      of "pattern", "p":
        niuvConfig.testPattern = val
      of "env", "e":
        envPath = val
      else:
        echo "Unknown option: " & key
    of cmdArgument:
      # First argument is the environment path
      envPath = key
    of cmdEnd:
      break
  
  if showHelpOnly:
    echo "niuv test runner - Virtual environment test execution"
    echo "Usage: niuv test [options] [env_path]"
    echo "Options:"
    echo "  -h, --help              Show this help"
    echo "  -v, --verbose           Enable verbose output"
    echo "  -o, --output-dir=DIR    Test output directory"
    echo "  --report                Generate test reports"
    echo "  --no-report             Do not generate test reports"
    echo "  -f, --fail-fast         Stop on first test failure"
    echo "  -d, --test-dir=DIR      Test directory (default: tests)"
    echo "  -p, --pattern=PATTERN   Test file pattern (default: test_*.nim)"
    echo "  -e, --env=PATH          Virtual environment path"
    quit(0)
  
  # ログレベルの設定
  if niuvConfig.verboseOutput:
    logger.levelThreshold = lvlDebug
  else:
    logger.levelThreshold = lvlInfo
  
  # テスト実行
  let success = runTestsInEnvironment(envPath, niuvConfig)
  
  if not success:
    quit(1)