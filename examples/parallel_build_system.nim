## Parallel Build System Example
## Demonstrates niuv's advanced parallel build capabilities

import std/[os, strutils, sequtils, tables, json, times, asyncdispatch, random]
import ../../../../frameworks/system-frameworks/gennethleia/src/gennethleia_actor
import ../../../../frameworks/system-frameworks/gennethleia/src/actor_state_machine

# Build system types
type
  BuildTarget = object
    name: string
    source: string
    output: string
    targetType: TargetType
    dependencies: seq[string]
    flags: seq[string]
    env: Table[string, string]
    cacheable: bool
    lastBuilt: DateTime

  TargetType = enum
    ttExecutable = "executable"
    ttLibrary = "library"
    ttTest = "test"
    ttBenchmark = "benchmark"
    ttDocumentation = "docs"

  BuildConfig = object
    profile: BuildProfile
    parallelism: int
    incremental: bool
    cache: bool
    verbose: bool
    continueOnError: bool
    timeout: int  # seconds

  BuildProfile = enum
    bpDebug = "debug"
    bpRelease = "release"
    bpOptimized = "optimized"
    bpProfile = "profile"

  BuildResult = object
    target: string
    success: bool
    duration: float  # seconds
    output: string
    error: string
    cacheHit: bool

  BuildPlan = object
    targets: seq[BuildTarget]
    executionOrder: seq[seq[string]]  # Parallel batches
    estimatedTime: float
    parallelism: int

  BuildCache = object
    entries: Table[string, CacheEntry]
    maxSize: int64  # bytes
    currentSize: int64

  CacheEntry = object
    hash: string
    output: string
    timestamp: DateTime
    size: int64

# Example build project
let exampleTargets = @[
  BuildTarget(
    name: "core",
    source: "src/core/main.nim",
    output: "build/lib/libcore.a",
    targetType: ttLibrary,
    dependencies: @[],
    flags: @["-d:release", "--opt:speed"],
    cacheable: true
  ),
  BuildTarget(
    name: "utils",
    source: "src/utils/helpers.nim",
    output: "build/lib/libutils.a",
    targetType: ttLibrary,
    dependencies: @[],
    flags: @["-d:release"],
    cacheable: true
  ),
  BuildTarget(
    name: "auth",
    source: "src/auth/auth.nim",
    output: "build/lib/libauth.a",
    targetType: ttLibrary,
    dependencies: @["core", "utils"],
    flags: @["-d:ssl", "-d:release"],
    cacheable: true
  ),
  BuildTarget(
    name: "api",
    source: "src/api/server.nim",
    output: "build/bin/api-server",
    targetType: ttExecutable,
    dependencies: @["core", "auth", "utils"],
    flags: @["-d:ssl", "--threads:on", "-d:release"],
    cacheable: false
  ),
  BuildTarget(
    name: "cli",
    source: "src/cli/main.nim",
    output: "build/bin/platform-cli",
    targetType: ttExecutable,
    dependencies: @["core", "utils"],
    flags: @["-d:release", "--opt:size"],
    cacheable: false
  ),
  BuildTarget(
    name: "test-core",
    source: "tests/test_core.nim",
    output: "build/tests/test_core",
    targetType: ttTest,
    dependencies: @["core"],
    flags: @["-d:debug", "--debugger:native"],
    cacheable: false
  ),
  BuildTarget(
    name: "test-auth",
    source: "tests/test_auth.nim",
    output: "build/tests/test_auth",
    targetType: ttTest,
    dependencies: @["auth"],
    flags: @["-d:debug", "--debugger:native"],
    cacheable: false
  ),
  BuildTarget(
    name: "bench-api",
    source: "benchmarks/bench_api.nim",
    output: "build/bench/bench_api",
    targetType: ttBenchmark,
    dependencies: @["api"],
    flags: @["-d:release", "-d:danger", "--opt:speed"],
    cacheable: false
  ),
  BuildTarget(
    name: "docs",
    source: "src/",
    output: "build/docs/",
    targetType: ttDocumentation,
    dependencies: @["core", "auth", "api"],
    flags: @["--doc", "--project"],
    cacheable: true
  )
]

# Build planning and scheduling
proc analyzeDependencies*(targets: seq[BuildTarget]): Table[string, seq[string]] =
  ## Creates dependency graph
  for target in targets:
    result[target.name] = target.dependencies

