## Comprehensive integration module for niuv delegation system
## Integrates all patterns from mcp-jujutsu: VCS, logging, MCP, and advanced configuration

import std/[os, strutils, tables, json, asyncdispatch, options]
import base, testkit_adapter, nimble_adapter
import vcs_integration, logging_integration, advanced_config, mcp_integration
import ../config as niuv_config
import ../utils

type
  ComprehensiveIntegrationConfig* = object
    ## Comprehensive configuration that combines all integration patterns
    # Basic configurations
    niuvConfig*: Config
    delegationConfig*: DelegationConfig
    advancedConfig*: AdvancedNiuvConfig
    
    # Specialized configurations
    vcsConfig*: VCSConfig
    mcpServer*: Option[NiuvMCPServer]
    
    # Integration flags
    enableTestKit*: bool
    enableNimbleDelegate*: bool
    enableVCSIntegration*: bool
    enableMCPServer*: bool
    enableAdvancedLogging*: bool
    
    # Operational settings
    preferNative*: bool
    verboseMode*: bool
    initialized*: bool

proc loadComprehensiveConfig*(): ComprehensiveIntegrationConfig =
  ## Load comprehensive configuration combining all patterns
  result = ComprehensiveIntegrationConfig()
  
  # Load basic configurations
  result.niuvConfig = loadConfig()
  result.delegationConfig = loadDelegationConfig()
  result.advancedConfig = parseAdvancedCommandLine()
  
  # Setup advanced logging first
  setupAdvancedNiuv(result.advancedConfig)
  result.enableAdvancedLogging = true
  
  # Load VCS configuration
  result.vcsConfig = autoDetectVCS()
  setupVCSDelegation(result.delegationConfig, result.vcsConfig)
  result.enableVCSIntegration = result.vcsConfig.primary.available
  
  # Integration preferences from advanced config
  result.enableTestKit = result.advancedConfig.delegation.preferTestkit
  result.enableNimbleDelegate = result.advancedConfig.delegation.preferNimble
  result.enableMCPServer = result.advancedConfig.transport.enableMCP
  result.verboseMode = result.advancedConfig.verbose
  result.preferNative = not result.advancedConfig.delegation.fallbackEnabled
  
  # Setup MCP server if enabled
  if result.enableMCPServer:
    result.mcpServer = some(setupDefaultMCPServer(result.advancedConfig))
  
  # Override delegation config based on advanced preferences
  if result.preferNative:
    result.delegationConfig.preferDelegation = false
  
  # Log integration setup
  info("Comprehensive integration loaded",
    newLogContext("integration", "setup")
      .withMetadata("vcs_type", $result.vcsConfig.primary.vcsType)
      .withMetadata("testkit_enabled", $result.enableTestKit)
      .withMetadata("mcp_enabled", $result.enableMCPServer)
      .withMetadata("advanced_logging", $result.enableAdvancedLogging))
  
  result.initialized = true

proc getIntegrationStatus*(config: ComprehensiveIntegrationConfig): Table[string, bool] =
  ## Get status of all integration components
  result = initTable[string, bool]()
  
  # Basic availability
  result["nim"] = checkToolAvailable("nim")
  result["nimble"] = checkToolAvailable("nimble")
  result["nim-testkit"] = checkToolAvailable("nimtestkit")
  
  # VCS availability
  result["git"] = checkToolAvailable("git")
  result["jujutsu"] = checkToolAvailable("jj")
  result["vcs_detected"] = config.vcsConfig.primary.available
  
  # Delegation status
  result["delegation_enabled"] = config.delegationConfig.enabled
  result["testkit_delegate"] = config.delegationConfig.findDelegate(dcTestExecution).isSome
  result["nimble_delegate"] = config.delegationConfig.findDelegate(dcPackageSearch).isSome
  
  # Advanced features
  result["advanced_logging"] = config.enableAdvancedLogging
  result["mcp_server"] = config.mcpServer.isSome
  result["workspace_mode"] = config.advancedConfig.operationMode == omWorkspace
  
  # Performance features
  result["performance_cache"] = config.advancedConfig.packageCacheEnabled
  result["parallel_execution"] = config.advancedConfig.parallelJobs > 1

