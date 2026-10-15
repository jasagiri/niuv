## Nim compiler detection module
## Searches for Nim compiler in multiple locations with fallback support

import os, strutils, osproc, sequtils, tables, algorithm

type
  NimCompilerInfo* = object
    path*: string
    version*: string
    isValid*: bool
    source*: string  # Where it was found: "path", "choosenim", "system", etc.

const
  CommonNimPaths = @[
    # Linux/Unix common paths
    "/usr/local/bin/nim",
    "/usr/bin/nim",
    "/opt/nim/bin/nim",
    "/opt/local/bin/nim",
    # Home directory installations
    "~/.nimble/bin/nim",
    # Note: choosenim paths are handled separately in findNimViaChoosenim
    "~/.local/bin/nim",
    # macOS specific
    "/opt/homebrew/bin/nim",
    "/usr/local/opt/nim/bin/nim",
    # Windows common paths
    "C:\\nim\\bin\\nim.exe",
    "C:\\tools\\nim\\bin\\nim.exe",
    "C:\\Program Files\\nim\\bin\\nim.exe",
    # Snap installation
    "/snap/nim/current/bin/nim"
  ]

proc expandPath(path: string): string =
  ## Expand ~ and environment variables in path
  result = path
  if result.startsWith("~"):
    result = getHomeDir() & result[1..^1]
  # Don't use expandFilename on paths that might not exist
  result = result.normalizedPath()

proc checkNimExecutable(path: string): NimCompilerInfo =
  ## Check if a path points to a valid Nim executable
  result = NimCompilerInfo(path: path, isValid: false)
  
  let expandedPath = expandPath(path)
  if not fileExists(expandedPath):
    return result
  
  try:
    let (output, exitCode) = execCmdEx(expandedPath & " --version")
    if exitCode == 0:
      result.isValid = true
      result.path = expandedPath
      # Extract version from output
      for line in output.splitLines():
        if "Nim Compiler Version" in line:
          let parts = line.split(" ")
          for i, part in parts:
            if part == "Version":
              if i + 1 < parts.len:
                result.version = parts[i + 1]
                break
          break
  except:
    discard

proc findNimInPath(): NimCompilerInfo =
  ## Try to find nim in system PATH
  result = NimCompilerInfo(isValid: false, source: "path")
  try:
    let (output, exitCode) = execCmdEx("which nim")
    if exitCode == 0:
      let nimPath = output.strip()
      result = checkNimExecutable(nimPath)
      if result.isValid:
        result.source = "path"
  except:
    discard

proc findNimViaChoosenim(): seq[NimCompilerInfo] =
  ## Find Nim installations managed by choosenim
  result = @[]
  try:
    # Check if choosenim is available
    let (_, choosenimExitCode) = execCmdEx("choosenim --version")
    if choosenimExitCode != 0:
      return
    
    # Get current version
    let (currentOutput, currentExitCode) = execCmdEx("choosenim show")
    if currentExitCode == 0:
      let currentPath = currentOutput.strip()
      if currentPath.len > 0:
        var info = checkNimExecutable(currentPath)
        if info.isValid:
          info.source = "choosenim-current"
          result.add(info)
    
    # List all installed versions
    let (versionsOutput, versionsExitCode) = execCmdEx("choosenim list")
    if versionsExitCode == 0:
      for line in versionsOutput.splitLines():
        let cleaned = line.strip()
        if cleaned.len > 0 and not cleaned.startsWith("*"):
          # Try to construct path for this version
          let versionPath = expandPath("~/.choosenim/toolchains/nim-" & cleaned & "/bin/nim")
          var info = checkNimExecutable(versionPath)
          if info.isValid:
            info.source = "choosenim-" & cleaned
            result.add(info)
  except:
    discard

proc findNimInCommonPaths(): seq[NimCompilerInfo] =
  ## Search for Nim in common installation paths
  result = @[]
  for path in CommonNimPaths:
    var info = checkNimExecutable(path)
    if info.isValid:
      info.source = "common-path"
      result.add(info)

proc findNimInEnvironment(): NimCompilerInfo =
  ## Check NIM_HOME or similar environment variables
  result = NimCompilerInfo(isValid: false)
  
  # Check NIM_HOME
  let nimHome = getEnv("NIM_HOME")
  if nimHome.len > 0:
    let nimPath = nimHome / "bin" / "nim"
    result = checkNimExecutable(nimPath)
    if result.isValid:
      result.source = "NIM_HOME"
      return
  
  # Check NIMBLE_DIR for nim installation
  let nimbleDir = getEnv("NIMBLE_DIR", expandPath("~/.nimble"))
  let nimbleBinPath = nimbleDir / "bin" / "nim"
  result = checkNimExecutable(nimbleBinPath)
  if result.isValid:
    result.source = "NIMBLE_DIR"

proc detectNimCompilers*(): seq[NimCompilerInfo] =
  ## Detect all available Nim compilers on the system
  result = @[]
  
  # 1. Check system PATH first
  let pathNim = findNimInPath()
  if pathNim.isValid:
    result.add(pathNim)
  
  # 2. Check environment variables
  let envNim = findNimInEnvironment()
  if envNim.isValid:
    result.add(envNim)
  
  # 3. Check choosenim installations
  let choosenimNims = findNimViaChoosenim()
  for nim in choosenimNims:
    result.add(nim)
  
  # 4. Check common paths
  let commonNims = findNimInCommonPaths()
  for nim in commonNims:
    # Avoid duplicates
    var isDuplicate = false
    for existing in result:
      if existing.path == nim.path:
        isDuplicate = true
        break
    if not isDuplicate:
      result.add(nim)
  
  # Sort by version (newest first)
  result.sort(proc(a, b: NimCompilerInfo): int =
    if a.version > b.version: -1
    elif a.version < b.version: 1
    else: 0
  )

proc selectBestNimCompiler*(): NimCompilerInfo =
  ## Select the best available Nim compiler
  let compilers = detectNimCompilers()
  
  if compilers.len == 0:
    return NimCompilerInfo(isValid: false)
  
  # Prefer in this order:
  # 1. System PATH nim
  # 2. choosenim current
  # 3. Environment variable nim
  # 4. Newest version
  
  for compiler in compilers:
    if compiler.source == "path":
      return compiler
  
  for compiler in compilers:
    if compiler.source == "choosenim-current":
      return compiler
  
  for compiler in compilers:
    if compiler.source in ["NIM_HOME", "NIMBLE_DIR"]:
      return compiler
  
  # Return newest version
  return compilers[0]

proc getNimCommand*(preferredPath: string = ""): string =
  ## Get the nim command to use, with optional preferred path
  if preferredPath.len > 0:
    let info = checkNimExecutable(preferredPath)
    if info.isValid:
      return info.path
  
  let best = selectBestNimCompiler()
  if best.isValid:
    return best.path
  
  # Fallback to "nim" and hope it's in PATH
  return "nim"

when isMainModule:
  echo "Detecting Nim compilers..."
  let compilers = detectNimCompilers()
  
  if compilers.len == 0:
    echo "No Nim compiler found!"
  else:
    echo "Found ", compilers.len, " Nim compiler(s):"
    for i, compiler in compilers:
      echo "  ", i + 1, ". ", compiler.path
      echo "     Version: ", compiler.version
      echo "     Source: ", compiler.source
    
    echo "\nBest compiler:"
    let best = selectBestNimCompiler()
    if best.isValid:
      echo "  Path: ", best.path
      echo "  Version: ", best.version
      echo "  Source: ", best.source