## Coverage Integration Module for Enhanced niuv
## Integrates with existing Hourai project test infrastructure

import std/[os, strutils, sequtils, json, times, osproc, strformat]

type
  CoverageIntegration* = object
    projectRoot*: string
    testSuiteFiles*: seq[string]
    coverageEnabled*: bool
    outputDir*: string
    format*: string
    threshold*: float

proc initCoverageIntegration*(projectRoot: string): CoverageIntegration =
  ## Initialize coverage integration for Hourai project
  result = CoverageIntegration(
    projectRoot: projectRoot,
    testSuiteFiles: @[],
    coverageEnabled: false,
    outputDir: ".coverage",
    format: "html",
    threshold: 80.0
  )

proc discoverTestSuites*(integration: var CoverageIntegration) =
  ## Discover test suites in the Hourai project structure
  integration.testSuiteFiles = @[]
  
  # Priority test files for comprehensive coverage
  let priorityFiles = [
    "tests/test_all.nim",
    "tests/test_all_properties.nim",
    "tests/test_integration.nim"
  ]
  
  # Add priority files if they exist
  for file in priorityFiles:
    let fullPath = integration.projectRoot / file
    if fileExists(fullPath):
      integration.testSuiteFiles.add(fullPath)
  
  # Discover domain-specific tests
  let domainDirs = [
    "tests/core/domains",
    "tests/extensions"
  ]
  
  for domainDir in domainDirs:
    let fullDomainPath = integration.projectRoot / domainDir
    if dirExists(fullDomainPath):
      for subdir in walkDirs(fullDomainPath / "*"):
        for testFile in walkFiles(subdir / "test_*.nim"):
          if testFile notin integration.testSuiteFiles:
            integration.testSuiteFiles.add(testFile)
  
  # Add remaining core tests
  let coreTestDirs = [
    "tests/core/common",
    "tests/core/protocol"
  ]
  
  for coreDir in coreTestDirs:
    let fullCorePath = integration.projectRoot / coreDir
    if dirExists(fullCorePath):
      for testFile in walkFiles(fullCorePath / "test_*.nim"):
        if testFile notin integration.testSuiteFiles:
          integration.testSuiteFiles.add(testFile)

proc generateCoverageConfig*(integration: CoverageIntegration): string =
  ## Generate nim.cfg content for coverage
  result = fmt"""
# Coverage configuration for Hourai W9P2025 project
--forceBuild
--define:coverage
--define:testkitCoverage
--lineDir:on
--stackTrace:on
--linetrace:on
--profiler:on
--path:"{integration.projectRoot}/src"
--path:"{integration.projectRoot}/tests"
--outdir:"{integration.projectRoot}/{integration.outputDir}/build"
"""

proc runTestSuiteWithCoverage*(integration: CoverageIntegration, testFile: string): tuple[success: bool, output: string] =
  ## Run a single test suite with coverage enabled
  if not integration.coverageEnabled:
    # Run without coverage
    let cmd = fmt"nim c -r {testFile}"
    let (output, exitCode) = execCmdEx(cmd)
    return (exitCode == 0, output)
  
  # Setup coverage environment
  putEnv("TESTKIT_COVERAGE_ENABLED", "1")
  putEnv("TESTKIT_COVERAGE_OUTPUT", integration.outputDir)
  putEnv("TESTKIT_COVERAGE_FORMAT", integration.format)
  putEnv("TESTKIT_COVERAGE_THRESHOLD", $integration.threshold)
  
  # Create coverage build directory
  let buildDir = integration.projectRoot / integration.outputDir / "build"
  createDir(buildDir)
  
  # Compile with coverage
  let executable = buildDir / testFile.extractFilename().changeFileExt("")
  let compileCmd = fmt"nim c --forceBuild --define:coverage --lineDir:on --stackTrace:on --linetrace:on -o:{executable} {testFile}"
  
  let (compileOutput, compileCode) = execCmdEx(compileCmd)
  if compileCode != 0:
    return (false, fmt"Compilation failed: {compileOutput}")
  
  # Run with coverage
  let (runOutput, runCode) = execCmdEx(executable)
  let fullOutput = compileOutput & "\n" & runOutput
  
  return (runCode == 0, fullOutput)

