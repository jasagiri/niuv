## testkit_adapter.nim
## ===================
##
## Adapter layer to integrate nim-testkit functionality into niuv
## This module contains all test configuration defaults and handles
## the bridge between niuv's minimal interface and nim-testkit's features
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

# Import niuv modules
import test_framework
import test_types
import utils
import cli

# Export types
export test_types

# Import nim-testkit modules conditionally
when defined(niuvTestKit):
  import ../../nim-testkit/src/nimtestkit
  import ../../nim-testkit/src/core/[types, runner, results]
  import ../../nim-testkit/src/analysis/mece_detector
  import ../../nim-testkit/src/config/parser as testkit_parser
  import ../../nim-testkit/src/generation/[unit_gen, integration_gen, system_gen]

type
  TestKitAdapter* = object
    when defined(niuvTestKit):
      config: TestConfig
      runner: TestRunner
    niuvConfig: TestRunnerConfig
    
  ConversionResult* = object
    when defined(niuvTestKit):
      suite: TestSuite
    warnings: seq[string]

  # Test configuration with all defaults
  TestKitConfig* = object
    # Test execution
    backend*: TestBackend
    pattern*: string
    failFast*: bool
    outputDir*: string
    generateReport*: bool
    verbose*: bool
    parallel*: bool
    parallelJobs*: int
    timeout*: float
    
    # Test categories and organization
    categories*: seq[string]
    customCategories*: seq[string]
    
    # MECE analysis
    meceEnabled*: bool
    meceStrict*: bool
    
    # Directory structure
    testDir*: string
    unitDir*: string
    integrationDir*: string
    systemDir*: string
    performanceDir*: string
    
    # Coverage options
    coverageThreshold*: float
    coverageFormats*: seq[string]
    coverageOutputDir*: string
    coverageInclude*: seq[string]
    coverageExclude*: seq[string]
    
    # Reporting
    reportFormats*: seq[string]
    htmlTheme*: string
    
    # Advanced options
    randomSeed*: int
    retryFailedTests*: int
    tagFilter*: seq[string]
    excludeTags*: seq[string]

# Default configuration values
proc newTestKitConfig*(): TestKitConfig =
  result = TestKitConfig(
    # Test execution defaults
    backend: tbNiuv,
    pattern: "test_*.nim",
    failFast: false,
    outputDir: "build/test_output",
    generateReport: true,
    verbose: false,
    parallel: false,
    parallelJobs: 0,  # 0 means use CPU count
    timeout: 300.0,   # 5 minutes default
    
    # Test categories
    categories: @["unit", "integration", "system", "performance"],
    customCategories: @[],
    
    # MECE analysis
    meceEnabled: true,
    meceStrict: false,
    
    # Directory structure
    testDir: "tests",
    unitDir: "tests/unit",
    integrationDir: "tests/integration", 
    systemDir: "tests/system",
    performanceDir: "tests/performance",
    
    # Coverage defaults
    coverageThreshold: 80.0,
    coverageFormats: @["html", "json"],
    coverageOutputDir: "coverage",
    coverageInclude: @["src/**/*.nim"],
    coverageExclude: @["tests/**/*.nim", "vendor/**/*.nim"],
    
    # Reporting
    reportFormats: @["html", "json"],
    htmlTheme: "default",
    
    # Advanced
    randomSeed: 0,
    retryFailedTests: 0,
    tagFilter: @[],
    excludeTags: @[]
  )

# Load configuration from niuv.toml
proc loadTestKitConfigFromToml*(path: string = "niuv.toml"): TestKitConfig =
  result = newTestKitConfig()
  
  if not fileExists(path):
    return result
  
  # Parse TOML file and override defaults
  # This is a simplified version - full implementation would use parsetoml
  let content = readFile(path)
  
  # Simple pattern matching for common options
  if content.contains("[tool.niuv.testing]"):
    for line in content.splitLines():
      let trimmed = line.strip()
      if trimmed.startsWith("backend"):
        if "testkit" in trimmed:
          result.backend = tbTestKit
      elif trimmed.startsWith("pattern"):
        let parts = trimmed.split("=")
        if parts.len > 1:
          result.pattern = parts[1].strip().strip(chars = {'"'})
      elif trimmed.startsWith("fail_fast"):
        result.failFast = "true" in trimmed
      elif trimmed.startsWith("output_dir"):
        let parts = trimmed.split("=")
        if parts.len > 1:
          result.outputDir = parts[1].strip().strip(chars = {'"'})

