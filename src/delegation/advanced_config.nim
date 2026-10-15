## Advanced configuration management for niuv
## Integrates structured configuration patterns from mcp-jujutsu

import std/[os, parseopt, strutils, tables, json, options, cpuinfo]
import base, logging_integration

type
  NiuvOperationMode* = enum
    ## Niuv operation modes
    omStandalone    # Standalone mode - independent operations
    omWorkspace     # Workspace mode - manage multiple related projects  
    omDelegated     # Delegated mode - delegate everything possible to external tools

  NiuvProfile* = enum
    ## Configuration profiles for different use cases
    profileDevelopment = "development"
    profileProduction = "production"
    profileTesting = "testing"
    profileCI = "ci"

  TransportConfig* = object
    ## Transport configuration for potential MCP integration
    enableMCP*: bool
    mcpPort*: int
    mcpHost*: string
    useStdio*: bool

  WorkspaceConfig* = object
    ## Workspace-specific configuration
    rootDir*: string
    projectPaths*: seq[string]
    sharedDependencies*: bool
    isolatedBuilds*: bool
    crossProjectDeps*: Table[string, seq[string]]

  DelegationProfile* = object
    ## Delegation configuration profiles
    preferTestkit*: bool
    preferNimble*: bool
    fallbackEnabled*: bool
    verboseDelegation*: bool
    delegationTimeout*: int  # Timeout in seconds

  AIIntegration* = object
    ## AI integration configuration (future use)
    enabled*: bool
    endpoint*: string
    apiKey*: string
    model*: string

  AdvancedNiuvConfig* = object
    ## Advanced configuration object for niuv
    # Core settings
    operationMode*: NiuvOperationMode
    profile*: NiuvProfile
    verbose*: bool
    dryRun*: bool
    
    # Logging configuration
    logLevel*: LogLevel
    logToFile*: bool
    logFilePath*: string
    
    # Delegation settings
    delegation*: DelegationProfile
    
    # Workspace settings
    workspace*: WorkspaceConfig
    
    # Transport (for potential MCP server functionality)
    transport*: TransportConfig
    
    # AI integration (reserved for future)
    ai*: AIIntegration
    
    # Path configurations
    configDir*: string
    cacheDir*: string
    tempDir*: string
    
    # Build and runtime settings
    parallelJobs*: int
    buildProfile*: string
    targetOS*: string
    targetCPU*: string
    
    # Package management
    packageCacheEnabled*: bool
    packageCacheTTL*: int
    autoUpdateDeps*: bool

proc newDefaultAdvancedConfig*(): AdvancedNiuvConfig =
  ## Create default advanced configuration
  let homeDir = getHomeDir()
  let configDir = homeDir / ".niuv"
  
  result = AdvancedNiuvConfig(
    # Core settings
    operationMode: omStandalone,
    profile: profileDevelopment,
    verbose: false,
    dryRun: false,
    
    # Logging
    logLevel: llInfo,
    logToFile: false,
    logFilePath: configDir / "niuv.log",
    
    # Delegation
    delegation: DelegationProfile(
      preferTestkit: true,
      preferNimble: false,
      fallbackEnabled: true,
      verboseDelegation: false,
      delegationTimeout: 300
    ),
    
    # Workspace
    workspace: WorkspaceConfig(
      rootDir: getCurrentDir(),
      projectPaths: @[],
      sharedDependencies: true,
      isolatedBuilds: false,
      crossProjectDeps: initTable[string, seq[string]]()
    ),
    
    # Transport
    transport: TransportConfig(
      enableMCP: false,
      mcpPort: 8080,
      mcpHost: "127.0.0.1",
      useStdio: false
    ),
    
    # AI Integration
    ai: AIIntegration(
      enabled: false,
      endpoint: "https://api.openai.com/v1/chat/completions",
      apiKey: "",
      model: "gpt-4"
    ),
    
    # Paths
    configDir: configDir,
    cacheDir: configDir / "cache",
    tempDir: getTempDir() / "niuv",
    
    # Build settings
    parallelJobs: countProcessors(),
    buildProfile: "debug",
    targetOS: hostOS,
    targetCPU: hostCPU,
    
    # Package management
    packageCacheEnabled: true,
    packageCacheTTL: 3600,
    autoUpdateDeps: false
  )

