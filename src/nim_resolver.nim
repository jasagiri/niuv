## Nim compiler resolver for niuv
## Integrates nim_detector with niuv configuration

import std/[os, strutils, tables, logging]
import nim_detector
import config
import utils

type
  NimResolverError* = object of CatchableError

var nimCompilerCache: Table[string, NimCompilerInfo]
let cacheTimeout = 300.0  # 5 minutes in seconds
var lastCacheTime = 0.0

proc clearNimCache*() =
  ## Clear the Nim compiler cache
  nimCompilerCache.clear()
  lastCacheTime = 0.0

proc getCacheKey(config: NiuvConfig): string =
  ## Generate cache key based on configuration
  result = config.nimPath & "|" & config.nimVersion & "|" & 
           config.nimDetection & "|" & $config.allowSystemNim

proc getNimForBuild*(config: NiuvConfig): string =
  ## Get the Nim compiler path to use for building
  ## Priority:
  ## 1. Explicit nim_path in config
  ## 2. Project-local Nim (.niuv/nim/bin/nim)
  ## 3. NIUV_NIM_PATH environment variable
  ## 4. Version-matched Nim (if nim_version specified)
  ## 5. System Nim (if allowed)
  
  # Check cache first
  let cacheKey = getCacheKey(config)
  let currentTime = epochTime()
  if cacheKey in nimCompilerCache and (currentTime - lastCacheTime) < cacheTimeout:
    let cached = nimCompilerCache[cacheKey]
    if cached.isValid:
      return cached.path
  
  # 1. Check explicit path
  if config.nimPath != "":
    logInfo("Checking configured Nim path: " & config.nimPath)
    let info = checkNimExecutable(config.nimPath)
    if info.isValid:
      nimCompilerCache[cacheKey] = info
      lastCacheTime = currentTime
      return info.path
    else:
      logWarning("Configured Nim path is invalid: " & config.nimPath)
  
  # 2. Check project-local Nim
  let projectNim = getCurrentDir() / ".niuv" / "nim" / "bin" / "nim"
  if fileExists(projectNim):
    let info = checkNimExecutable(projectNim)
    if info.isValid:
      logInfo("Using project-local Nim: " & projectNim)
      nimCompilerCache[cacheKey] = info
      lastCacheTime = currentTime
      return info.path
  
  # 3. Check environment variable
  let envNimPath = getEnv("NIUV_NIM_PATH")
  if envNimPath != "":
    let info = checkNimExecutable(envNimPath)
    if info.isValid:
      logInfo("Using Nim from NIUV_NIM_PATH: " & envNimPath)
      nimCompilerCache[cacheKey] = info
      lastCacheTime = currentTime
      return info.path
  
  # Check detection strategy
  if config.nimDetection == "project-only":
    raise newException(NimResolverError, 
      "No project-local Nim found and detection strategy is 'project-only'")
  
  # Check if system fallback is allowed
  if not config.allowSystemNim:
    raise newException(NimResolverError, 
      "No project-local Nim found and system fallback is disabled. " &
      "Set 'allow_system_nim = true' in niuv.toml or run 'niuv nim install'")
  
  # 4. Try to find version-matched Nim if specified
  if config.nimVersion != "":
    logInfo("Looking for Nim version: " & config.nimVersion)
    let compilers = detectNimCompilers()
    for compiler in compilers:
      if compiler.version == config.nimVersion or 
         compiler.version.startsWith(config.nimVersion & "."):
        logInfo("Found matching Nim version: " & compiler.version & " at " & compiler.path)
        nimCompilerCache[cacheKey] = compiler
        lastCacheTime = currentTime
        return compiler.path
  
  # 5. Use best available system Nim
  logInfo("No project-local Nim found, searching system...")
  let best = selectBestNimCompiler()
  if best.isValid:
    logInfo("Using system Nim: " & best.path & " (version: " & best.version & ", source: " & best.source & ")")
    nimCompilerCache[cacheKey] = best
    lastCacheTime = currentTime
    return best.path
  
  raise newException(NimResolverError, "No Nim compiler found")

proc getNimVersion*(config: NiuvConfig): string =
  ## Get the version of the Nim compiler that would be used
  try:
    let nimPath = getNimForBuild(config)
    let info = checkNimExecutable(nimPath)
    if info.isValid:
      return info.version
    else:
      return "unknown"
  except NimResolverError:
    return "not found"

proc listAvailableNims*(): seq[NimCompilerInfo] =
  ## List all available Nim compilers on the system
  result = detectNimCompilers()

proc showNimWhich*(config: NiuvConfig) =
  ## Show which Nim compiler would be used with current configuration
  try:
    let nimPath = getNimForBuild(config)
    let info = checkNimExecutable(nimPath)
    
    echo "Nim compiler that would be used:"
    echo "  Path: ", nimPath
    if info.isValid:
      echo "  Version: ", info.version
      echo "  Source: ", info.source
    
    # Show configuration affecting selection
    echo "\nCurrent configuration:"
    echo "  nim_path: ", if config.nimPath == "": "(not set)" else: config.nimPath
    echo "  nim_version: ", if config.nimVersion == "": "(not set)" else: config.nimVersion
    echo "  nim_detection: ", config.nimDetection
    echo "  allow_system_nim: ", config.allowSystemNim
    
  except NimResolverError as e:
    echo "Error: ", e.msg

proc showNimList*() =
  ## Show all available Nim compilers
  let compilers = listAvailableNims()
  
  if compilers.len == 0:
    echo "No Nim compilers found on the system"
    return
  
  echo "Available Nim compilers:"
  echo ""
  
  for i, compiler in compilers:
    echo i + 1, ". ", compiler.path
    echo "   Version: ", compiler.version
    echo "   Source: ", compiler.source
    echo ""
  
  # Show current selection
  try:
    let config = loadConfig()
    let currentPath = getNimForBuild(config)
    echo "Current selection: ", currentPath
  except:
    discard

proc installProjectNim*(version: string): bool =
  ## Install a specific Nim version for the project
  ## This is a placeholder - actual implementation would download/install Nim
  echo "Installing Nim ", version, " for project..."
  echo "This feature is not yet implemented."
  echo ""
  echo "For now, you can:"
  echo "1. Use choosenim to install Nim: choosenim ", version
  echo "2. Set nim_path in niuv.toml to point to your Nim installation"
  echo "3. Allow system Nim with: allow_system_nim = true"
  return false