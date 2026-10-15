## Automatic test discovery and execution for niuv
## Eliminates the need for manual test_all.nim files

import std/[os, strutils, sequtils, tables, times, terminal, algorithm, json]
import std/[osproc, parsecfg, strformat, sets]
import ../config/types
import ../utils/[logger, process]

type
  TestPattern = object
    pattern: string
    category: string
    
  TestFile = object
    path: string
    category: string
    size: BiggestInt
    
  TestResult = object
    file: string
    category: string
    passed: bool
    duration: float
    output: string
    exitCode: int
    
  TestRunnerConfig = object
    patterns: seq[string]
    exclude: seq[string]
    categories: Table[string, seq[string]]
    parallel: bool
    coverage: bool
    verbose: bool
    failfast: bool
    timeout: int
    workers: int

const
  DefaultPatterns = @[
    "tests/test_*.nim",
    "tests/*_test.nim",
    "test/test_*.nim",
    "test/*_test.nim"
  ]
  
  DefaultExclude = @[
    "nimcache",
    ".nimble",
    "node_modules",
    "vendor",
    "build",
    "dist",
    ".*"  # Hidden directories
  ]
  
  CategoryPatterns = {
    "unit": @["*_unit_test.nim", "test_unit_*.nim", "unit/test_*.nim"],
    "integration": @["*_integration_test.nim", "test_integration_*.nim", "integration/test_*.nim"],
    "e2e": @["*_e2e_test.nim", "test_e2e_*.nim", "e2e/test_*.nim"],
    "benchmark": @["*_benchmark.nim", "test_benchmark_*.nim", "benchmark/test_*.nim"],
    "property": @["*_property_test.nim", "test_property_*.nim", "property/test_*.nim"]
  }.toTable()

proc loadTestConfig(projectPath: string): TestRunnerConfig =
  ## Load test configuration from niuv.toml
  result = TestRunnerConfig(
    patterns: DefaultPatterns,
    exclude: DefaultExclude,
    categories: CategoryPatterns,
    parallel: true,
    coverage: false,
    verbose: false,
    failfast: false,
    timeout: 300,
    workers: countProcessors() - 1
  )
  
  let configPath = projectPath / "niuv.toml"
  if fileExists(configPath):
    # Parse niuv.toml for testing section
    # TODO: Implement TOML parsing
    discard

proc matchesPattern(file: string, pattern: string): bool =
  ## Check if file matches glob pattern
  # Simple implementation - in production use proper glob matching
  if pattern.contains("**"):
    let simplePattern = pattern.replace("**/", "").replace("**", "*")
    return file.contains(simplePattern.replace("*", ""))
  elif pattern.contains("*"):
    let parts = pattern.split("*")
    if parts.len == 2:
      return file.startsWith(parts[0]) and file.endsWith(parts[1])
  else:
    return file == pattern

proc isExcluded(path: string, excludePatterns: seq[string]): bool =
  ## Check if path should be excluded
  for pattern in excludePatterns:
    for part in path.split(DirSep):
      if part.matchesPattern(pattern):
        return true
  return false

proc categorizeTest(path: string, categories: Table[string, seq[string]]): string =
  ## Determine test category based on filename
  for category, patterns in categories:
    for pattern in patterns:
      if path.extractFilename.matchesPattern(pattern):
        return category
  return "general"

proc discoverTests(dir: string, config: TestRunnerConfig): seq[TestFile] =
  ## Discover all test files based on patterns
  result = @[]
  var seen = initHashSet[string]()
  
  for pattern in config.patterns:
    # Handle recursive patterns
    let recursive = pattern.contains("**/")
    let searchDir = if pattern.startsWith("**/"): dir else: dir
    
    for file in walkFiles(searchDir / pattern):
      let normalizedPath = file.normalizedPath
      if normalizedPath notin seen and not isExcluded(normalizedPath, config.exclude):
        seen.incl(normalizedPath)
        result.add(TestFile(
          path: normalizedPath,
          category: categorizeTest(normalizedPath, config.categories),
          size: getFileSize(normalizedPath)
        ))
    
    # Handle recursive search
    if recursive:
      for subdir in walkDirs(searchDir / "*"):
        if not isExcluded(subdir, config.exclude):
          let subTests = discoverTests(subdir, config)
          for test in subTests:
            if test.path notin seen:
              seen.incl(test.path)
              result.add(test)
  
  # Sort by category and size for better parallel distribution
  result.sort do (a, b: TestFile) -> int:
    if a.category != b.category:
      return cmp(a.category, b.category)
    return cmp(b.size, a.size)  # Larger files first