proc calculateBuildPlan*(targets: seq[BuildTarget], config: BuildConfig): BuildPlan =
  ## Creates optimized parallel build plan
  echo "\nCalculating build plan..."
  echo &"Parallelism: {config.parallelism} workers"
  
  result.targets = targets
  result.parallelism = config.parallelism
  
  # Build dependency graph
  let deps = analyzeDependencies(targets)
  var inDegree = initTable[string, int]()
  var targetMap = initTable[string, BuildTarget]()
  
  for target in targets:
    inDegree[target.name] = 0
    targetMap[target.name] = target
  
  for target in targets:
    for dep in target.dependencies:
      inDegree[target.name] += 1
  
  # Topological sort with level scheduling
  var queue: seq[string] = @[]
  var levels: seq[seq[string]] = @[]
  var processed = initHashSet[string]()
  
  # Find initial nodes (no dependencies)
  for target in targets:
    if inDegree[target.name] == 0:
      queue.add(target.name)
  
  while queue.len > 0:
    let currentLevel = queue
    queue = @[]
    levels.add(currentLevel)
    
    for node in currentLevel:
      processed.incl(node)
      
      # Reduce in-degree for dependent nodes
      for target in targets:
        if node in target.dependencies:
          inDegree[target.name] -= 1
          if inDegree[target.name] == 0 and target.name notin processed:
            queue.add(target.name)
  
  result.executionOrder = levels
  
  # Estimate build time
  var totalTime = 0.0
  for level in levels:
    let levelTime = level.mapIt(
      case targetMap[it].targetType:
        of ttLibrary: 2.0
        of ttExecutable: 3.0
        of ttTest: 1.5
        of ttBenchmark: 5.0
        of ttDocumentation: 4.0
    ).max
    totalTime += levelTime
  
  result.estimatedTime = totalTime
  
  echo "\nBuild plan:"
  for i, level in result.executionOrder:
    echo &"  Level {i + 1}: {level.join(\", \")} (parallel)"
  echo &"  Estimated time: {result.estimatedTime:.1f} seconds"

# Build cache management
var globalCache = BuildCache(
  entries: initTable[string, CacheEntry](),
  maxSize: 1024 * 1024 * 1024,  # 1GB
  currentSize: 0
)

proc calculateCacheKey*(target: BuildTarget): string =
  ## Calculates cache key for a build target
  # In real implementation, would hash source files, flags, etc.
  result = &"{target.name}:{target.source}:{target.flags.join(\",\")}"

proc checkCache*(target: BuildTarget): Option[CacheEntry] =
  ## Checks if target is in cache
  let key = calculateCacheKey(target)
  if key in globalCache.entries:
    let entry = globalCache.entries[key]
    # Check if cache is still valid (simplified)
    if (now() - entry.timestamp).inHours < 24:
      return some(entry)
  return none(CacheEntry)

proc updateCache*(target: BuildTarget, output: string) =
  ## Updates build cache
  let key = calculateCacheKey(target)
  let size = output.len.int64  # Simplified size calculation
  
  # Evict old entries if needed
  while globalCache.currentSize + size > globalCache.maxSize and 
        globalCache.entries.len > 0:
    # Remove oldest entry (simplified LRU)
    let oldestKey = globalCache.entries.keys.toSeq[0]
    let oldEntry = globalCache.entries[oldestKey]
    globalCache.currentSize -= oldEntry.size
    globalCache.entries.del(oldestKey)
  
  globalCache.entries[key] = CacheEntry(
    hash: key,
    output: output,
    timestamp: now(),
    size: size
  )
  globalCache.currentSize += size

