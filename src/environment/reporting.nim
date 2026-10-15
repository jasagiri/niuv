## environment/reporting.nim
## =========================
##
## Environment-specific test reporting functionality for niuv
## Provides environment management specific test result formatting and integration

import std/[strformat, strutils, os, terminal, times, tables]
import "../../../nim-testkit/src/reporting"

# Re-export nim-testkit types for compatibility
export reporting.ReportFormatter
export reporting.EnhancedTestStatistics
export reporting.TestResult
export reporting.TestStatus
export reporting.TestCategory

# Environment-specific test categories
type
  NiuvTestCategory* = enum
    EnvironmentTest   = "environment"
    ConfigurationTest = "configuration"
    DependencyTest    = "dependency"
    InstallationTest  = "installation"
    ParallelTest      = "parallel"
    WorkspaceTest     = "workspace"
    IntegrationTest   = "integration"

  # Environment context for reporting
  EnvironmentContext* = object
    envPath*: string         # Virtual environment path
    nimVersion*: string      # Nim version being tested
    configFile*: string      # Configuration file used
    dependencies*: seq[string] # List of dependencies
    parallelJobs*: int       # Number of parallel jobs
    lockFile*: string        # Lock file path

  # Environment-specific formatter that extends nim-testkit
  EnvironmentReportFormatter* = ref object of ReportFormatter
    context*: EnvironmentContext
    showEnvironmentInfo*: bool
    showDependencyInfo*: bool
    showTimingBreakdown*: bool

# Environment-specific reporting procedures
proc newEnvironmentReportFormatter*(context: EnvironmentContext,
                                    showEnvInfo = true,
                                    showDepInfo = true,
                                    showTiming = true): EnvironmentReportFormatter =
  result = EnvironmentReportFormatter(
    context: context,
    showEnvironmentInfo: showEnvInfo,
    showDependencyInfo: showDepInfo,
    showTimingBreakdown: showTiming,
    colored: true,
    showStackTrace: false,
    verbosityLevel: 1
  )

method beginTesting*(formatter: EnvironmentReportFormatter) =
  ## Environment-specific test initialization
  if formatter.showEnvironmentInfo:
    echo "\n" & "=".repeat(60)
    echo "Niuv Environment Test Report"
    echo "=".repeat(60)
    
    if formatter.context.envPath.len > 0:
      echo fmt"Environment: {formatter.context.envPath}"
    if formatter.context.nimVersion.len > 0:
      echo fmt"Nim Version: {formatter.context.nimVersion}"
    if formatter.context.configFile.len > 0 and fileExists(formatter.context.configFile):
      echo fmt"Config File: {formatter.context.configFile}"
    if formatter.context.parallelJobs > 0:
      echo fmt"Parallel Jobs: {formatter.context.parallelJobs}"
    if formatter.context.lockFile.len > 0 and fileExists(formatter.context.lockFile):
      echo fmt"Lock File: {formatter.context.lockFile}"
    
    if formatter.showDependencyInfo and formatter.context.dependencies.len > 0:
      echo "\nDependencies:"
      for dep in formatter.context.dependencies:
        echo fmt"  - {dep}"
    
    echo "\nStarting tests..."
    echo "-".repeat(60)

method endTesting*(formatter: EnvironmentReportFormatter, stats: EnhancedTestStatistics) =
  ## Environment-specific test completion
  echo "-".repeat(60)
  echo "Test Execution Complete"
  
  # Basic statistics
  echo fmt"Total: {stats.total} tests, Passed: {stats.passed}, Failed: {stats.failed}"
  echo fmt"Skipped: {stats.skipped}, Errors: {stats.errors}"
  echo fmt"Duration: {stats.duration:.3f} seconds"
  
  if formatter.showTimingBreakdown and stats.categoryStats.len() > 0:
    echo "\nTiming by Category:"
    for category, catStats in stats.categoryStats:
      let avgTime = if catStats.total > 0: stats.duration / float(catStats.total) else: 0.0
      echo fmt"  {category}: {catStats.total} tests ({avgTime:.3f}s avg)"
  
  # Environment-specific summary
  if formatter.context.envPath.len > 0:
    let envStatus = if stats.failed + stats.errors == 0: "HEALTHY" else: "ISSUES DETECTED"
    echo fmt"\nEnvironment Status: {envStatus}"
    
    if stats.failed + stats.errors > 0:
      echo "Issues found in environment testing. Consider:"
      echo "  - Verifying dependency installation"
      echo "  - Checking configuration file validity"
      echo "  - Ensuring Nim version compatibility"
  
  let successRate = if stats.total > 0: float(stats.passed) / float(stats.total) * 100.0 else: 0.0
  
  if formatter.colored:
    let rateColor = if successRate >= 95.0: fgGreen
                   elif successRate >= 80.0: fgYellow
                   else: fgRed
    styledEcho(styleBright, "Success Rate: ", rateColor, fmt"{successRate:.2f}%")
  else:
    echo fmt"Success Rate: {successRate:.2f}%"
  
  echo "=".repeat(60)

# Helper procedures for environment testing integration
proc gatherEnvironmentContext*(envPath = "", configFile = "niuv.toml"): EnvironmentContext =
  ## Gather environment context for reporting
  result = EnvironmentContext(
    envPath: if envPath.len > 0: envPath else: getCurrentDir(),
    configFile: configFile,
    dependencies: @[],
    parallelJobs: 1
  )
  
  # Try to detect Nim version
  try:
    when defined(NimVersion):
      result.nimVersion = NimVersion
    else:
      result.nimVersion = "unknown"
  except:
    result.nimVersion = "unknown"
  
  # Try to read configuration for more context
  if fileExists(configFile):
    try:
      # Simple config parsing - would integrate with niuv's config module
      let configContent = readFile(configFile)
      if "parallelJobs" in configContent:
        # This is simplified - real implementation would use proper TOML parsing
        result.parallelJobs = 4  # Default assumption
    except:
      discard
  
  # Look for lock file
  for lockFile in ["nimble.lock", "niuv.lock"]:
    if fileExists(lockFile):
      result.lockFile = lockFile
      break

proc createEnvironmentTestSuite*(suiteName: string, envPath = ""): EnvironmentReportFormatter =
  ## Create a test suite with environment context
  let context = gatherEnvironmentContext(envPath)
  result = newEnvironmentReportFormatter(context)

# Integration helpers for existing niuv test infrastructure
proc migrateFromLegacyReporting*(legacyResults: seq[tuple[name: string, status: string, message: string]]): seq[TestResult] =
  ## Helper to migrate from old niuv reporting format to nim-testkit format
  result = @[]
  
  for legacyResult in legacyResults:
    let status = case legacyResult.status.toLowerAscii()
                of "pass", "passed", "ok": tsPassed
                of "fail", "failed", "error": tsFailed
                of "skip", "skipped": tsSkipped
                else: tsError
    
    result.add(TestResult(
      name: legacyResult.name,
      category: tcIntegration,
      status: status,
      startTime: epochTime(),
      endTime: epochTime(),
      duration: 0.0,
      message: legacyResult.message,
      stackTrace: "",
      file: "environment"
    ))