# Parse command line arguments with all options
proc parseTestKitArgs*(args: seq[string], config: var TestKitConfig) =
  var p = initOptParser(args)
  
  while true:
    p.next()
    case p.kind
    of cmdEnd: break
    of cmdShortOption, cmdLongOption:
      case p.key
      # Basic options
      of "backend", "b":
        case p.val.toLowerAscii()
        of "niuv": config.backend = tbNiuv
        of "testkit", "tk": config.backend = tbTestKit
        else: discard
      of "pattern", "p":
        config.pattern = p.val
      of "fail-fast", "f":
        config.failFast = true
      of "output-dir", "o":
        config.outputDir = p.val
      of "no-report":
        config.generateReport = false
      of "verbose", "v":
        config.verbose = true
      
      # Parallel execution
      of "parallel":
        config.parallel = true
      of "jobs", "j":
        config.parallelJobs = parseInt(p.val)
      
      # Coverage options
      of "threshold":
        config.coverageThreshold = parseFloat(p.val)
      of "coverage-format":
        config.coverageFormats = p.val.split(",")
      of "coverage-output":
        config.coverageOutputDir = p.val
      of "include":
        config.coverageInclude.add(p.val)
      of "exclude":
        config.coverageExclude.add(p.val)
      
      # Advanced options
      of "timeout", "t":
        config.timeout = parseFloat(p.val)
      of "seed":
        config.randomSeed = parseInt(p.val)
      of "retry":
        config.retryFailedTests = parseInt(p.val)
      of "tag":
        config.tagFilter.add(p.val)
      of "exclude-tag":
        config.excludeTags.add(p.val)
      
      else: discard
    of cmdArgument:
      # Arguments are handled elsewhere
      discard

# Convert TestKitConfig to TestRunnerConfig
proc toTestRunnerConfig*(config: TestKitConfig): TestRunnerConfig =
  result = TestRunnerConfig(
    mode: trmPattern,
    testFiles: @[],
    pattern: config.pattern,
    verbose: config.verbose,
    outputDir: config.outputDir,
    generateReport: config.generateReport,
    failFast: config.failFast,
    testDir: config.testDir,
    backend: config.backend
  )

# Enhanced test runner with all configuration
# NOTE: This function is temporarily disabled due to circular import issues
# It would need to be moved to niuv_testing.nim or another module
# proc runTestsWithConfig*(config: TestKitConfig, testFiles: seq[string] = @[]): bool =
#   var runnerConfig = config.toTestRunnerConfig()
#   
#   if testFiles.len > 0:
#     runnerConfig.testFiles = testFiles
#     runnerConfig.mode = trmSingle
#   
#   # Set up environment based on config
#   if config.parallel and config.parallelJobs > 0:
#     putEnv("NIUV_TEST_PARALLEL_JOBS", $config.parallelJobs)
#   
#   if config.randomSeed != 0:
#     putEnv("NIUV_TEST_RANDOM_SEED", $config.randomSeed)
#   
#   # Run tests
#   result = runAndReport(runnerConfig)
#   
#   # Clean up environment
#   if existsEnv("NIUV_TEST_PARALLEL_JOBS"):
#     delEnv("NIUV_TEST_PARALLEL_JOBS")
#   if existsEnv("NIUV_TEST_RANDOM_SEED"):
#     delEnv("NIUV_TEST_RANDOM_SEED")

