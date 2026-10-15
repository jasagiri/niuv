## Configuration Manager for niuv
## Uses nim-configkit to provide a unified configuration system

import std/[os, strutils, tables, json]
import std/parsecfg as pc
import config

type
  BuildProfile* = enum
    bpDebug = "debug"
    bpRelease = "release"
    bpTest = "test"
    bpBenchmark = "benchmark"

  NiuvConfigManager* = object
    profile*: BuildProfile
    baseConfig*: NiuvConfig
    configData*: JsonNode  # Simple JSON-based config storage
    
  CompilerConfig* = object
    nimcache*: string
    outdir*: string
    paths*: seq[string]
    nimblePaths*: seq[string]
    defines*: seq[string]
    hints*: bool
    warnings*: bool
    threads*: bool
    opt*: string
    debugger*: string
    stackTrace*: bool
    lineTrace*: bool

proc detectProfile(): BuildProfile =
  ## Detect build profile from environment and command line
  if defined(release):
    return bpRelease
  elif defined(test) or existsEnv("NIUV_TEST") or existsEnv("NIMBLE_TEST"):
    return bpTest
  elif defined(benchmark):
    return bpBenchmark
  else:
    return bpDebug

proc loadConfigData(): JsonNode =
  ## Load configuration from niuv.toml if it exists
  result = %* {
    "build": {"dir": "build"},
    "debug": {"opt": "none", "stackTrace": true, "lineTrace": true},
    "release": {"opt": "speed"},
    "test": {"useTestKit": true, "dir": "tests", "pattern": "test_*.nim"},
    "coverage": {"enabled": true, "threshold": 80.0, "formats": ["html", "json"]}
  }
  
  # Override with niuv.toml if exists
  if fileExists("niuv.toml"):
    # Simple TOML parsing for key values
    let cfg = pc.loadConfig("niuv.toml")
    for section, sectionData in cfg.pairs:
      if section notin result:
        result[section] = newJObject()
      for key, value in sectionData.pairs:
        result[section][key] = %value

proc getString(data: JsonNode, path: string, default: string): string =
  ## Get string value from nested path (e.g., "build.dir")
  let parts = path.split(".")
  var current = data
  for i, part in parts:
    if current.kind != JObject or part notin current:
      return default
    if i == parts.len - 1:
      return current[part].getStr(default)
    current = current[part]
  return default

proc getBool(data: JsonNode, path: string, default: bool): bool =
  ## Get bool value from nested path
  let parts = path.split(".")
  var current = data
  for i, part in parts:
    if current.kind != JObject or part notin current:
      return default
    if i == parts.len - 1:
      return current[part].getBool(default)
    current = current[part]
  return default

proc getInt(data: JsonNode, path: string, default: int): int =
  ## Get int value from nested path
  let parts = path.split(".")
  var current = data
  for i, part in parts:
    if current.kind != JObject or part notin current:
      return default
    if i == parts.len - 1:
      return current[part].getInt(default)
    current = current[part]
  return default

proc getFloat(data: JsonNode, path: string, default: float): float =
  ## Get float value from nested path
  let parts = path.split(".")
  var current = data
  for i, part in parts:
    if current.kind != JObject or part notin current:
      return default
    if i == parts.len - 1:
      return current[part].getFloat(default)
    current = current[part]
  return default

proc initNiuvConfigManager*(): NiuvConfigManager =
  ## Initialize the configuration manager
  result.profile = detectProfile()
  result.configData = loadConfigData()
  result.baseConfig = loadConfig()

proc getCompilerConfig*(manager: NiuvConfigManager): CompilerConfig =
  ## Get compiler configuration based on current profile
  let buildDir = getString(manager.configData, "build.dir", "build")
  let profileStr = $manager.profile
  
  result = CompilerConfig(
    nimcache: buildDir / profileStr / "nimcache",
    outdir: buildDir / profileStr / "bin",
    paths: @[],
    nimblePaths: @["nimbledeps/pkgs"],
    defines: @[],
    hints: true,
    warnings: true,
    threads: true,
    opt: "none",
    debugger: "native",
    stackTrace: false,
    lineTrace: false
  )
  
  # Profile-specific configuration
  case manager.profile
  of bpRelease:
    result.opt = getString(manager.configData, "release.opt", "speed")
    result.defines.add("release")
    result.stackTrace = false
    result.lineTrace = false
    
  of bpDebug:
    result.opt = getString(manager.configData, "debug.opt", "none")
    result.debugger = getString(manager.configData, "debug.debugger", "native")
    result.stackTrace = getBool(manager.configData, "debug.stackTrace", true)
    result.lineTrace = getBool(manager.configData, "debug.lineTrace", true)
    
  of bpTest:
    result.paths.add("src")
    result.defines.add("testing")
    result.defines.add("niuvTest")
    # Use nim-testkit configuration if available
    if getBool(manager.configData, "test.useTestKit", true):
      result.defines.add("niuvTestKit")
    
  of bpBenchmark:
    result.opt = "speed"
    result.defines.add("release")
    result.defines.add("benchmark")

