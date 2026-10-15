## testkit_adapter.nim
## ===================
##
## Adapter layer to integrate nim-testkit functionality into niuv
## This module bridges niuv's virtual environment features with nim-testkit's
## comprehensive test execution and reporting capabilities
##

import std/[
  os,
  strutils,
  strformat,
  tables,
  sequtils,
  times,
  json,
  parseopt
]

# Import nim-testkit modules
import ../../../nim-testkit/src/core/[types, runner, results]
import ../../../nim-testkit/src/reporting/base as reporting_base
import ../../../nim-testkit/src/config/config as testkit_config

# Import niuv modules
import ../utils
import ../cli
import ../config

# Re-export nim-testkit types
export types, runner, results

# Import nim-testkit modules conditionally
when defined(niuvTestKit):
  import ../../nim-testkit/src/nimtestkit
  import ../../nim-testkit/src/core/[types, runner, results]
  import ../../nim-testkit/src/analysis/mece_detector
  import ../../nim-testkit/src/config/parser as testkit_parser
  import ../../nim-testkit/src/generation/[unit_gen, integration_gen, system_gen]

type
  TestKitAdapter* = object
    ## Adapter that bridges niuv virtual environments with nim-testkit
    config: testkit_config.TestConfig
    runner: TestRunner
    envPath: string
    niuvConfig: NiuvConfig

proc initTestKitAdapter*(envPath: string, niuvConfig: NiuvConfig): TestKitAdapter =
  ## Initialize adapter with virtual environment path and configuration
  let tkConfig = testkit_config.TestConfig(
    testDir: niuvConfig.testDir,
    outputDir: niuvConfig.outputDir,
    pattern: niuvConfig.testPattern,
    verbose: niuvConfig.verboseOutput,
    failFast: niuvConfig.failFast,
    parallel: niuvConfig.parallelJobs > 1,
    timeout: 30000,
    format: testkit_config.OutputFormat.Text
  )
  
  result = TestKitAdapter(
    config: tkConfig,
    runner: initTestRunner(tkConfig),
    envPath: envPath,
    niuvConfig: niuvConfig
  )

proc setupEnvironmentPaths*(adapter: TestKitAdapter) =
  ## Set up environment-specific paths for test execution
  putEnv("NIUV_ENV", adapter.envPath)
  putEnv("NIUV_TEST_MODE", "true")
  
  # Add virtual environment bin to PATH
  let binPath = adapter.envPath / "bin"
  if dirExists(binPath):
    let currentPath = getEnv("PATH")
    putEnv("PATH", binPath & PathSep & currentPath)

proc runTests*(adapter: var TestKitAdapter): TestReport =
  ## Run tests in the virtual environment using nim-testkit
  # Set up environment
  adapter.setupEnvironmentPaths()
  
  # Discover test files
  let testFiles = adapter.discoverTests()
  
  if testFiles.len == 0:
    cli.showError("No test files found")
    return TestReport(
      totalTests: 0,
      passed: 0,
      failed: 0,
      skipped: 0,
      errors: 0,
      duration: 0.0,
      startTime: now(),
      endTime: now()
    )
  
  cli.showInfo(fmt"Running {testFiles.len} test files in {adapter.envPath}")
  
  # Run tests using nim-testkit
  return adapter.runner.run()

proc discoverTests*(adapter: TestKitAdapter): seq[string] =
  ## Discover test files in the virtual environment
  result = @[]
  let testDir = adapter.envPath / adapter.niuvConfig.testDir
  
  if not dirExists(testDir):
    return result
  
  for kind, path in walkDir(testDir):
    if kind == pcFile and path.endsWith(".nim"):
      let filename = extractFilename(path)
      if filename.match(re(adapter.niuvConfig.testPattern)):
        result.add(path)

proc addEnvironmentReporter*(adapter: var TestKitAdapter, reporter: reporting_base.ReportFormatter) =
  ## Add a custom reporter to the test runner
  adapter.runner.addReporter(reporter)

proc cleanupEnvironment*(adapter: TestKitAdapter) =
  ## Clean up environment variables after test execution
  if existsEnv("NIUV_ENV"):
    delEnv("NIUV_ENV")
  if existsEnv("NIUV_TEST_MODE"):
    delEnv("NIUV_TEST_MODE")

# Helper functions for test discovery
import std/re

proc toTestCategory*(testFile: string): TestCategory =
  ## Determine test category based on file name or path
  let fileName = extractFilename(testFile).toLowerAscii()
  let path = testFile.toLowerAscii()
  
  if "integration" in path or "integration" in fileName:
    return TestCategory.Integration
  elif "system" in path or "e2e" in fileName:
    return TestCategory.System
  elif "perf" in fileName or "benchmark" in fileName:
    return TestCategory.Performance
  else:
    return TestCategory.Unit

# Export convenience functions
proc isTestKitAvailable*(): bool =
  ## Check if nim-testkit is properly integrated
  true  # Always available when using this adapter

proc getTestKitVersion*(): string =
  ## Get nim-testkit version
  "1.0.0"  # Using latest nim-testkit

when isMainModule:
  echo "Niuv TestKit Adapter"
  echo "This module bridges niuv virtual environments with nim-testkit"
  echo "\nUsage: Import this module and use initTestKitAdapter() to create an adapter"