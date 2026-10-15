## nim-testkit adapter for niuv
## Provides seamless integration with nim-testkit for testing functionality

import std/[os, osproc, strutils, sequtils, json, tables]
import base
import ../utils

type
  TestResult* = object
    name*: string
    passed*: bool
    duration*: float
    error*: string
    
  TestSuite* = object
    name*: string
    tests*: seq[TestResult]
    passed*: int
    failed*: int
    skipped*: int
    
  CoverageData* = object
    file*: string
    linesCovered*: int
    linesTotal*: int
    percentage*: float
    
  TestDiscoveryResult* = object
    testFiles*: seq[string]
    testCount*: int
    suites*: seq[string]

proc parseTestKitOutput(output: string): seq[TestSuite] =
  ## Parse nim-testkit output into structured results
  result = @[]
  var currentSuite: TestSuite
  var inSuite = false
  
  for line in output.splitLines():
    if line.startsWith("suite "):
      if inSuite and currentSuite.tests.len > 0:
        result.add(currentSuite)
      currentSuite = TestSuite(name: line[6..^1].strip(chars = {'"'}))
      inSuite = true
    elif line.contains("✓") or line.contains("✗"):
      if inSuite:
        let passed = line.contains("✓")
        let testName = line.split(if passed: "✓" else: "✗")[1].strip()
        currentSuite.tests.add(TestResult(
          name: testName,
          passed: passed
        ))
        if passed:
          inc currentSuite.passed
        else:
          inc currentSuite.failed
  
  if inSuite and currentSuite.tests.len > 0:
    result.add(currentSuite)

proc discoverTests*(config: DelegationConfig, projectPath: string): DelegateResult[TestDiscoveryResult] =
  ## Discover tests using nim-testkit
  config.delegateOr(dcTestDiscovery):
    # Delegate to nim-testkit
    let args = @["--discover", "--json", projectPath]
    result = delegate.executeDelegate(args, proc(output: string): TestDiscoveryResult =
      let json = parseJson(output)
      result.testFiles = @[]
      result.testCount = 0
      result.suites = @[]
      
      for file in json["files"]:
        result.testFiles.add(file["path"].getStr)
        result.testCount += file["tests"].getInt
        for suite in file["suites"]:
          result.suites.add(suite.getStr)
    )
  do:
    # Fallback: Simple file discovery
    var discovery = TestDiscoveryResult()
    for file in walkFiles(projectPath / "tests" / "*.nim"):
      discovery.testFiles.add(file)
    discovery.testCount = discovery.testFiles.len
    result = DelegateResult[TestDiscoveryResult](
      success: true,
      value: discovery,
      usedDelegate: "native"
    )

proc runTests*(config: DelegationConfig, testFiles: seq[string], options: Table[string, string] = initTable[string, string]()): DelegateResult[seq[TestSuite]] =
  ## Run tests using nim-testkit
  config.delegateOr(dcTestExecution):
    # Build nim-testkit arguments
    var args = @["--run"]
    
    # Add format option
    if "format" in options:
      args.add("--format=" & options["format"])
    
    # Add parallel option
    if "parallel" in options and options["parallel"] == "true":
      args.add("--parallel")
    
    # Add test files
    args.add(testFiles)
    
    result = delegate.executeDelegate(args, parseTestKitOutput)
  do:
    # Fallback: Run tests with nim directly
    var suites: seq[TestSuite] = @[]
    for testFile in testFiles:
      let (output, exitCode) = execCmdEx(utils.getNimCommand() & " c -r " & testFile)
      let suite = TestSuite(
        name: testFile.extractFilename,
        passed: if exitCode == 0: 1 else: 0,
        failed: if exitCode == 0: 0 else: 1
      )
      suites.add(suite)
    
    result = DelegateResult[seq[TestSuite]](
      success: true,
      value: suites,
      usedDelegate: "native"
    )