proc generateNimCfg*(manager: NiuvConfigManager): string =
  ## Generate nim.cfg content based on configuration
  let config = manager.getCompilerConfig()
  result = "# Generated by niuv config manager\n"
  result.add("# Profile: " & $manager.profile & "\n\n")
  
  # Nimcache
  result.add("--nimcache:\"" & config.nimcache & "\"\n")
  
  # Output directory (only for non-test builds)
  if manager.profile != bpTest:
    result.add("--outdir:\"" & config.outdir & "\"\n")
  
  # Paths
  for path in config.paths:
    result.add("--path:\"" & path & "\"\n")
  
  # Nimble paths
  for path in config.nimblePaths:
    result.add("--nimblePath:\"" & path & "\"\n")
  
  # Defines
  for define in config.defines:
    result.add("--define:" & define & "\n")
  
  # Optimization
  if config.opt != "none":
    result.add("--opt:" & config.opt & "\n")
  
  # Debugging options
  if manager.profile == bpDebug:
    result.add("--debugger:" & config.debugger & "\n")
    if config.stackTrace:
      result.add("--stackTrace:on\n")
    if config.lineTrace:
      result.add("--lineTrace:on\n")
  
  # Hints and warnings
  result.add("--hints:" & (if config.hints: "on" else: "off") & "\n")
  result.add("--warnings:" & (if config.warnings: "on" else: "off") & "\n")
  
  # Threading
  if config.threads:
    result.add("--threads:on\n")

proc generateConfigNims*(manager: NiuvConfigManager): string =
  ## Generate config.nims content
  result = """# Generated by niuv config manager
import std/[os, strutils]

# Build directory configuration
const buildDir = """ & "\"" & getString(manager.configData, "build.dir", "build") & "\"\n\n"

  result.add("""
# Detect profile
var profile = """ & "\"" & $manager.profile & "\"\n")
  
  result.add("""
# Apply profile-specific settings
case profile
of "release":
  switch("opt", "speed")
  switch("define", "release")
of "debug":
  switch("debugger", "native")
  switch("stackTrace", "on")
  switch("lineTrace", "on")
of "test":
  switch("path", "src")
  switch("define", "testing")
  switch("define", "niuvTest")
""")

  if getBool(manager.configData, "test.useTestKit", true):
    result.add("""  switch("define", "niuvTestKit")
""")
    
  result.add("""of "benchmark":
  switch("opt", "speed")
  switch("define", "release")
  switch("define", "benchmark")
else:
  discard

# Common settings
switch("nimcache", buildDir / profile / "nimcache")
if profile != "test":
  switch("outdir", buildDir / profile / "bin")

# Threading
switch("threads", "on")
""")

proc generateTestKitConfig*(manager: NiuvConfigManager): string =
  ## Generate nim-testkit configuration
  result = """# nim-testkit configuration for niuv
[test]
# Test discovery
testDir = """ & "\"" & getString(manager.configData, "test.dir", "tests") & "\"\n"
  result.add("pattern = \"" & getString(manager.configData, "test.pattern", "test_*.nim") & "\"\n")
  result.add("parallel = " & $getBool(manager.configData, "test.parallel", false) & "\n")
  result.add("timeout = " & $getInt(manager.configData, "test.timeout", 300) & "\n")
  result.add("\n")
  
  result.add("""# Coverage settings
[coverage]
enabled = """ & $getBool(manager.configData, "coverage.enabled", true) & "\n")
  result.add("threshold = " & $getFloat(manager.configData, "coverage.threshold", 80.0) & "\n")
  result.add("outputDir = \"" & getString(manager.configData, "coverage.outputDir", "build/coverage") & "\"\n")
  result.add("formats = [")
  
  # Get formats from config
  var formats = @["html", "json"]
  if manager.configData.hasKey("coverage") and manager.configData["coverage"].hasKey("formats"):
    formats = @[]
    for format in manager.configData["coverage"]["formats"]:
      formats.add(format.getStr())
  for i, format in formats:
    result.add("\"" & format & "\"")
    if i < formats.len - 1:
      result.add(", ")
  result.add("]\n\n")
  
  result.add("""# Reporting
[reporting]
verbose = """ & $getBool(manager.configData, "reporting.verbose", false) & "\n")
  result.add("showTiming = " & $getBool(manager.configData, "reporting.showTiming", true) & "\n")
  result.add("showMemory = " & $getBool(manager.configData, "reporting.showMemory", false) & "\n")

proc writeMinimalConfigs*(manager: NiuvConfigManager) =
  ## Write minimal configuration files
  # Main nim.cfg (minimal)
  writeFile("nim.cfg", """# Minimal niuv configuration
# See config.nims for dynamic configuration
--nimblePath:"nimbledeps/pkgs"
""")
  
  # config.nims (dynamic configuration)
  writeFile("config.nims", manager.generateConfigNims())
  
  # Remove redundant cfg files
  if fileExists("src/nim.cfg"):
    removeFile("src/nim.cfg")
  if fileExists("tests/nim.cfg"):
    removeFile("tests/nim.cfg")
  
  # Generate nimtestkit.toml if using testkit
  if getBool(manager.configData, "test.useTestKit", true):
    writeFile("nimtestkit.toml", manager.generateTestKitConfig())

proc updateNimbleConfig*(manager: NiuvConfigManager) =
  ## Update nimble.cfg with minimal settings
  writeFile("nimble.cfg", """# Minimal nimble configuration
binDir = """ & "\"" & getString(manager.configData, "build.dir", "build") & """/bin"
""")

when isMainModule:
  # Example usage
  let manager = initNiuvConfigManager()
  echo "Current profile: ", manager.profile
  echo "\nCompiler configuration:"
  let config = manager.getCompilerConfig()
  echo "  nimcache: ", config.nimcache
  echo "  outdir: ", config.outdir
  echo "  defines: ", config.defines
  
  echo "\nGenerating minimal configs..."
  manager.writeMinimalConfigs()
  manager.updateNimbleConfig()
  echo "Done!"