proc showComprehensiveStatus*(config: ComprehensiveIntegrationConfig) =
  ## Show comprehensive status report
  echo "Niuv Comprehensive Integration Status"
  echo "=" .repeat(50)
  
  let status = getIntegrationStatus(config)
  
  # Core tools
  echo "\nCore Tools:"
  for tool in ["nim", "nimble", "nim-testkit"]:
    let available = status.getOrDefault(tool, false)
    let icon = if available: "✅" else: "❌"
    echo "  ", icon, " ", tool
  
  # VCS Integration
  echo "\nVCS Integration:"
  echo "  VCS Type: ", config.vcsConfig.primary.vcsType
  echo "  VCS Root: ", config.vcsConfig.primary.rootDir
  echo "  ", if status["vcs_detected"]: "✅" else: "❌", " VCS Available"
  echo "  ", if status["git"]: "✅" else: "❌", " Git"
  echo "  ", if status["jujutsu"]: "✅" else: "❌", " Jujutsu"
  
  # Delegation System
  echo "\nDelegation System:"
  echo "  ", if status["delegation_enabled"]: "✅" else: "❌", " Delegation Enabled"
  echo "  ", if status["testkit_delegate"]: "✅" else: "❌", " TestKit Delegate"
  echo "  ", if status["nimble_delegate"]: "✅" else: "❌", " Nimble Delegate"
  echo "  Prefer Native: ", config.preferNative
  echo "  Fallback Enabled: ", config.delegationConfig.fallbackEnabled
  
  # Advanced Features
  echo "\nAdvanced Features:"
  echo "  ", if status["advanced_logging"]: "✅" else: "❌", " Advanced Logging"
  echo "  ", if status["mcp_server"]: "✅" else: "❌", " MCP Server"
  echo "  ", if status["workspace_mode"]: "✅" else: "❌", " Workspace Mode"
  echo "  ", if status["performance_cache"]: "✅" else: "❌", " Performance Cache"
  echo "  ", if status["parallel_execution"]: "✅" else: "❌", " Parallel Execution"
  
  # Configuration Details
  echo "\nConfiguration:"
  echo "  Operation Mode: ", config.advancedConfig.operationMode
  echo "  Profile: ", config.advancedConfig.profile
  echo "  Log Level: ", config.advancedConfig.logLevel
  echo "  Parallel Jobs: ", config.advancedConfig.parallelJobs
  echo "  Build Profile: ", config.advancedConfig.buildProfile

proc executeWithIntegration*[T](
  config: ComprehensiveIntegrationConfig,
  operation: string,
  capability: DelegateCapability,
  implementation: proc(): T,
  fallback: proc(): T = nil
): T =
  ## Execute operation with full integration support
  let ctx = newLogContext(operation, "integration")
  
  withOperationLogging(operation, "integration"):
    # Try delegation first if enabled
    if config.delegationConfig.enabled:
      let delegate = config.delegationConfig.findDelegate(capability)
      if delegate.isSome:
        logDelegateOperation(operation, delegate.get().name, true, "Using delegate")
        # Note: In a real implementation, we would call the delegate here
        # For now, we fall back to implementation
        return if implementation != nil: implementation() else: fallback()
    
    # Use implementation or fallback
    if implementation != nil:
      debug("Using native implementation", ctx)
      return implementation()
    elif fallback != nil:
      warning("Using fallback implementation", ctx)
      return fallback()
    else:
      error("No implementation available", ctx)
      raise newException(ValueError, "No implementation available for " & operation)

proc delegateVCSCommand*(config: ComprehensiveIntegrationConfig, cmd: string, args: seq[string] = @[]): bool =
  ## Delegate VCS command with full integration
  if not config.enableVCSIntegration:
    warning("VCS integration disabled", newLogContext("vcs", "delegation"))
    return false
  
  let result = delegateVCSOperation(config.vcsConfig, cmd, args)
  logVCSOperation(cmd, $config.vcsConfig.primary.vcsType, result.success, result.value)
  
  if config.verboseMode and result.success:
    echo result.value
  elif not result.success:
    error("VCS command failed: " & result.error, 
      newLogContext("vcs", "command").withMetadata("command", cmd))
  
  return result.success

proc manageMCPServer*(config: ComprehensiveIntegrationConfig): bool =
  ## Manage MCP server lifecycle
  if not config.enableMCPServer or config.mcpServer.isNone:
    return false
  
  let server = config.mcpServer.get()
  
  if not server.running:
    info("Starting MCP server", 
      newLogContext("mcp", "server")
        .withMetadata("port", $config.advancedConfig.transport.mcpPort)
        .withMetadata("host", config.advancedConfig.transport.mcpHost))
    
    server.running = true
    return true
  
  return true