proc runAllTestsWithCoverage*(integration: var CoverageIntegration): tuple[totalTests: int, passedTests: int, failedTests: seq[string]] =
  ## Run all discovered tests with coverage
  integration.discoverTestSuites()
  
  result = (totalTests: 0, passedTests: 0, failedTests: @[])
  
  echo fmt"🧪 Running {integration.testSuiteFiles.len} test suites with coverage..."
  echo ""
  
  for testFile in integration.testSuiteFiles:
    inc result.totalTests
    let relativeFile = testFile.replace(integration.projectRoot & "/", "")
    
    echo fmt"  Running: {relativeFile}"
    let (success, output) = integration.runTestSuiteWithCoverage(testFile)
    
    if success:
      inc result.passedTests
      echo fmt"    ✓ PASSED"
    else:
      result.failedTests.add(relativeFile)
      echo fmt"    ✗ FAILED"
      # Show first few lines of error
      let errorLines = output.split("\n")[0..min(2, output.split("\n").len-1)]
      for line in errorLines:
        if line.strip().len > 0:
          echo fmt"      {line}"

proc collectCoverageData*(integration: CoverageIntegration): JsonNode =
  ## Collect and organize coverage data
  result = newJObject()
  
  let coverageDir = integration.projectRoot / integration.outputDir
  
  # Look for coverage files
  var coverageFiles: seq[string] = @[]
  
  if dirExists(coverageDir):
    for file in walkFiles(coverageDir / "*.json"):
      coverageFiles.add(file)
    for file in walkFiles(coverageDir / "build/*.json"):
      coverageFiles.add(file)
  
  result["project"] = %integration.projectRoot.extractFilename()
  result["timestamp"] = %($now())
  result["format"] = %integration.format
  result["threshold"] = %integration.threshold
  result["coverageFiles"] = %coverageFiles.len
  
  # If we have coverage data files, process them
  var totalCoverage = 0.0
  var fileCount = 0
  
  for file in coverageFiles:
    try:
      let content = readFile(file)
      let data = parseJson(content)
      if data.hasKey("coverage"):
        totalCoverage += data["coverage"].getFloat()
        inc fileCount
    except:
      continue
  
  if fileCount > 0:
    result["averageCoverage"] = %(totalCoverage / fileCount.float)
  else:
    result["averageCoverage"] = %0.0

proc generateCoverageReport*(integration: CoverageIntegration): string =
  ## Generate a coverage summary report
  let data = integration.collectCoverageData()
  let timestamp = data["timestamp"].getStr()
  let coverage = data["averageCoverage"].getFloat()
  let threshold = integration.threshold
  
  result = fmt"""
# Hourai W9P2025 Coverage Report

**Generated:** {timestamp}
**Project:** {data["project"].getStr()}
**Format:** {integration.format}
**Output Directory:** {integration.outputDir}

## Summary

- **Overall Coverage:** {coverage:.1f}%
- **Threshold:** {threshold:.1f}%
- **Status:** {if coverage >= threshold: "✅ PASSED" else: "❌ BELOW THRESHOLD"}
- **Test Suites:** {integration.testSuiteFiles.len}

## Test Suite Coverage

"""
  
  for i, testFile in integration.testSuiteFiles:
    let relativeFile = testFile.replace(integration.projectRoot & "/", "")
    result.add(fmt"- `{relativeFile}`\n")
  
  result.add(fmt"""

## Coverage Details

Coverage data collected in: `{integration.outputDir}/`

### Domain Coverage Analysis

The Hourai project implements a 9-domain system:

#### 基盤三界 (Foundation Realm)
- **たまゆら (Tamayura)** - Storage Domain
- **ゆうげん (Yugen)** - Compute & Resource Domain  
- **ことづて (Kotozute)** - Network Domain

#### 調和三界 (Harmony Realm)
- **ときわ (Tokiwa)** - Synchronization Domain
- **あかし (Akashi)** - Identity Domain
- **ことわり (Kotowari)** - Consensus Domain

#### 補助三界 (Support Realm)
- **うつし (Utsushi)** - Cache Domain
- **みわたし (Miwatashi)** - Observer Domain
- **みらい (Mirai)** - Extension Framework

Each domain should have comprehensive test coverage including:
- Unit tests for types and APIs
- Property-based tests for invariants
- Integration tests for cross-domain workflows

""")