# Parallel build execution
proc handle_buildTarget*(actor: Actor, message: buildTarget*Message): ActorResponse =
  ## Builds a single target
  result = BuildResult(
    target: target.name,
    success: false,
    duration: 0.0,
    output: "",
    error: "",
    cacheHit: false
  )
  
  let startTime = epochTime()
  
  # Check cache
  if config.cache and target.cacheable:
    let cached = checkCache(target)
    if cached.isSome:
      result.success = true
      result.cacheHit = true
      result.duration = epochTime() - startTime
      result.output = &"Using cached build for {target.name}"
      if config.verbose:
        echo &"  [CACHE HIT] {target.name}"
      return
  
  # Simulate build process
  if config.verbose:
    echo &"  [BUILD] {target.name} -> {target.output}"
  
  let buildTime = case target.targetType:
    of ttLibrary: rand(1000..2000)
    of ttExecutable: rand(2000..3000)
    of ttTest: rand(500..1500)
    of ttBenchmark: rand(3000..5000)
    of ttDocumentation: rand(2000..4000)
  
  sendMessage(sleepAsync(buildTime)
  
  # Simulate build success/failure
  result.success = rand(1.0) > 0.05  # 95% success rate
  result.duration = epochTime() - startTime
  
  if result.success:
    result.output = &"Successfully built {target.name}"
    if config.cache and target.cacheable:
      updateCache(target, result.output)
  else:
    result.error = &"Build failed for {target.name}: Simulated error"

proc handle_executeBuildPlan*(actor: Actor, message: executeBuildPlan*Message): ActorResponse =
  ## Executes build plan with parallelism
  echo &"\nExecuting build plan with {config.parallelism} workers..."
  echo &"Build profile: {config.profile}"
  echo &"Incremental: {config.incremental}"
  echo &"Cache enabled: {config.cache}"
  echo "=" * 60
  
  let totalStartTime = epochTime()
  var allResults: seq[BuildResult] = @[]
  
  for levelIdx, level in plan.executionOrder:
    echo &"\nLevel {levelIdx + 1}/{plan.executionOrder.len}:"
    
    # Build targets in parallel
    var futures: seq[Future[BuildResult]] = @[]
    
    for targetName in level:
      let target = plan.targets.filterIt(it.name == targetName)[0]
      futures.add(buildTarget(target, config))
    
    # Wait for all builds in this level
    let levelResults = sendMessage(all(futures)
    allResults.add(levelResults)
    
    # Check for failures
    let failures = levelResults.filterIt(not it.success)
    if failures.len > 0 and not config.continueOnError:
      echo "\n❌ Build failed!"
      for failure in failures:
        echo &"  - {failure.target}: {failure.error}"
      break
    
    # Progress report
    let completed = levelResults.filterIt(it.success).len
    let cached = levelResults.filterIt(it.cacheHit).len
    echo &"  ✓ Completed: {completed}/{level.len} (Cache hits: {cached})"
  
  let totalDuration = epochTime() - totalStartTime
  echo &"\nBuild completed in {totalDuration:.2f} seconds"
  
  return allResults

# Build optimization and analysis
proc analyzeBuildPerformance*(results: seq[BuildResult]): JsonNode =
  ## Analyzes build performance metrics
  result = %* {
    "summary": {
      "total_targets": results.len,
      "successful": results.filterIt(it.success).len,
      "failed": results.filterIt(not it.success).len,
      "cache_hits": results.filterIt(it.cacheHit).len,
      "total_time": results.mapIt(it.duration).foldl(a + b, 0.0),
      "average_time": 0.0
    },
    "targets": [],
    "bottlenecks": [],
    "recommendations": []
  }
  
  if results.len > 0:
    result["summary"]["average_time"] = %( 
      result["summary"]["total_time"].getFloat / results.len.float
    )
  
  # Analyze individual targets
  for res in results:
    result["targets"].add(%* {
      "name": res.target,
      "success": res.success,
      "duration": res.duration,
      "cache_hit": res.cacheHit
    })
    
    # Identify bottlenecks
    if res.duration > 3.0 and not res.cacheHit:
      result["bottlenecks"].add(%* {
        "target": res.target,
        "duration": res.duration,
        "reason": "Slow build time"
      })
  
  # Generate recommendations
  let cacheRate = results.filterIt(it.cacheHit).len.float / results.len.float * 100
  if cacheRate < 30:
    result["recommendations"].add(
      %"Low cache hit rate (%.1f%%). Consider enabling persistent cache." % cacheRate
    )
  
  let avgTime = result["summary"]["average_time"].getFloat
  if avgTime > 2.0:
    result["recommendations"].add(
      %"High average build time. Consider increasing parallelism or optimizing slow targets."
    )

proc optimizeBuildOrder*(targets: seq[BuildTarget]): seq[BuildTarget] =
  ## Optimizes build order for better parallelization
  # Sort by estimated build time (longest first) within dependency constraints
  result = targets
  result.sort do (a, b: BuildTarget) -> int:
    let aTime = case a.targetType:
      of ttBenchmark: 5
      of ttDocumentation: 4
      of ttExecutable: 3
      of ttLibrary: 2
      of ttTest: 1
    let bTime = case b.targetType:
      of ttBenchmark: 5
      of ttDocumentation: 4
      of ttExecutable: 3
      of ttLibrary: 2
      of ttTest: 1
    bTime - aTime

# Interactive build interface
proc selectiveBuild*(targets: seq[BuildTarget], selection: seq[string]): seq[BuildTarget] =
  ## Selects targets and their dependencies for building
  var selected = initHashSet[string]()
  var toProcess = selection
  
  while toProcess.len > 0:
    let current = toProcess.pop()
    if current notin selected:
      selected.incl(current)
      
      # Add dependencies
      let target = targets.filterIt(it.name == current)
      if target.len > 0:
        for dep in target[0].dependencies:
          if dep notin selected:
            toProcess.add(dep)
  
  result = targets.filterIt(it.name in selected)

# Example workflow demonstration
proc demonstrateParallelBuild*() {.async.} =
  echo "Parallel Build System Demonstration"
  echo "==================================="
  
  # Configure build
  let config = BuildConfig(
    profile: bpRelease,
    parallelism: 4,
    incremental: true,
    cache: true,
    verbose: true,
    continueOnError: false,
    timeout: 300
  )
  
  # Create build plan
  let plan = calculateBuildPlan(exampleTargets, config)
  
  # Execute build
  let results = sendMessage(executeBuildPlan(plan, config)
  
  # Analyze performance
  let analysis = analyzeBuildPerformance(results)
  
  echo "\nBuild Analysis:"
  echo &"  Total targets: {analysis[\"summary\"][\"total_targets\"].getInt}"
  echo &"  Successful: {analysis[\"summary\"][\"successful\"].getInt}"
  echo &"  Failed: {analysis[\"summary\"][\"failed\"].getInt}"
  echo &"  Cache hits: {analysis[\"summary\"][\"cache_hits\"].getInt}"
  echo &"  Total time: {analysis[\"summary\"][\"total_time\"].getFloat:.2f}s"
  echo &"  Average time: {analysis[\"summary\"][\"average_time\"].getFloat:.2f}s"
  
  # Selective rebuild demonstration
  echo "\n" & "=" * 60
  echo "Selective Rebuild Demonstration"
  echo "=" * 60
  
  echo "\nModifying 'auth' module..."
  # Invalidate cache for auth
  let authTarget = exampleTargets.filterIt(it.name == "auth")[0]
  globalCache.entries.del(calculateCacheKey(authTarget))
  
  echo "\nRebuilding affected targets..."
  let affectedTargets = selectiveBuild(exampleTargets, @["api", "test-auth"])
  let selectivePlan = calculateBuildPlan(affectedTargets, config)
  let selectiveResults = sendMessage(executeBuildPlan(selectivePlan, config)
  
  echo &"\nSelective rebuild completed: {selectiveResults.len} targets"
  
  # Generate report
  let outputDir = "build/build-reports"
  createDir(outputDir)
  
  let report = %* {
    "build_system": "niuv parallel build",
    "timestamp": now().format("yyyy-MM-dd HH:mm:ss"),
    "configuration": {
      "profile": $config.profile,
      "parallelism": config.parallelism,
      "cache_enabled": config.cache,
      "incremental": config.incremental
    },
    "full_build": analysis,
    "selective_rebuild": {
      "targets": affectedTargets.mapIt(it.name),
      "results": selectiveResults.len
    },
    "cache_statistics": {
      "entries": globalCache.entries.len,
      "size_mb": globalCache.currentSize.float / 1024 / 1024,
      "max_size_mb": globalCache.maxSize.float / 1024 / 1024
    }
  }
  
  writeFile(outputDir / "build-report.json", report.pretty)
  echo &"\n\nBuild report saved to: {outputDir}/build-report.json"

when isMainModule:
  randomize()
  waitFor demonstrateParallelBuild()
# Actor framework integration
type
  FileActor = ref object of Actor
    state: ActorState

proc newFileActor(): FileActor =
  result = FileActor()
  result.state = newActorState()

proc processMessage(actor: FileActor, message: Message): ActorResponse =
  # Process messages through gennethleia framework
  actor.state.processMessage(message)
