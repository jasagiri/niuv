#!/usr/bin/env nim
## Performance Benchmarking Suite for Enhanced niuv
## 
## Measures and reports performance metrics for various operations
## including test execution, configuration loading, and parallel processing

import std/[os, times, strutils, strformat, sequtils, tables, json, algorithm, math]

type
  BenchmarkResult = object
    name: string
    duration: float
    iterations: int
    averageDuration: float
    minDuration: float
    maxDuration: float
    memoryUsage: int
    metadata: Table[string, string]

  BenchmarkSuite = object
    results: seq[BenchmarkResult]
    timestamp: string
    systemInfo: Table[string, string]

var benchmarkSuite = BenchmarkSuite(
  results: @[],
  timestamp: $now(),
  systemInfo: initTable[string, string]()
)

proc logInfo(msg: string) =
  echo fmt"[INFO] {msg}"

proc logBenchmark(msg: string) =
  echo fmt"[BENCH] {msg}"

proc collectSystemInfo() =
  ## Collect system information for benchmark context
  try:
    # Get Nim version
    let (nimVersion, _) = execCmdEx("nim --version")
    benchmarkSuite.systemInfo["nim_version"] = nimVersion.split("\n")[0]
    
    # Get OS information
    benchmarkSuite.systemInfo["os"] = hostOS
    benchmarkSuite.systemInfo["cpu"] = hostCPU
    
    # Get CPU count
    when defined(linux):
      let (cpuCount, _) = execCmdEx("nproc")
      benchmarkSuite.systemInfo["cpu_cores"] = cpuCount.strip()
    elif defined(macosx):
      let (cpuCount, _) = execCmdEx("sysctl -n hw.ncpu")
      benchmarkSuite.systemInfo["cpu_cores"] = cpuCount.strip()
    
    # Get memory information
    when defined(linux):
      let (memInfo, _) = execCmdEx("free -m | grep '^Mem:' | awk '{print $2}'")
      benchmarkSuite.systemInfo["total_memory_mb"] = memInfo.strip()
    elif defined(macosx):
      let (memInfo, _) = execCmdEx("sysctl -n hw.memsize")
      try:
        let memBytes = parseInt(memInfo.strip())
        benchmarkSuite.systemInfo["total_memory_mb"] = $(memBytes div (1024 * 1024))
      except:
        discard
    
  except:
    logInfo("Could not collect complete system information")

proc measureMemoryUsage(): int =
  ## Estimate current memory usage (simplified)
  try:
    when defined(linux):
      let (usage, _) = execCmdEx("ps -o rss= -p " & $getCurrentProcessId())
      return parseInt(usage.strip())
    elif defined(macosx):
      let (usage, _) = execCmdEx("ps -o rss= -p " & $getCurrentProcessId())
      return parseInt(usage.strip())
    else:
      return 0
  except:
    return 0

proc runBenchmark(name: string, iterations: int, benchmarkProc: proc()): BenchmarkResult =
  ## Run a benchmark with multiple iterations and collect statistics
  logBenchmark fmt"Running benchmark: {name} ({iterations} iterations)"
  
  var durations: seq[float] = @[]
  let memoryBefore = measureMemoryUsage()
  
  # Warmup iteration
  benchmarkProc()
  
  # Actual benchmark iterations
  for i in 1..iterations:
    let startTime = epochTime()
    benchmarkProc()
    let duration = epochTime() - startTime
    durations.add(duration)
    
    if i mod max(1, iterations div 10) == 0:
      echo fmt"  Progress: {i}/{iterations} iterations"
  
  let memoryAfter = measureMemoryUsage()
  
  # Calculate statistics
  durations.sort()
  let totalDuration = durations.foldl(a + b, 0.0)
  let averageDuration = totalDuration / durations.len.float
  let minDuration = durations[0]
  let maxDuration = durations[^1]
  
  result = BenchmarkResult(
    name: name,
    duration: totalDuration,
    iterations: iterations,
    averageDuration: averageDuration,
    minDuration: minDuration,
    maxDuration: maxDuration,
    memoryUsage: memoryAfter - memoryBefore,
    metadata: initTable[string, string]()
  )
  
  logBenchmark fmt"Completed: {name} - Avg: {averageDuration*1000:.2f}ms, Min: {minDuration*1000:.2f}ms, Max: {maxDuration*1000:.2f}ms"
  benchmarkSuite.results.add(result)

# Benchmark implementations

proc benchmarkBinaryStartup() =
  ## Benchmark binary startup time
  discard execCmdEx("./.build/niuv-enhanced --help")

proc benchmarkConfigLoading() =
  ## Benchmark configuration loading
  discard execCmdEx("./.build/niuv-enhanced validate-config")

proc benchmarkTestDiscovery() =
  ## Benchmark test discovery process
  discard execCmdEx("timeout 5 ./.build/niuv-enhanced test-all || true")

proc benchmarkSimpleTest() =
  ## Benchmark running a simple test
  if fileExists("tests/test_simple.nim"):
    discard execCmdEx("./.build/niuv-enhanced test tests/test_simple.nim")

