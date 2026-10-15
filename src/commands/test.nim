## Enhanced test command for niuv with full nim-testkit integration
## Provides comprehensive testing functionality as a nimble replacement

import std/[os, strutils, sequtils, tables, json, terminal]
import ../utils
import ../config
import ../cli
import ../delegation/[base, testkit_adapter]

type
  TestOptions* = object
    ## Test command options
    pattern*: string          # Test file pattern
    verbose*: bool            # Verbose output
    parallel*: bool           # Run tests in parallel
    coverage*: bool           # Generate coverage report
    coverageThreshold*: float # Coverage threshold percentage
    format*: string           # Output format (text, json, junit, tap)
    output*: string           # Output file path
    failFast*: bool           # Stop on first failure
    watch*: bool              # Watch mode for continuous testing
    filter*: string           # Test name filter
    timeout*: int             # Test timeout in seconds
    benchmark*: bool          # Run benchmarks
    generateDocs*: bool       # Generate documentation after tests

proc parseTestOptions*(args: seq[string]): TestOptions =
  ## Parse test command options
  result = TestOptions(
    pattern: "tests/*.nim",
    verbose: false,
    parallel: false,
    coverage: false,
    coverageThreshold: 80.0,
    format: "text",
    output: "",
    failFast: false,
    watch: false,
    filter: "",
    timeout: 300,
    benchmark: false,
    generateDocs: false
  )
  
  var i = 0
  while i < args.len:
    case args[i]
    of "--pattern", "-p":
      inc i
      if i < args.len:
        result.pattern = args[i]
    of "--verbose", "-v":
      result.verbose = true
    of "--parallel":
      result.parallel = true
    of "--coverage", "-c":
      result.coverage = true
    of "--coverage-threshold":
      inc i
      if i < args.len:
        result.coverageThreshold = parseFloat(args[i])
    of "--format", "-f":
      inc i
      if i < args.len:
        result.format = args[i]
    of "--output", "-o":
      inc i
      if i < args.len:
        result.output = args[i]
    of "--fail-fast":
      result.failFast = true
    of "--watch", "-w":
      result.watch = true
    of "--filter":
      inc i
      if i < args.len:
        result.filter = args[i]
    of "--timeout":
      inc i
      if i < args.len:
        result.timeout = parseInt(args[i])
    of "--benchmark", "-b":
      result.benchmark = true
    of "--generate-docs":
      result.generateDocs = true
    else:
      # Assume it's a test file or pattern
      if args[i].endsWith(".nim") or args[i].contains("*"):
        result.pattern = args[i]
    inc i

proc displayTestResults(suites: seq[TestSuite], format: string, verbose: bool) =
  ## Display test results in the specified format
  case format
  of "json":
    let json = %* {
      "suites": suites.mapIt(%* {
        "name": it.name,
        "passed": it.passed,
        "failed": it.failed,
        "skipped": it.skipped,
        "tests": it.tests.mapIt(%* {
          "name": it.name,
          "passed": it.passed,
          "duration": it.duration,
          "error": it.error
        })
      })
    }
    echo json.pretty()
  
  of "junit":
    echo """<?xml version="1.0" encoding="UTF-8"?>"""
    echo "<testsuites>"
    for suite in suites:
      echo "  <testsuite name=\"", suite.name, "\" tests=\"", suite.tests.len, 
           "\" failures=\"", suite.failed, "\" skipped=\"", suite.skipped, "\">"
      for test in suite.tests:
        echo "    <testcase name=\"", test.name, "\" time=\"", test.duration, "\">"
        if not test.passed:
          echo "      <failure message=\"", test.error, "\"/>"
        echo "    </testcase>"
      echo "  </testsuite>"
    echo "</testsuites>"
  
  of "tap":
    var testNum = 1
    for suite in suites:
      for test in suite.tests:
        if test.passed:
          echo "ok ", testNum, " - ", suite.name, "::", test.name
        else:
          echo "not ok ", testNum, " - ", suite.name, "::", test.name
          if test.error != "":
            echo "  ---"
            echo "  message: ", test.error
            echo "  ..."
        inc testNum
  
  else:  # text format
    var totalPassed = 0
    var totalFailed = 0
    var totalSkipped = 0
    
    for suite in suites:
      if verbose or suite.failed > 0:
        echo "\n", suite.name, ":"
        for test in suite.tests:
          if test.passed:
            if verbose:
              styledEcho(fgGreen, "  ✓ ", resetStyle, test.name)
          else:
            styledEcho(fgRed, "  ✗ ", resetStyle, test.name)
            if test.error != "":
              echo "    ", test.error
      
      totalPassed += suite.passed
      totalFailed += suite.failed
      totalSkipped += suite.skipped
    
    # Summary
    echo "\n", "─".repeat(40)
    styledEcho(fgCyan, "Test Summary", resetStyle)
    echo "─".repeat(40)
    
    if totalPassed > 0:
      styledEcho(fgGreen, "✓ Passed: ", resetStyle, $totalPassed)
    if totalFailed > 0:
      styledEcho(fgRed, "✗ Failed: ", resetStyle, $totalFailed)
    if totalSkipped > 0:
      styledEcho(fgYellow, "⊘ Skipped: ", resetStyle, $totalSkipped)
    
    let total = totalPassed + totalFailed + totalSkipped
    if total > 0:
      let percentage = (totalPassed.float / total.float) * 100
      echo "\nSuccess rate: ", formatFloat(percentage, ffDecimal, 1), "%"