when defined(niuvTestKit):
  # Conversion between niuv and nim-testkit test categories
  proc toTestCategory*(niuvTestFile: string): TestCategory =
    ## Determine test category based on file name or path
    let fileName = extractFilename(niuvTestFile).toLowerAscii()
    let path = niuvTestFile.toLowerAscii()
    
    if "integration" in path or "integration" in fileName:
      return tcIntegration
    elif "system" in path or "e2e" in fileName:
      return tcSystem
    elif "perf" in fileName or "benchmark" in fileName:
      return tcPerformance
    else:
      return tcUnit

  proc toOutputFormat*(format: string): OutputFormat =
    ## Convert string format to nim-testkit OutputFormat
    case format.toLowerAscii()
    of "json": ofJson
    of "xml": ofXml
    of "tap": ofTap
    of "junit": ofJunit
    else: ofText

  proc initTestKitAdapter*(config: TestKitConfig): TestKitAdapter =
    ## Initialize the adapter with TestKit configuration
    var tkConfig = TestConfig(
      verbose: config.verbose,
      parallel: config.parallel,
      failFast: config.failFast,
      timeout: config.timeout,
      reportFile: config.outputDir / "testkit_report.json",
      randomSeed: config.randomSeed,
      outputFormat: ofText,
      filter: TestFilter(
        categories: @[],
        tags: config.tagFilter,
        patterns: @[config.pattern],
        excludePatterns: @[]
      )
    )
    
    result = TestKitAdapter(
      config: tkConfig,
      runner: initTestRunner(tkConfig),
      niuvConfig: config.toTestRunnerConfig()
    )

  proc parseNiuvTest(testFile: string): seq[tuple[name: string, lineNo: int]] =
    ## Parse a niuv test file to extract test names and line numbers
    let content = readFile(testFile)
    var tests: seq[tuple[name: string, lineNo: int]] = @[]
    
    var lineNo = 0
    for line in content.splitLines():
      inc lineNo
      # Look for test definitions
      if line.strip().startsWith("test \"") or line.strip().startsWith("test\""):
        let startQuote = line.find('"')
        let endQuote = line.find('"', startQuote + 1)
        if startQuote >= 0 and endQuote > startQuote:
          let testName = line[startQuote + 1 ..< endQuote]
          tests.add((name: testName, lineNo: lineNo))
    
    return tests

  proc convertNiuvTest*(adapter: TestKitAdapter, testFile: string): ConversionResult =
    ## Convert a niuv test file to nim-testkit TestSuite
    var warnings: seq[string] = @[]
    
    # Extract test information
    let testInfo = parseNiuvTest(testFile)
    let category = toTestCategory(testFile)
    let suiteName = extractFilename(testFile).changeFileExt("")
    
    # Create test cases
    var testCases: seq[types.TestCase] = @[]
    
    for (name, lineNo) in testInfo:
      # Create a wrapper proc that will run the niuv test
      proc testProc() {.nimcall.} =
        # This is a placeholder - actual implementation would need to
        # dynamically compile and run the specific test
        discard
      
      let tc = types.TestCase(
        name: name,
        category: category,
        file: testFile,
        line: lineNo,
        testProc: testProc,
        setupProc: nil,
        teardownProc: nil,
        tags: @[],
        timeout: 0.0
      )
      testCases.add(tc)
    
    # Create test suite
    let suite = TestSuite(
      name: suiteName,
      category: category,
      tests: testCases,
      setupSuite: nil,
      teardownSuite: nil,
      parallel: false
    )
    
    if testCases.len == 0:
      warnings.add(fmt"No tests found in {testFile}")
    
    result = ConversionResult(
      suite: suite,
      warnings: warnings
    )

  proc runWithTestKit*(adapter: var TestKitAdapter, testFiles: seq[string]): bool =
    ## Run tests using nim-testkit backend
    logInfo("Running tests with nim-testkit backend")
    
    # Convert all test files to test suites
    var totalWarnings: seq[string] = @[]
    
    for testFile in testFiles:
      let fullPath = if adapter.niuvConfig.testDir != "":
        adapter.niuvConfig.testDir / testFile
      else:
        testFile
      
      if not fileExists(fullPath):
        logWarning(fmt"Test file not found: {fullPath}")
        continue
      
      let convResult = adapter.convertNiuvTest(fullPath)
      adapter.runner.addSuite(convResult.suite)
      totalWarnings.add(convResult.warnings)
    
    # Show warnings
    for warning in totalWarnings:
      logWarning(warning)
    
    # Run tests
    let report = adapter.runner.run()
    
    # Generate reports in requested formats
    if adapter.niuvConfig.generateReport:
      # Save testkit native report
      let jsonReport = $ %* {
        "totalTests": report.totalTests,
        "passed": report.passed,
        "failed": report.failed,
        "skipped": report.skipped,
        "errors": report.errors,
        "duration": report.duration,
        "startTime": report.startTime,
        "endTime": report.endTime
      }
      
      let reportPath = adapter.config.reportFile
      writeFile(reportPath, jsonReport)
      logInfo(fmt"Test report saved to: {reportPath}")
    
    # Return success status
    return report.failed == 0 and report.errors == 0

  # MECE Analysis Functions
  proc analyzeMECE*(projectPath: string = getCurrentDir()): MECEReport =
    ## Analyze test structure using nim-testkit's MECE detector
    return mece_detector.analyzeMECE(projectPath)

  proc generateMECEStructure*(projectPath: string = getCurrentDir()) =
    ## Generate MECE-compliant test structure
    mece_detector.generateMECEStructure(projectPath)

  proc printMECEReport*(report: MECEReport) =
    ## Print MECE analysis report with niuv styling
    styledEcho(styleBright, "\n=== MECE Test Structure Analysis ===")
    
    if report.isValid:
      styledEcho(fgGreen, "✓ Test structure is MECE compliant")
    else:
      styledEcho(fgRed, "✗ Test structure has MECE violations")
    
    echo "\nStatistics:"
    echo fmt"  Total files: {report.stats.totalFiles}"
    echo fmt"  Categorized: {report.stats.categorizedFiles}"
    echo fmt"  Uncategorized: {report.stats.uncategorizedFiles}"
    
    if report.violations.len > 0:
      styledEcho(fgRed, "\nViolations:")
      for violation in report.violations:
        echo fmt"  - {violation}"
    
    if report.suggestions.len > 0:
      styledEcho(fgYellow, "\nSuggestions:")
      for suggestion in report.suggestions:
        echo fmt"  - {suggestion}"

  # Test Generation Wrappers
  proc generateTest*(category: string, name: string, outputPath: string): bool =
    ## Generate test file using nim-testkit templates
    let testName = if name.endsWith(".nim"): name else: name & ".nim"
    
    case category.toLowerAscii()
    of "unit":
      let content = generateUnitTest(name, moduleToTest = "")
      saveUnitTest(outputPath / testName, content)
      logInfo(fmt"Generated unit test: {outputPath / testName}")
      return true
    of "integration":
      let content = generateIntegrationTest(name, components = @[])
      saveIntegrationTest(outputPath / testName, content)
      logInfo(fmt"Generated integration test: {outputPath / testName}")
      return true
    of "system":
      let content = generateSystemTest(name, systemUnderTest = "")
      saveSystemTest(outputPath / testName, content)
      logInfo(fmt"Generated system test: {outputPath / testName}")
      return true
    else:
      logError(fmt"Unknown test category: {category}")
      return false

  # Configuration Bridge
  proc loadTestKitConfig*(configPath: string = ""): TestConfig =
    ## Load nim-testkit configuration, merging with niuv settings
    var config = testkit_parser.loadConfig(configPath)
    
    # Override with niuv-specific settings if available
    let niuvConfigPath = "niuv.toml"
    if fileExists(niuvConfigPath):
      # Parse niuv.toml for testing section
      # This is a simplified version - full implementation would parse TOML
      config.verbose = true  # Example override
    
    return config

  # Utility functions
  proc isTestKitAvailable*(): bool =
    ## Check if nim-testkit is available
    # Check if the nim-testkit directory exists
    const testkitPath = "../../nim-testkit/src/nimtestkit.nim"
    return fileExists(testkitPath)

  proc getTestKitVersion*(): string =
    ## Get nim-testkit version
    return "0.1.0"  # Placeholder version

else:
  # Stub implementations when testkit is not available
  proc analyzeMECE*(projectPath: string = getCurrentDir()): bool =
    cli.showError("MECE analysis requires nim-testkit. Compile with -d:niuvTestKit")
    return false
  
  proc printMECEReport*(report: bool) =
    discard
  
  proc generateTest*(category: string, name: string, outputPath: string): bool =
    cli.showError("Test generation requires nim-testkit. Compile with -d:niuvTestKit")
    return false

when isMainModule:
  echo "Niuv TestKit Adapter"
  echo "This module provides test configuration and nim-testkit integration"
  
  # Show default configuration
  let config = newTestKitConfig()
  echo "\nDefault Configuration:"
  echo fmt"  Backend: {config.backend}"
  echo fmt"  Pattern: {config.pattern}"
  echo fmt"  Output Dir: {config.outputDir}"
  echo fmt"  Test Dir: {config.testDir}"
  echo fmt"  Coverage Threshold: {config.coverageThreshold}%"