proc benchmarkParallelTests() =
  ## Benchmark parallel test execution
  if dirExists("tests/core/common"):
    discard execCmdEx("./.build/niuv-enhanced test tests/core/common/test_*.nim")

proc benchmarkCoverageTest() =
  ## Benchmark test with coverage enabled
  if fileExists("tests/test_simple.nim"):
    putEnv("TESTKIT_COVERAGE_ENABLED", "1")
    discard execCmdEx("./.build/niuv-enhanced test tests/test_simple.nim")
    delEnv("TESTKIT_COVERAGE_ENABLED")

proc benchmarkNoCoverageTest() =
  ## Benchmark test with coverage disabled
  if fileExists("tests/test_simple.nim"):
    discard execCmdEx("./.build/niuv-enhanced test --no-coverage tests/test_simple.nim")

proc benchmarkShellCompletion() =
  ## Benchmark shell completion functionality
  putEnv("COMP_WORDS", "niuv-enhanced test ")
  putEnv("COMP_CWORD", "2")
  discard execCmdEx("bash niuv-enhanced-completion.bash")
  delEnv("COMP_WORDS")
  delEnv("COMP_CWORD")

# Parallel processing benchmarks

proc benchmarkParallelJobsComparison() =
  ## Compare performance with different parallel job settings
  logInfo("Benchmarking parallel jobs performance...")
  
  let jobCounts = [1, 2, 4, 8]
  let configPath = getHomeDir() / ".config/niuv/config.ini"
  var originalConfig = ""
  
  # Backup original config
  if fileExists(configPath):
    originalConfig = readFile(configPath)
  
  try:
    for jobCount in jobCounts:
      # Update configuration
      let testConfig = fmt"""[coverage]
enabled=false
threshold=80.0
format=html
output_dir=.coverage
auto_open=false

[performance]
parallel=true
max_jobs={jobCount}
"""
      writeFile(configPath, testConfig)
      
      # Benchmark with this job count
      let benchmarkName = fmt"Parallel Jobs ({jobCount})"
      discard runBenchmark(benchmarkName, 3, proc() =
        if dirExists("tests/core/common"):
          discard execCmdEx("./.build/niuv-enhanced test tests/core/common/test_*.nim")
      )
  
  finally:
    # Restore original config
    if originalConfig != "":
      writeFile(configPath, originalConfig)

proc benchmarkConfigurationScenarios() =
  ## Benchmark different configuration scenarios
  logInfo("Benchmarking configuration scenarios...")
  
  let scenarios = [
    ("Development", """[coverage]
enabled=false
threshold=70.0
format=html
output_dir=.coverage
auto_open=false

[performance]
parallel=true
max_jobs=8
"""),
    ("CI/CD", """[coverage]
enabled=true
threshold=85.0
format=lcov
output_dir=ci_coverage
auto_open=false

[performance]
parallel=true
max_jobs=2
"""),
    ("High Quality", """[coverage]
enabled=true
threshold=95.0
format=html
output_dir=quality_reports
auto_open=false

[performance]
parallel=false
max_jobs=1
""")
  ]
  
  let configPath = getHomeDir() / ".config/niuv/config.ini"
  let originalConfig = if fileExists(configPath): readFile(configPath) else: ""
  
  try:
    for (scenarioName, config) in scenarios:
      writeFile(configPath, config)
      
      let benchmarkName = fmt"Config Scenario ({scenarioName})"
      discard runBenchmark(benchmarkName, 3, proc() =
        discard execCmdEx("./.build/niuv-enhanced validate-config")
        if fileExists("tests/test_simple.nim"):
          discard execCmdEx("./.build/niuv-enhanced test tests/test_simple.nim")
      )
  
  finally:
    if originalConfig != "":
      writeFile(configPath, originalConfig)