proc runCoverage*(config: DelegationConfig, projectPath: string, options: Table[string, string] = initTable[string, string]()): DelegateResult[seq[CoverageData]] =
  ## Run coverage analysis using nim-testkit
  config.delegateOr(dcCoverageAnalysis):
    var args = @["--coverage"]
    
    # Add format option
    if "format" in options:
      args.add("--coverage-format=" & options["format"])
    
    # Add threshold option
    if "threshold" in options:
      args.add("--coverage-threshold=" & options["threshold"])
    
    args.add(projectPath)
    
    result = delegate.executeDelegate(args, proc(output: string): seq[CoverageData] =
      result = @[]
      let json = parseJson(output)
      for file in json["files"]:
        result.add(CoverageData(
          file: file["path"].getStr,
          linesCovered: file["covered"].getInt,
          linesTotal: file["total"].getInt,
          percentage: file["percentage"].getFloat
        ))
    )
  do:
    # Fallback: No coverage without nim-testkit
    result = DelegateResult[seq[CoverageData]](
      success: false,
      error: "Coverage analysis requires nim-testkit",
      usedDelegate: "none"
    )

proc generateTestReport*(config: DelegationConfig, suites: seq[TestSuite], format: string, outputPath: string): DelegateResult[string] =
  ## Generate test report using nim-testkit formatters
  let delegated = config.tryDelegate(dcTestExecution):
    # Use nim-testkit's report generation
    let args = @["--report", "--format=" & format, "--output=" & outputPath]
    result = delegate.executeDelegate(args, proc(output: string): string = outputPath)
  
  if not delegated:
    # Fallback: Generate simple report
    var report = ""
    var totalPassed = 0
    var totalFailed = 0
    
    for suite in suites:
      report.add("Suite: " & suite.name & "\n")
      report.add("  Passed: " & $suite.passed & "\n")
      report.add("  Failed: " & $suite.failed & "\n")
      totalPassed += suite.passed
      totalFailed += suite.failed
    
    report.add("\nTotal: " & $(totalPassed + totalFailed) & " tests\n")
    report.add("Passed: " & $totalPassed & "\n")
    report.add("Failed: " & $totalFailed & "\n")
    
    writeFile(outputPath, report)
    result = DelegateResult[string](
      success: true,
      value: outputPath,
      usedDelegate: "native"
    )

proc runBenchmarks*(config: DelegationConfig, benchmarkFiles: seq[string]): DelegateResult[JsonNode] =
  ## Run benchmarks using nim-testkit
  config.delegateOr(dcBenchmarking):
    let args = @["--benchmark"] & benchmarkFiles
    result = delegate.executeDelegate(args, proc(output: string): JsonNode = parseJson(output))
  do:
    # Fallback: Simple timing
    result = DelegateResult[JsonNode](
      success: false,
      error: "Benchmarking requires nim-testkit",
      usedDelegate: "none"
    )

proc generateDocs*(config: DelegationConfig, projectPath: string, options: Table[string, string] = initTable[string, string]()): DelegateResult[string] =
  ## Generate documentation using nim-testkit
  config.delegateOr(dcDocGeneration):
    var args = @["--generate-docs"]
    
    if "format" in options:
      args.add("--doc-format=" & options["format"])
    
    args.add(projectPath)
    
    result = delegate.executeDelegate(args, proc(output: string): string =
      # Extract output path from nim-testkit output
      for line in output.splitLines():
        if line.contains("Documentation generated"):
          return line.split("in")[1].strip()
      return "build/docs"
    )
  do:
    # Fallback: Use nim doc
    let (output, exitCode) = execCmdEx(utils.getNimCommand() & " doc --project " & projectPath)
    result = DelegateResult[string](
      success: exitCode == 0,
      value: if exitCode == 0: "htmldocs" else: "",
      error: if exitCode != 0: output else: "",
      usedDelegate: "nim doc"
    )