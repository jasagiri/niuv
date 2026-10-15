## Integration module for niuv delegation system
## Provides high-level integration and configuration management

import std/[os, strutils, tables, json]
import base, testkit_adapter, nimble_adapter
import ../config as niuv_config
import ../utils

type
  IntegrationConfig* = object
    ## Configuration for niuv integration with delegated tools
    niuvConfig*: Config
    delegationConfig*: DelegationConfig
    enableTestKit*: bool
    enableNimbleDelegate*: bool
    preferNative*: bool

proc loadIntegrationConfig*(): IntegrationConfig =
  ## Load integration configuration from niuv config
  result.niuvConfig = loadConfig()
  result.delegationConfig = loadDelegationConfig()
  
  # Check configuration preferences
  result.enableTestKit = result.niuvConfig.getOrDefault("delegation.testkit", true).getBool
  result.enableNimbleDelegate = result.niuvConfig.getOrDefault("delegation.nimble", true).getBool
  result.preferNative = result.niuvConfig.getOrDefault("delegation.preferNative", false).getBool
  
  # Override delegation config based on preferences
  if result.preferNative:
    result.delegationConfig.preferDelegation = false
  
  # Disable specific delegates if requested
  if not result.enableTestKit:
    result.delegationConfig.delegates.del("nim-testkit")
  
  if not result.enableNimbleDelegate:
    result.delegationConfig.delegates.del("nimble")

proc ensureTestKit*(config: IntegrationConfig): bool =
  ## Ensure nim-testkit is available for testing
  if not config.enableTestKit:
    return false
  
  let testkit = config.delegationConfig.findDelegate(dcTestExecution)
  if testkit.isNone:
    echo "nim-testkit not found. Installing..."
    let (output, exitCode) = execCmdEx("nimble install nimtestkit")
    if exitCode == 0:
      echo "✅ nim-testkit installed successfully"
      # Reload delegation config
      config.delegationConfig = loadDelegationConfig()
      return true
    else:
      echo "❌ Failed to install nim-testkit"
      echo output
      return false
  
  return true

proc migrateFromNimble*(projectPath: string = getCurrentDir()): bool =
  ## Migrate a nimble project to use niuv
  echo "Migrating project from nimble to niuv..."
  
  # Check for .nimble file
  let nimbleFiles = toSeq(walkFiles(projectPath / "*.nimble"))
  if nimbleFiles.len == 0:
    echo "No .nimble file found"
    return false
  
  # Create niuv configuration
  var niuvConfig = %* {
    "tool": {
      "niuv": {
        "delegation": {
          "testkit": true,
          "nimble": true,
          "preferNative": false
        },
        "nimVersion": "stable",
        "parallelJobs": 0,
        "verboseOutput": false,
        "autoLock": true
      }
    }
  }
  
  # Parse nimble file for additional configuration
  let nimbleContent = readFile(nimbleFiles[0])
  for line in nimbleContent.splitLines():
    if line.startsWith("version"):
      let version = line.split("=")[1].strip().strip(chars = {'"'})
      niuvConfig["tool"]["niuv"]["projectVersion"] = %version
    elif line.startsWith("author"):
      let author = line.split("=")[1].strip().strip(chars = {'"'})
      niuvConfig["tool"]["niuv"]["author"] = %author
    elif line.startsWith("description"):
      let desc = line.split("=")[1].strip().strip(chars = {'"'})
      niuvConfig["tool"]["niuv"]["description"] = %desc
  
  # Write niuv.toml
  writeFile(projectPath / "niuv.toml", niuvConfig.pretty())
  echo "✅ Created niuv.toml configuration"
  
  # Initialize virtual environment
  echo "Initializing virtual environment..."
  discard execShellCmd("niuv init")
  
  # Install dependencies
  echo "Installing dependencies..."
  discard execShellCmd("niuv install")
  
  echo "✅ Migration complete!"
  echo ""
  echo "You can now use niuv commands instead of nimble:"
  echo "  niuv build    # instead of nimble build"
  echo "  niuv test     # instead of nimble test"
  echo "  niuv task     # instead of nimble <task>"
  echo ""
  echo "Your .nimble file is preserved for compatibility."
  
  return true

proc createNimbleCompatibilityShim*() =
  ## Create a nimble shim that redirects to niuv
  let shimContent = """#!/bin/sh
# Nimble compatibility shim for niuv
# This script redirects nimble commands to niuv

case "$1" in
  build)
    shift
    exec niuv build "$@"
    ;;
  test)
    shift
    exec niuv test "$@"
    ;;
  install)
    shift
    exec niuv install "$@"
    ;;
  search)
    shift
    exec niuv search "$@"
    ;;
  publish)
    shift
    exec niuv publish "$@"
    ;;
  develop)
    shift
    exec niuv develop "$@"
    ;;
  path)
    shift
    exec niuv path "$@"
    ;;
  dump)
    shift
    exec niuv dump "$@"
    ;;
  refresh)
    shift
    exec niuv refresh "$@"
    ;;
  check)
    shift
    exec niuv check "$@"
    ;;
  uninstall)
    shift
    exec niuv uninstall "$@"
    ;;
  *)
    # For tasks and other commands
    exec niuv task "$@"
    ;;
esac
"""
  
  let shimPath = getHomeDir() / ".niuv" / "bin" / "nimble"
  createDir(getHomeDir() / ".niuv" / "bin")
  writeFile(shimPath, shimContent)
  
  # Make executable
  inclFilePermissions(shimPath, {fpUserExec, fpGroupExec, fpOthersExec})
  
  echo "Created nimble compatibility shim at: ", shimPath
  echo "Add ~/.niuv/bin to your PATH to use niuv as a drop-in nimble replacement"

proc checkCompatibility*(): Table[string, bool] =
  ## Check compatibility with various tools
  result = initTable[string, bool]()
  
  # Check nim
  result["nim"] = checkToolAvailable("nim")
  
  # Check nimble (for delegation)
  result["nimble"] = checkToolAvailable("nimble")
  
  # Check nim-testkit
  result["nim-testkit"] = checkToolAvailable("nimtestkit")
  
  # Check git
  result["git"] = checkToolAvailable("git")
  
  # Check jujutsu (optional)
  result["jujutsu"] = checkToolAvailable("jj")

proc showCompatibilityReport*() =
  ## Show a compatibility report
  echo "niuv Compatibility Report"
  echo "=" .repeat(40)
  
  let compat = checkCompatibility()
  
  for tool, available in compat:
    let status = if available: "✅" else: "❌"
    let required = tool in ["nim"]
    let requiredText = if required: " (required)" else: ""
    echo status, " ", tool, requiredText
  
  echo ""
  
  if not compat["nim"]:
    echo "⚠️  Nim is required but not found in PATH"
    echo "   Please install Nim: https://nim-lang.org/install.html"
  
  if not compat["nim-testkit"]:
    echo "ℹ️  nim-testkit not found"
    echo "   Testing features will use fallback implementation"
    echo "   Install with: nimble install nimtestkit"
  
  if not compat["nimble"]:
    echo "ℹ️  nimble not found" 
    echo "   Package registry features will be limited"
    echo "   Install nimble for full functionality"