proc loadAdvancedConfigFile*(path: string): AdvancedNiuvConfig =
  ## Load advanced configuration from file
  result = newDefaultAdvancedConfig()
  
  if not fileExists(path):
    return
  
  try:
    let content = readFile(path)
    let jsonNode = parseJson(content)
    
    # Parse core settings
    if jsonNode.hasKey("mode"):
      let mode = jsonNode["mode"].getStr()
      case mode.toLowerAscii()
      of "standalone": result.operationMode = omStandalone
      of "workspace": result.operationMode = omWorkspace
      of "delegated": result.operationMode = omDelegated
    
    if jsonNode.hasKey("profile"):
      let profile = jsonNode["profile"].getStr()
      case profile.toLowerAscii()
      of "development": result.profile = profileDevelopment
      of "production": result.profile = profileProduction
      of "testing": result.profile = profileTesting
      of "ci": result.profile = profileCI
    
    if jsonNode.hasKey("verbose"):
      result.verbose = jsonNode["verbose"].getBool()
    
    # Parse logging settings
    if jsonNode.hasKey("logging"):
      let logging = jsonNode["logging"]
      if logging.hasKey("level"):
        let level = logging["level"].getStr().toLowerAscii()
        case level
        of "trace": result.logLevel = llTrace
        of "debug": result.logLevel = llDebug
        of "info": result.logLevel = llInfo
        of "warn", "warning": result.logLevel = llWarning
        of "error": result.logLevel = llError
        of "fatal": result.logLevel = llFatal
      
      if logging.hasKey("to_file"):
        result.logToFile = logging["to_file"].getBool()
      
      if logging.hasKey("file_path"):
        result.logFilePath = logging["file_path"].getStr()
    
    # Parse delegation settings
    if jsonNode.hasKey("delegation"):
      let delegation = jsonNode["delegation"]
      if delegation.hasKey("prefer_testkit"):
        result.delegation.preferTestkit = delegation["prefer_testkit"].getBool()
      if delegation.hasKey("prefer_nimble"):
        result.delegation.preferNimble = delegation["prefer_nimble"].getBool()
      if delegation.hasKey("fallback_enabled"):
        result.delegation.fallbackEnabled = delegation["fallback_enabled"].getBool()
      if delegation.hasKey("verbose"):
        result.delegation.verboseDelegation = delegation["verbose"].getBool()
      if delegation.hasKey("timeout"):
        result.delegation.delegationTimeout = delegation["timeout"].getInt()
    
    # Parse workspace settings
    if jsonNode.hasKey("workspace"):
      let workspace = jsonNode["workspace"]
      if workspace.hasKey("root_dir"):
        result.workspace.rootDir = workspace["root_dir"].getStr()
      if workspace.hasKey("project_paths"):
        result.workspace.projectPaths = @[]
        for path in workspace["project_paths"]:
          result.workspace.projectPaths.add(path.getStr())
      if workspace.hasKey("shared_dependencies"):
        result.workspace.sharedDependencies = workspace["shared_dependencies"].getBool()
      if workspace.hasKey("isolated_builds"):
        result.workspace.isolatedBuilds = workspace["isolated_builds"].getBool()
    
    # Parse build settings
    if jsonNode.hasKey("build"):
      let build = jsonNode["build"]
      if build.hasKey("parallel_jobs"):
        result.parallelJobs = build["parallel_jobs"].getInt()
      if build.hasKey("profile"):
        result.buildProfile = build["profile"].getStr()
      if build.hasKey("target_os"):
        result.targetOS = build["target_os"].getStr()
      if build.hasKey("target_cpu"):
        result.targetCPU = build["target_cpu"].getStr()
    
  except JsonParsingError, IOError:
    # Return default config if parsing fails
    debug("Failed to parse config file: " & path, newLogContext("config", "loader"))

proc saveAdvancedConfigFile*(config: AdvancedNiuvConfig, path: string) =
  ## Save advanced configuration to file
  var jsonNode = newJObject()
  
  # Core settings
  jsonNode["mode"] = newJString($config.operationMode)
  jsonNode["profile"] = newJString($config.profile)
  jsonNode["verbose"] = newJBool(config.verbose)
  jsonNode["dry_run"] = newJBool(config.dryRun)
  
  # Logging settings
  var logging = newJObject()
  logging["level"] = newJString($config.logLevel)
  logging["to_file"] = newJBool(config.logToFile)
  logging["file_path"] = newJString(config.logFilePath)
  jsonNode["logging"] = logging
  
  # Delegation settings
  var delegation = newJObject()
  delegation["prefer_testkit"] = newJBool(config.delegation.preferTestkit)
  delegation["prefer_nimble"] = newJBool(config.delegation.preferNimble)
  delegation["fallback_enabled"] = newJBool(config.delegation.fallbackEnabled)
  delegation["verbose"] = newJBool(config.delegation.verboseDelegation)
  delegation["timeout"] = newJInt(config.delegation.delegationTimeout)
  jsonNode["delegation"] = delegation
  
  # Workspace settings
  var workspace = newJObject()
  workspace["root_dir"] = newJString(config.workspace.rootDir)
  var projectPaths = newJArray()
  for path in config.workspace.projectPaths:
    projectPaths.add(newJString(path))
  workspace["project_paths"] = projectPaths
  workspace["shared_dependencies"] = newJBool(config.workspace.sharedDependencies)
  workspace["isolated_builds"] = newJBool(config.workspace.isolatedBuilds)
  jsonNode["workspace"] = workspace
  
  # Build settings
  var build = newJObject()
  build["parallel_jobs"] = newJInt(config.parallelJobs)
  build["profile"] = newJString(config.buildProfile)
  build["target_os"] = newJString(config.targetOS)
  build["target_cpu"] = newJString(config.targetCPU)
  jsonNode["build"] = build
  
  # Transport settings
  var transport = newJObject()
  transport["enable_mcp"] = newJBool(config.transport.enableMCP)
  transport["mcp_port"] = newJInt(config.transport.mcpPort)
  transport["mcp_host"] = newJString(config.transport.mcpHost)
  transport["use_stdio"] = newJBool(config.transport.useStdio)
  jsonNode["transport"] = transport
  
  try:
    createDir(parentDir(path))
    writeFile(path, jsonNode.pretty())
    info("Configuration saved", newLogContext("config", "saver").withMetadata("path", path))
  except IOError as e:
    error("Failed to save config: " & e.msg, newLogContext("config", "saver").withMetadata("path", path))