proc displayCoverageResults(coverage: seq[CoverageData], threshold: float) =
  ## Display coverage results
  echo "\n", "─".repeat(40)
  styledEcho(fgCyan, "Coverage Report", resetStyle)
  echo "─".repeat(40)
  
  var totalCovered = 0
  var totalLines = 0
  
  for file in coverage:
    let color = if file.percentage >= threshold: fgGreen else: fgRed
    styledEcho(color, formatFloat(file.percentage, ffDecimal, 1), "%", resetStyle, " ", file.file)
    totalCovered += file.linesCovered
    totalLines += file.linesTotal
  
  let totalPercentage = if totalLines > 0: (totalCovered.float / totalLines.float) * 100 else: 0.0
  
  echo "\n", "─".repeat(40)
  let color = if totalPercentage >= threshold: fgGreen else: fgRed
  styledEcho("Total coverage: ", color, formatFloat(totalPercentage, ffDecimal, 1), "%", resetStyle)
  
  if totalPercentage < threshold:
    styledEcho(fgRed, "Coverage below threshold of ", formatFloat(threshold, ffDecimal, 1), "%", resetStyle)

proc runTests*(options: TestOptions): int =
  ## Run tests with nim-testkit integration
  let config = loadDelegationConfig()
  
  # Discover tests
  let discoveryResult = config.discoverTests(getCurrentDir())
  if not discoveryResult.success:
    showError("Failed to discover tests: " & discoveryResult.error)
    return 1
  
  let discovery = discoveryResult.value
  
  if discovery.testFiles.len == 0:
    showWarning("No test files found matching pattern: " & options.pattern)
    return 0
  
  showInfo("Found " & $discovery.testCount & " tests in " & $discovery.testFiles.len & " files")
  
  # Apply pattern filter
  var testFiles = discovery.testFiles
  if options.pattern != "tests/*.nim":
    testFiles = testFiles.filterIt(it.contains(options.pattern))
  
  # Prepare test options
  var testOptions = initTable[string, string]()
  testOptions["format"] = options.format
  if options.parallel:
    testOptions["parallel"] = "true"
  if options.filter != "":
    testOptions["filter"] = options.filter
  if options.timeout > 0:
    testOptions["timeout"] = $options.timeout
  
  # Run tests
  let testResult = config.runTests(testFiles, testOptions)
  if not testResult.success:
    showError("Failed to run tests: " & testResult.error)
    return 1
  
  let suites = testResult.value
  
  # Display results
  displayTestResults(suites, options.format, options.verbose)
  
  # Save to file if requested
  if options.output != "":
    let reportResult = config.generateTestReport(suites, options.format, options.output)
    if reportResult.success:
      showSuccess("Test report saved to: " & reportResult.value)
    else:
      showWarning("Failed to save test report: " & reportResult.error)
  
  # Run coverage if requested
  if options.coverage:
    showInfo("Running coverage analysis...")
    let coverageResult = config.runCoverage(getCurrentDir(), testOptions)
    if coverageResult.success:
      displayCoverageResults(coverageResult.value, options.coverageThreshold)
    else:
      showWarning("Coverage analysis failed: " & coverageResult.error)
  
  # Run benchmarks if requested
  if options.benchmark:
    showInfo("Running benchmarks...")
    let benchmarkFiles = testFiles.filterIt(it.contains("bench") or it.contains("benchmark"))
    if benchmarkFiles.len > 0:
      let benchResult = config.runBenchmarks(benchmarkFiles)
      if benchResult.success:
        echo "\nBenchmark Results:"
        echo benchResult.value.pretty()
      else:
        showWarning("Benchmark failed: " & benchResult.error)
  
  # Generate documentation if requested
  if options.generateDocs:
    showInfo("Generating documentation...")
    let docResult = config.generateDocs(getCurrentDir(), testOptions)
    if docResult.success:
      showSuccess("Documentation generated in: " & docResult.value)
    else:
      showWarning("Documentation generation failed: " & docResult.error)
  
  # Return exit code based on test results
  for suite in suites:
    if suite.failed > 0:
      return 1
  
  return 0