proc setupCoverageIntegration*(projectRoot: string, enabled: bool, outputDir: string = ".coverage", format: string = "html", threshold: float = 80.0): CoverageIntegration =
  ## Setup coverage integration with the enhanced niuv
  result = initCoverageIntegration(projectRoot)
  result.coverageEnabled = enabled
  result.outputDir = outputDir
  result.format = format
  result.threshold = threshold
  
  # Create output directory
  let fullOutputDir = projectRoot / outputDir
  createDir(fullOutputDir)
  createDir(fullOutputDir / "build")
  createDir(fullOutputDir / "reports")
  
  # Generate nim.cfg for coverage if enabled
  if enabled:
    let configContent = result.generateCoverageConfig()
    writeFile(fullOutputDir / "nim.cfg", configContent)
    echo fmt"✓ Coverage configuration written to {fullOutputDir}/nim.cfg"

# CLI interface for coverage integration
when isMainModule:
  import std/parseopt
  
  var integration: CoverageIntegration
  var projectRoot = getCurrentDir()
  var command = "help"
  
  # Parse command line arguments
  for kind, key, val in getOpt():
    case kind
    of cmdArgument:
      if command == "help":
        command = key
    of cmdLongOption, cmdShortOption:
      case key
      of "project", "p":
        projectRoot = val
      of "output", "o":
        integration.outputDir = val
      of "format", "f":
        integration.format = val
      of "threshold", "t":
        integration.threshold = parseFloat(val)
    of cmdEnd:
      break
  
  case command:
  of "discover":
    integration = initCoverageIntegration(projectRoot)
    integration.discoverTestSuites()
    echo fmt"Discovered {integration.testSuiteFiles.len} test suites:"
    for file in integration.testSuiteFiles:
      echo fmt"  - {file.replace(projectRoot & \"/\", \"\")}"
  
  of "run":
    integration = setupCoverageIntegration(projectRoot, true)
    let results = integration.runAllTestsWithCoverage()
    echo ""
    echo fmt"Test Results: {results.passedTests}/{results.totalTests} passed"
    if results.failedTests.len > 0:
      echo "Failed tests:"
      for failed in results.failedTests:
        echo fmt"  - {failed}"
  
  of "report":
    integration = initCoverageIntegration(projectRoot)
    let report = integration.generateCoverageReport()
    echo report
  
  else:
    echo """
Coverage Integration Tool for Enhanced niuv

Usage:
  nim c -r niuv_coverage_integration.nim [command] [options]

Commands:
  discover    Discover test suites in the project
  run         Run all tests with coverage
  report      Generate coverage report

Options:
  --project, -p <path>     Project root directory (default: current)
  --output, -o <dir>       Coverage output directory (default: .coverage)
  --format, -f <format>    Coverage format (html/json/lcov/text)
  --threshold, -t <num>    Coverage threshold percentage

Examples:
  nim c -r niuv_coverage_integration.nim discover
  nim c -r niuv_coverage_integration.nim run --threshold 85
  nim c -r niuv_coverage_integration.nim report
"""