proc parseAdvancedCommandLine*(): AdvancedNiuvConfig =
  ## Parse command-line arguments for advanced configuration
  result = newDefaultAdvancedConfig()
  
  # Check for config file in standard locations
  let configLocations = [
    getCurrentDir() / ".niuv.json",
    result.configDir / "config.json",
    result.configDir / "niuv.json"
  ]
  
  for configPath in configLocations:
    if fileExists(configPath):
      result = loadAdvancedConfigFile(configPath)
      break
  
  # Parse command-line arguments
  var p = initOptParser()
  while true:
    p.next()
    case p.kind
    of cmdEnd: break
    of cmdShortOption, cmdLongOption:
      case p.key.toLowerAscii()
      of "h", "help":
        echo "Niuv - Nim Virtual Environment Manager"
        echo "Usage: niuv [options] [command]"
        echo "Options:"
        echo "  -h, --help                  Show this help message"
        echo "  --mode=MODE                 Operation mode: standalone, workspace, delegated"
        echo "  --profile=PROFILE           Configuration profile: development, production, testing, ci"
        echo "  --verbose                   Enable verbose output"
        echo "  --dry-run                   Show what would be done without executing"
        echo "  --log-level=LEVEL           Log level: trace, debug, info, warn, error, fatal"
        echo "  --log-to-file               Enable file logging"
        echo "  --config=PATH               Configuration file path"
        echo "  --workspace=PATH            Workspace root directory"
        echo "  --jobs=N                    Number of parallel jobs"
        echo "  --prefer-testkit            Prefer nim-testkit for operations"
        echo "  --prefer-nimble             Prefer nimble for operations"
        echo "  --no-fallback               Disable fallback to native implementations"
        quit(0)
      of "mode":
        case p.val.toLowerAscii()
        of "standalone": result.operationMode = omStandalone
        of "workspace": result.operationMode = omWorkspace
        of "delegated": result.operationMode = omDelegated
      of "profile":
        case p.val.toLowerAscii()
        of "development": result.profile = profileDevelopment
        of "production": result.profile = profileProduction
        of "testing": result.profile = profileTesting
        of "ci": result.profile = profileCI
      of "verbose":
        result.verbose = if p.val == "": true else: parseBool(p.val)
      of "dry-run":
        result.dryRun = if p.val == "": true else: parseBool(p.val)
      of "log-level":
        case p.val.toLowerAscii()
        of "trace": result.logLevel = llTrace
        of "debug": result.logLevel = llDebug
        of "info": result.logLevel = llInfo
        of "warn", "warning": result.logLevel = llWarning
        of "error": result.logLevel = llError
        of "fatal": result.logLevel = llFatal
      of "log-to-file":
        result.logToFile = if p.val == "": true else: parseBool(p.val)
      of "config":
        if fileExists(p.val):
          result = loadAdvancedConfigFile(p.val)
      of "workspace":
        result.workspace.rootDir = p.val
      of "jobs":
        result.parallelJobs = parseInt(p.val)
      of "prefer-testkit":
        result.delegation.preferTestkit = if p.val == "": true else: parseBool(p.val)
      of "prefer-nimble":
        result.delegation.preferNimble = if p.val == "": true else: parseBool(p.val)
      of "no-fallback":
        result.delegation.fallbackEnabled = false
    of cmdArgument:
      # Handle positional arguments if needed
      discard

proc setupAdvancedNiuv*(config: AdvancedNiuvConfig) =
  ## Setup niuv with advanced configuration
  # Setup logging
  setupDefaultLogger(config.logLevel, config.logToFile)
  
  # Create necessary directories
  createDir(config.configDir)
  createDir(config.cacheDir)
  createDir(config.tempDir)
  
  # Log configuration startup
  info("Niuv advanced configuration loaded", 
    newLogContext("startup", "config")
      .withMetadata("mode", $config.operationMode)
      .withMetadata("profile", $config.profile)
      .withMetadata("delegate_testkit", $config.delegation.preferTestkit)
      .withMetadata("delegate_nimble", $config.delegation.preferNimble))

# Template for advanced configuration usage
template withAdvancedConfig*(body: untyped) =
  ## Template to setup advanced configuration in niuv commands
  let advancedConfig {.inject.} = parseAdvancedCommandLine()
  setupAdvancedNiuv(advancedConfig)
  body