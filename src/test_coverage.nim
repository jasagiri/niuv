## Test Coverage Integration Module
## 
## Integrates coverage collection with the test framework

import std/[os, strutils, sequtils, tables, json, times, osproc, strformat, algorithm]
import ./coverage
import ./config
import ./utils
import ./tools/report/test_report

type
  TestCoverageRunner* = object
    config*: Config
    coverageConfig*: CoverageConfig
    testResults*: seq[TestCase]
    coverageReport*: CoverageReport

proc initTestCoverageRunner*(config: Config): TestCoverageRunner =
  ## Initialize a test coverage runner
  result = TestCoverageRunner(
    config: config,
    coverageConfig: loadCoverageConfig(config),
    testResults: @[]
  )

proc runTestWithCoverage*(runner: var TestCoverageRunner, testFile: string): TestCase =
  ## Run a single test with coverage enabled
  let coverageEnabled = runner.coverageConfig.enabled
  
  if coverageEnabled:
    # Compile with coverage instrumentation
    let (compileOut, compileCode) = compileCoverageEnabled(testFile, runner.coverageConfig)
    
    if compileCode != 0:
      return TestCase(
        name: testFile.extractFilename(),
        result: tFail,
        message: fmt"Compilation failed: {compileOut}",
        duration: 0.0,
        suite: "",
        file: testFile,
        line: 0
      )
    
    # Run the test
    let executable = runner.coverageConfig.outputDir / "build" / testFile.extractFilename().changeFileExt("")
    let startTime = epochTime()
    let (output, exitCode) = runWithCoverage(executable, runner.coverageConfig)
    let duration = epochTime() - startTime
    
    result = TestCase(
      name: testFile.extractFilename(),
      result: if exitCode == 0: tPass else: tFail,
      message: if exitCode != 0: output else: "",
      duration: duration,
      suite: "",
      file: testFile,
      line: 0
    )
  else:
    # Run without coverage
    let startTime = epochTime()
    let cmd = fmt"nim c -r {testFile}"
    let (output, exitCode) = execCmdEx(cmd)
    let duration = epochTime() - startTime
    
    result = TestCase(
      name: testFile.extractFilename(),
      result: if exitCode == 0: tPass else: tFail,
      message: if exitCode != 0: output else: "",
      duration: duration,
      suite: "",
      file: testFile,
      line: 0
    )

proc runTestSuite*(runner: var TestCoverageRunner, pattern: string = "tests/test_*.nim"): int =
  ## Run a test suite with coverage collection
  var testFiles: seq[string] = @[]
  
  # Collect test files
  for file in walkFiles(pattern):
    testFiles.add(file)
    
  if testFiles.len == 0:
    utils.logError(fmt"No test files found matching pattern: {pattern}")
    return 1
    
  echo fmt"[INFO] Running {testFiles.len} tests with coverage..."
  
  # Run each test
  for testFile in testFiles:
    let testResult = runner.runTestWithCoverage(testFile)
    runner.testResults.add(testResult)
    
    if testResult.result == tPass:
      echo fmt"  ✓ {testResult.name}"
    else:
      echo fmt"  ✗ {testResult.name}"
      if testResult.message.len > 0:
        echo "    ", testResult.message.replace("\n", "\n    ")
  
  # Collect coverage data if enabled
  if runner.coverageConfig.enabled:
    runner.coverageReport = collectCoverageData(runner.coverageConfig, testFiles)
    
    # Generate reports
    for format in runner.coverageConfig.formats:
      let filename = case format
        of cfLcov: "coverage.info"
        of cfHtml: "index.html"
        of cfJson: "coverage.json"
        of cfText: "coverage.txt"
        
      let outputPath = runner.coverageConfig.outputDir / filename
      generateReport(runner.coverageReport, format, outputPath)
  
  # Summary
  let passed = runner.testResults.filterIt(it.result == tPass).len
  let failed = runner.testResults.filterIt(it.result == tFail).len
  let totalDuration = runner.testResults.mapIt(it.duration).foldl(a + b, 0.0)
  
  echo ""
  echo "Test Summary"
  echo fmt"  Passed: {passed}"
  if failed > 0:
    echo fmt"  Failed: {failed}"
  echo fmt"  Total:  {runner.testResults.len}"
  echo fmt"  Time:   {totalDuration:.2f}s"
  
  if runner.coverageConfig.enabled:
    echo ""
    echo "Coverage Summary"
    echo fmt"  Total Coverage: {runner.coverageReport.totalCoverage:.1f}%"
    echo fmt"  Files Analyzed: {runner.coverageReport.files.len}"
    
    # Check threshold
    if not checkCoverageThreshold(runner.coverageReport, runner.coverageConfig.threshold):
      return 1
  
  return if failed > 0: 1 else: 0