proc generatePerformanceReport() =
  ## Generate comprehensive performance report
  echo ""
  echo "=" .repeat(80)
  echo "ENHANCED NIUV PERFORMANCE BENCHMARK REPORT"
  echo "=" .repeat(80)
  echo ""
  
  echo fmt"Timestamp: {benchmarkSuite.timestamp}"
  echo fmt"Total Benchmarks: {benchmarkSuite.results.len}"
  echo ""
  
  echo "System Information:"
  echo "-" .repeat(40)
  for key, value in benchmarkSuite.systemInfo:
    echo fmt"  {key}: {value}"
  echo ""
  
  echo "Benchmark Results:"
  echo "-" .repeat(40)
  
  # Sort results by average duration
  var sortedResults = benchmarkSuite.results
  sortedResults.sort(proc(a, b: BenchmarkResult): int = 
    if a.averageDuration < b.averageDuration: -1
    elif a.averageDuration > b.averageDuration: 1
    else: 0
  )
  
  for result in sortedResults:
    echo fmt"{result.name}:"
    echo fmt"  Average: {result.averageDuration*1000:.2f}ms"
    echo fmt"  Min:     {result.minDuration*1000:.2f}ms"
    echo fmt"  Max:     {result.maxDuration*1000:.2f}ms"
    echo fmt"  Total:   {result.duration:.2f}s ({result.iterations} iterations)"
    if result.memoryUsage != 0:
      echo fmt"  Memory:  {result.memoryUsage}KB"
    echo ""
  
  # Performance analysis
  echo "Performance Analysis:"
  echo "-" .repeat(40)
  
  let fastestTest = sortedResults[0]
  let slowestTest = sortedResults[^1]
  
  echo fmt"Fastest operation: {fastestTest.name} ({fastestTest.averageDuration*1000:.2f}ms)"
  echo fmt"Slowest operation: {slowestTest.name} ({slowestTest.averageDuration*1000:.2f}ms)"
  
  if slowestTest.averageDuration > 0:
    let speedDiff = slowestTest.averageDuration / fastestTest.averageDuration
    echo fmt"Performance ratio: {speedDiff:.1f}x difference"
  
  echo ""
  
  # Performance recommendations
  echo "Performance Recommendations:"
  echo "-" .repeat(40)
  
  let avgDuration = benchmarkSuite.results.mapIt(it.averageDuration).foldl(a + b, 0.0) / benchmarkSuite.results.len.float
  
  for result in benchmarkSuite.results:
    if result.averageDuration > avgDuration * 2:
      echo fmt"⚠️  {result.name} is significantly slower than average"
    elif result.averageDuration < avgDuration * 0.5:
      echo fmt"✅ {result.name} performs very well"
  
  echo ""
  echo "=" .repeat(80)

proc exportBenchmarkData() =
  ## Export benchmark data to JSON for analysis
  let data = %*{
    "timestamp": benchmarkSuite.timestamp,
    "system_info": benchmarkSuite.systemInfo,
    "results": benchmarkSuite.results.mapIt((block:
      %*{
        "name": it.name,
        "duration": it.duration,
        "iterations": it.iterations,
        "average_duration": it.averageDuration,
        "min_duration": it.minDuration,
        "max_duration": it.maxDuration,
        "memory_usage": it.memoryUsage,
        "metadata": it.metadata
      }
    ))
  }
  
  let filename = fmt"benchmark-{now().format(\"yyyy-MM-dd-HH-mm-ss\")}.json"
  writeFile(filename, data.pretty())
  logInfo fmt"Benchmark data exported to: {filename}"

# Main benchmark execution

proc runStandardBenchmarks() =
  ## Run standard performance benchmarks
  logInfo("Running standard performance benchmarks...")
  
  # Ensure binary exists
  if not fileExists("./.build/niuv-enhanced"):
    logInfo("Building enhanced niuv binary...")
    discard execCmdEx("nim c -o:.build/niuv-enhanced niuv_enhanced.nim")
  
  # Core functionality benchmarks
  discard runBenchmark("Binary Startup", 10, benchmarkBinaryStartup)
  discard runBenchmark("Configuration Loading", 20, benchmarkConfigLoading)
  discard runBenchmark("Test Discovery", 5, benchmarkTestDiscovery)
  
  # Test execution benchmarks (if test files exist)
  if fileExists("tests/test_simple.nim"):
    discard runBenchmark("Simple Test", 5, benchmarkSimpleTest)
    discard runBenchmark("Coverage Test", 3, benchmarkCoverageTest)
    discard runBenchmark("No Coverage Test", 5, benchmarkNoCoverageTest)
  
  if dirExists("tests/core/common"):
    discard runBenchmark("Parallel Tests", 3, benchmarkParallelTests)
  
  # Shell completion benchmark
  if fileExists("niuv-enhanced-completion.bash"):
    discard runBenchmark("Shell Completion", 20, benchmarkShellCompletion)

proc runAdvancedBenchmarks() =
  ## Run advanced performance benchmarks
  logInfo("Running advanced performance benchmarks...")
  
  benchmarkParallelJobsComparison()
  benchmarkConfigurationScenarios()

proc main() =
  echo "🚀 Enhanced niuv Performance Benchmark Suite"
  echo ""
  
  collectSystemInfo()
  
  let args = commandLineParams()
  let benchmarkType = if args.len > 0: args[0] else: "standard"
  
  case benchmarkType:
  of "standard":
    runStandardBenchmarks()
  of "advanced":
    runStandardBenchmarks()
    runAdvancedBenchmarks()
  of "parallel":
    benchmarkParallelJobsComparison()
  of "config":
    benchmarkConfigurationScenarios()
  else:
    echo "Usage: nim c -r benchmark_niuv_enhanced.nim [standard|advanced|parallel|config]"
    echo ""
    echo "Benchmark types:"
    echo "  standard  - Core functionality benchmarks"
    echo "  advanced  - Standard + parallel and configuration benchmarks"
    echo "  parallel  - Parallel execution performance comparison"
    echo "  config    - Configuration scenario performance"
    return
  
  generatePerformanceReport()
  exportBenchmarkData()
  
  echo ""
  echo "🎉 Benchmark suite completed!"

when isMainModule:
  main()