proc compileTest(test: TestFile, config: TestRunnerConfig): TestResult =
  ## Compile a single test file
  let startTime = epochTime()
  var args = @["c"]
  
  if config.coverage:
    args.add(@["-d:testing", "--passC:--coverage", "--passL:--coverage"])
  
  args.add(test.path)
  
  let (output, exitCode) = execCmdEx("nim " & args.join(" "))
  
  result = TestResult(
    file: test.path,
    category: test.category,
    passed: exitCode == 0,
    duration: epochTime() - startTime,
    output: output,
    exitCode: exitCode
  )

proc runTest(test: TestFile, config: TestRunnerConfig): TestResult =
  ## Compile and run a single test
  result = compileTest(test, config)
  
  if result.passed:
    # Run the compiled test
    let exe = test.path.changeFileExt(ExeExt)
    let startTime = epochTime()
    
    let process = startProcess(exe, options = {poStdErrToStdOut})
    let exitCode = process.waitForExit(config.timeout * 1000)
    
    if exitCode == -1:
      # Timeout
      process.terminate()
      result.passed = false
      result.output &= "\n⏱️ Test timed out after " & $config.timeout & " seconds"
      result.exitCode = -1
    else:
      result.passed = exitCode == 0
      result.exitCode = exitCode
      result.output &= process.outputStream.readAll()
    
    result.duration = epochTime() - startTime
    process.close()
    
    # Clean up executable
    if not config.coverage:
      removeFile(exe)

proc runTestsSequential(tests: seq[TestFile], config: TestRunnerConfig): seq[TestResult] =
  ## Run tests sequentially
  result = @[]
  
  for i, test in tests:
    if config.verbose:
      echo &"[{i+1}/{tests.len}] Running {test.path}..."
    else:
      stdout.write(&"\r🧪 Running tests... {i+1}/{tests.len}")
      stdout.flushFile()
    
    let testResult = runTest(test, config)
    result.add(testResult)
    
    if config.verbose:
      if testResult.passed:
        echo &"  ✅ Passed ({testResult.duration:.2f}s)"
      else:
        echo &"  ❌ Failed (exit code: {testResult.exitCode})"
        if testResult.output.len > 0:
          echo indent(testResult.output, 4)
    
    if not testResult.passed and config.failfast:
      if not config.verbose:
        echo ""  # New line after progress
      echo "❌ Stopping due to test failure (--failfast)"
      break
  
  if not config.verbose:
    echo ""  # New line after progress

proc runTestsParallel(tests: seq[TestFile], config: TestRunnerConfig): seq[TestResult] =
  ## Run tests in parallel using process pool
  # Simplified implementation - in production use proper thread pool
  echo &"🧪 Running {tests.len} tests with {config.workers} workers..."
  
  var results = newSeq[TestResult](tests.len)
  var completed = 0
  
  # Simple parallel execution using processes
  var running = newSeq[Process]()
  var testIndex = 0
  
  while completed < tests.len:
    # Start new processes up to worker limit
    while running.len < config.workers and testIndex < tests.len:
      let test = tests[testIndex]
      let process = startProcess("nim", args = ["c", "-r", test.path],
                               options = {poStdErrToStdOut})
      running.add(process)
      inc testIndex
    
    # Check for completed processes
    for i in countdown(running.high, 0):
      if not running[i].running:
        let exitCode = running[i].peekExitCode
        results[completed] = TestResult(
          file: tests[completed].path,
          category: tests[completed].category,
          passed: exitCode == 0,
          exitCode: exitCode,
          output: running[i].outputStream.readAll()
        )
        running[i].close()
        running.delete(i)
        inc completed
        
        stdout.write(&"\r🧪 Progress: {completed}/{tests.len}")
        stdout.flushFile()
    
    sleep(100)  # Small delay to prevent CPU spinning
  
  echo ""  # New line after progress
  return results

proc printTestSummary(results: seq[TestResult], totalTime: float) =
  ## Print test execution summary
  let passed = results.filterIt(it.passed).len
  let failed = results.len - passed
  
  echo "\n📊 Test Summary"
  echo "==============="
  
  # Group by category
  var categoryStats = initTable[string, tuple[passed, failed: int]]()
  for result in results:
    if result.category notin categoryStats:
      categoryStats[result.category] = (0, 0)
    
    if result.passed:
      categoryStats[result.category].passed.inc
    else:
      categoryStats[result.category].failed.inc
  
  # Print category breakdown
  for category, stats in categoryStats:
    let total = stats.passed + stats.failed
    let percentage = if total > 0: (stats.passed * 100) div total else: 0
    echo &"  {category}: {stats.passed}/{total} ({percentage}%)"
  
  echo ""
  
  # Print failed tests
  if failed > 0:
    echo "❌ Failed Tests:"
    for result in results:
      if not result.passed:
        echo &"  - {result.file} (exit code: {result.exitCode})"
  
  # Overall summary
  echo ""
  if failed == 0:
    echo &"✅ All {passed} tests passed! 🎉"
  else:
    echo &"❌ {failed} of {results.len} tests failed"
  
  echo &"⏱️  Total time: {totalTime:.2f}s"