proc testCommand*(args: seq[string]): int =
  ## Main test command entry point
  if "--help" in args or "-h" in args:
    echo """
niuv test - Run tests with nim-testkit integration

Usage:
  niuv test [options] [pattern]

Options:
  --pattern, -p <pattern>    Test file pattern (default: tests/*.nim)
  --verbose, -v              Verbose output
  --parallel                 Run tests in parallel
  --coverage, -c             Generate coverage report
  --coverage-threshold <n>   Coverage threshold percentage (default: 80)
  --format, -f <format>      Output format: text, json, junit, tap (default: text)
  --output, -o <file>        Save report to file
  --fail-fast                Stop on first failure
  --watch, -w                Watch mode for continuous testing
  --filter <pattern>         Filter tests by name
  --timeout <seconds>        Test timeout (default: 300)
  --benchmark, -b            Run benchmarks
  --generate-docs            Generate documentation after tests
  --help, -h                 Show this help

Examples:
  niuv test                          # Run all tests
  niuv test --coverage               # Run with coverage
  niuv test --parallel               # Run tests in parallel
  niuv test --format junit -o test.xml  # Generate JUnit report
  niuv test test_utils.nim           # Run specific test file
  niuv test --watch                  # Watch mode
  niuv test --benchmark              # Run benchmarks

Special Commands:
  niuv test analyze                  # Analyze test organization (MECE)
  niuv test generate                 # Generate test stubs
  niuv test report                   # Generate test report
"""
    return 0
  
  # Handle special subcommands
  if args.len > 0:
    case args[0]
    of "analyze":
      # MECE analysis (requires nim-testkit)
      showInfo("Analyzing test organization...")
      let config = loadDelegationConfig()
      if config.findDelegate(dcTestExecution).isSome:
        discard execShellCmd("nimtestkit --analyze-mece")
      else:
        showError("Test analysis requires nim-testkit")
        return 1
      return 0
    
    of "generate":
      # Test generation (requires nim-testkit)
      showInfo("Generating test stubs...")
      let config = loadDelegationConfig()
      if config.findDelegate(dcTestExecution).isSome:
        discard execShellCmd("nimtestkit --generate")
      else:
        showError("Test generation requires nim-testkit")
        return 1
      return 0
    
    of "report":
      # Generate comprehensive report
      showInfo("Generating test report...")
      var reportArgs = args[1..^1]
      reportArgs.add("--output=test_report.html")
      reportArgs.add("--format=html")
      reportArgs.add("--coverage")
      let options = parseTestOptions(reportArgs)
      return runTests(options)
  
  # Parse options and run tests
  let options = parseTestOptions(args)
  
  # Handle watch mode
  if options.watch:
    showInfo("Starting watch mode... Press Ctrl+C to stop")
    # TODO: Implement file watching
    showWarning("Watch mode not yet implemented")
    return 1
  
  return runTests(options)