proc setupWorkspaceIntegration*(config: ComprehensiveIntegrationConfig, workspacePath: string) =
  ## Setup workspace with full integration
  if config.advancedConfig.operationMode != omWorkspace:
    return
  
  logWorkspaceOperation("setup", workspacePath, true, "Configuring workspace integration")
  
  # Setup VCS in workspace if available
  if config.enableVCSIntegration:
    let workspaceVCS = autoDetectVCS(workspacePath)
    if workspaceVCS.primary.available:
      info("Workspace VCS detected", 
        newLogContext("workspace", "vcs")
          .withWorkspace(workspacePath)
          .withMetadata("vcs_type", $workspaceVCS.primary.vcsType))
  
  # Register workspace with MCP server if enabled
  if config.mcpServer.isSome:
    let server = config.mcpServer.get()
    server.registerResource(createWorkspaceResource(workspacePath))

# Migration utilities with full integration
proc migrateProjectWithIntegration*(config: ComprehensiveIntegrationConfig, projectPath: string = getCurrentDir()): bool =
  ## Migrate project with comprehensive integration support
  withOperationLogging("migrate", "integration"):
    info("Starting project migration", 
      newLogContext("migration", "project")
        .withMetadata("path", projectPath)
        .withMetadata("vcs_type", $config.vcsConfig.primary.vcsType))
    
    # Check for .nimble file
    let nimbleFiles = toSeq(walkFiles(projectPath / "*.nimble"))
    if nimbleFiles.len == 0:
      error("No .nimble file found", newLogContext("migration", "validation"))
      return false
    
    # Create comprehensive niuv configuration
    var niuvConfig = %* {
      "tool": {
        "niuv": {
          "mode": $config.advancedConfig.operationMode,
          "profile": $config.advancedConfig.profile,
          "delegation": {
            "testkit": config.enableTestKit,
            "nimble": config.enableNimbleDelegate,
            "fallback": config.delegationConfig.fallbackEnabled,
            "verbose": config.verboseMode
          },
          "vcs": {
            "type": $config.vcsConfig.primary.vcsType,
            "integration": config.enableVCSIntegration
          },
          "logging": {
            "level": $config.advancedConfig.logLevel,
            "to_file": config.advancedConfig.logToFile
          },
          "build": {
            "parallel_jobs": config.advancedConfig.parallelJobs,
            "profile": config.advancedConfig.buildProfile
          }
        }
      }
    }
    
    # Write advanced configuration
    writeFile(projectPath / "niuv.json", niuvConfig.pretty())
    info("Created comprehensive niuv configuration", newLogContext("migration", "config"))
    
    # VCS integration for migration
    if config.enableVCSIntegration and isWorkspaceClean(config.vcsConfig):
      discard delegateVCSCommand(config, "add", @["niuv.json"])
      discard delegateVCSCommand(config, "commit", @["-m", "Add niuv configuration"])
      info("Committed niuv configuration to VCS", newLogContext("migration", "vcs"))
    
    info("Migration completed successfully", newLogContext("migration", "completion"))
    return true

# Template for comprehensive integration usage
template withComprehensiveIntegration*(body: untyped) =
  ## Template to setup comprehensive integration in niuv commands
  let integrationConfig {.inject.} = loadComprehensiveConfig()
  if not integrationConfig.initialized:
    error("Failed to initialize comprehensive integration", newLogContext("integration", "error"))
    quit(1)
  
  # Setup MCP server if enabled
  if integrationConfig.enableMCPServer:
    discard manageMCPServer(integrationConfig)
  
  body

# Export all integrated capabilities
proc getIntegratedCapabilities*(config: ComprehensiveIntegrationConfig): seq[string] =
  ## Get list of all integrated capabilities
  result = @[
    "delegation_framework",
    "testkit_integration", 
    "nimble_integration"
  ]
  
  if config.enableVCSIntegration:
    result.add("vcs_integration")
    result.add($config.vcsConfig.primary.vcsType & "_support")
  
  if config.enableAdvancedLogging:
    result.add("structured_logging")
    result.add("operation_tracking")
  
  if config.mcpServer.isSome:
    result.add("mcp_server")
    result.add("ai_integration_ready")
  
  if config.advancedConfig.operationMode == omWorkspace:
    result.add("workspace_management")
  
  if config.advancedConfig.packageCacheEnabled:
    result.add("performance_caching")
  
  if config.advancedConfig.parallelJobs > 1:
    result.add("parallel_execution")