proc generateCoverageReport(projectPath: string) =
  ## Generate coverage report from gcov data
  echo "\n📊 Generating coverage report..."
  
  let coverageDir = projectPath / ".coverage"
  createDir(coverageDir)
  
  # Run gcov
  let (gcovOutput, gcovExit) = execCmdEx("gcov -b -c *.gcda")
  if gcovExit == 0:
    echo "  ✅ Coverage data collected"
    
    # Generate HTML report if lcov is available
    let (_, lcovCheck) = execCmdEx("which lcov")
    if lcovCheck == 0:
      discard execCmdEx(&"lcov --capture --directory . --output-file {coverageDir}/coverage.info")
      discard execCmdEx(&"genhtml {coverageDir}/coverage.info --output-directory {coverageDir}/html")
      echo &"  📄 HTML report: {coverageDir}/html/index.html"
  else:
    echo "  ⚠️  Could not generate coverage data"

proc runTestCommand*(args: seq[string]): int =
  ## Execute niuv test command (single test or pattern)
  let projectPath = getCurrentDir()
  var config = loadTestConfig(projectPath)
  
  # Parse command line options
  var patterns: seq[string] = @[]
  var i = 0
  
  while i < args.len:
    case args[i]
    of "--coverage", "-c":
      config.coverage = true
    of "--verbose", "-v":
      config.verbose = true
    of "--parallel", "-p":
      config.parallel = true
    of "--failfast", "-f":
      config.failfast = true
    of "--timeout":
      if i + 1 < args.len:
        config.timeout = parseInt(args[i + 1])
        inc i
    else:
      if not args[i].startsWith("-"):
        patterns.add(args[i])
    inc i
  
  # If specific patterns provided, use them
  if patterns.len > 0:
    config.patterns = patterns
  
  # Discover tests
  let tests = discoverTests(projectPath, config)
  
  if tests.len == 0:
    echo "⚠️  No tests found"
    echo "    Searched patterns: " & config.patterns.join(", ")
    echo ""
    echo "    To create a test:"
    echo "    1. Create a tests/ directory"
    echo "    2. Add test files matching the pattern"
    echo "    3. Or specify custom patterns in niuv.toml"
    return 1
  
  echo &"🧪 Discovered {tests.len} test(s)"
  
  # Run tests
  let startTime = epochTime()
  let results = if config.parallel and tests.len > 1:
    runTestsParallel(tests, config)
  else:
    runTestsSequential(tests, config)
  
  let totalTime = epochTime() - startTime
  
  # Print summary
  printTestSummary(results, totalTime)
  
  # Generate coverage if requested
  if config.coverage:
    generateCoverageReport(projectPath)
  
  # Return exit code
  return if results.allIt(it.passed): 0 else: 1

proc runTestsCommand*(args: seq[string]): int =
  ## Execute niuv tests command (all tests with auto-discovery)
  # Same as test command but with recursive search by default
  var modifiedArgs = args
  
  # If no patterns specified, use recursive search
  var hasPattern = false
  for arg in args:
    if not arg.startsWith("-"):
      hasPattern = true
      break
  
  if not hasPattern:
    # Add recursive patterns
    modifiedArgs.add("tests/**/test_*.nim")
    modifiedArgs.add("tests/**/*_test.nim")
  
  return runTestCommand(modifiedArgs)

proc listTests*(args: seq[string]): int =
  ## List all discovered tests without running them
  let projectPath = getCurrentDir()
  let config = loadTestConfig(projectPath)
  
  let tests = discoverTests(projectPath, config)
  
  if tests.len == 0:
    echo "No tests found"
    return 1
  
  echo &"Found {tests.len} test(s):"
  echo ""
  
  # Group by category
  var byCategory = initTable[string, seq[TestFile]]()
  for test in tests:
    if test.category notin byCategory:
      byCategory[test.category] = @[]
    byCategory[test.category].add(test)
  
  # Print by category
  for category in byCategory.keys.toSeq.sorted:
    echo &"[{category}]"
    for test in byCategory[category]:
      echo &"  {test.path}"
    echo ""
  
  return 0