proc generateCoverageMatrix*(runner: TestCoverageRunner): Table[string, Table[string, bool]] =
  ## Generate a coverage matrix showing which tests cover which source files
  result = initTable[string, Table[string, bool]]()
  
  # This would require more sophisticated tracking of which test covers which source
  # For now, return empty matrix
  discard

proc generateCoverageTrends*(history: seq[CoverageReport]): JsonNode =
  ## Generate coverage trend data from historical reports
  result = newJArray()
  
  for report in history:
    result.add(%*{
      "timestamp": $report.timestamp,
      "coverage": report.totalCoverage,
      "files": report.files.len
    })

proc exportCoverageData*(runner: TestCoverageRunner, format: string): string =
  ## Export coverage data in various formats for external tools
  case format.toLowerAscii()
  of "cobertura":
    # Generate Cobertura XML format
    result = """<?xml version="1.0" encoding="UTF-8"?>
<coverage version="1">
  <sources>
    <source>""" & runner.coverageReport.projectRoot & """</source>
  </sources>
  <packages>
"""
    
    for file in runner.coverageReport.files:
      let coverage = if file.totalLines > 0:
        (file.coveredLines.float / file.totalLines.float)
      else:
        0.0
        
      result &= fmt"""    <package name="{file.file.extractFilename()}" line-rate="{coverage:.2f}">
      <classes>
        <class name="{file.file.extractFilename()}" filename="{file.file}" line-rate="{coverage:.2f}">
          <lines>
"""
      
      for lineNum, hits in file.lineHits:
        result &= fmt"""            <line number="{lineNum}" hits="{hits}"/>
"""
      
      result &= """          </lines>
        </class>
      </classes>
    </package>
"""
    
    result &= """  </packages>
</coverage>
"""
    
  of "sonarqube":
    # Generate SonarQube generic coverage format
    let data = %*{
      "version": "1",
      "coverageFiles": runner.coverageReport.files.mapIt((block:
        let filePath = it.file.replace(runner.coverageReport.projectRoot & "/", "")
        let lineData = block:
          var lines: seq[JsonNode] = @[]
          var sortedLineNums: seq[int] = @[]
          for lineNum in it.lineHits.keys:
            sortedLineNums.add(lineNum)
          sortedLineNums.sort()
          for lineNum in sortedLineNums:
            let hits = it.lineHits[lineNum]
            lines.add(%*{"lineNumber": lineNum, "covered": hits > 0})
          lines
        %*{
          "path": filePath,
          "lineCoverage": lineData
        }
      ))
    }
    result = data.pretty()
    
  else:
    result = ""

# Command-line interface
proc testWithCoverage*(args: seq[string]): int =
  ## Run tests with coverage from command line
  var config = loadConfig()
  # Force coverage to be enabled when using the coverage subcommand
  config.setConfigValue("coverage.enabled", "true")
  
  var runner = initTestCoverageRunner(config)
  
  var pattern = "tests/test_*.nim"
  var exportFormat = ""
  
  # Parse arguments
  var i = 0
  while i < args.len:
    case args[i]
    of "--pattern", "-p":
      if i + 1 < args.len:
        pattern = args[i + 1]
        inc i
    of "--export", "-e":
      if i + 1 < args.len:
        exportFormat = args[i + 1]
        inc i
    of "--help", "-h":
      echo "Usage: niuv test coverage [options] [test_files...]"
      echo ""
      echo "Options:"
      echo "  --pattern, -p <pattern>  Test file pattern (default: tests/test_*.nim)"
      echo "  --export, -e <format>    Export format (cobertura, sonarqube)"
      echo "  --help, -h               Show this help"
      echo ""
      echo "Examples:"
      echo "  niuv test coverage                    # Run all tests with coverage"
      echo "  niuv test coverage tests/test_*.nim   # Run matching tests"
      echo "  niuv test coverage test_config.nim    # Run specific test"
      return 0
    else:
      if args[i].endsWith(".nim"):
        pattern = args[i]
    inc i
  
  # Run tests
  result = runner.runTestSuite(pattern)
  
  # Export if requested
  if exportFormat.len > 0:
    let exportData = runner.exportCoverageData(exportFormat)
    if exportData.len > 0:
      let filename = fmt"coverage.{exportFormat}.xml"
      writeFile(runner.coverageConfig.outputDir / filename, exportData)
      utils.logInfo(fmt"Exported coverage data to: {runner.coverageConfig.outputDir / filename}")
    else:
      utils.logError(fmt"Unknown export format: {exportFormat}")
      result = 1