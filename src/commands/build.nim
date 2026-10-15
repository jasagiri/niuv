## Build command implementation for niuv
## Provides basic build functionality with fallback to nimble

import std/[os, osproc, strutils, parseopt]
import ../cli, ../env, ../utils

type
  BuildOptions* = object
    release*: bool
    debug*: bool
    target*: string
    output*: string
    verbose*: bool
    force*: bool

proc parseBuildOptions*(args: seq[string]): BuildOptions =
  ## Parse build command options
  result = BuildOptions()
  
  var parser = initOptParser(args)
  for kind, key, val in parser.getopt():
    case kind
    of cmdArgument:
      if result.target == "":
        result.target = key
    of cmdLongOption, cmdShortOption:
      case key
      of "release", "r":
        result.release = true
      of "debug", "d":
        result.debug = true
      of "output", "o":
        result.output = val
      of "verbose", "v":
        result.verbose = true
      of "force", "f":
        result.force = true
      else:
        cli.showWarning("Unknown build option: " & key)
    of cmdEnd:
      break

proc findMainFile(): string =
  ## Find the main source file to build
  # Try common patterns
  let candidates = [
    "src/main.nim",
    "main.nim", 
    "src/" & getCurrentDir().lastPathPart() & ".nim",
    getCurrentDir().lastPathPart() & ".nim"
  ]
  
  for candidate in candidates:
    if fileExists(candidate):
      return candidate
  
  # Look for .nimble file to get binary info
  for file in walkFiles("*.nimble"):
    let content = readFile(file)
    for line in content.splitLines():
      if line.strip().startsWith("bin"):
        # Extract binary name and try to find source
        let parts = line.split("=")
        if parts.len > 1:
          let binName = parts[1].strip().strip(chars = {'"', '\''})
          let srcFile = "src/" & binName & ".nim"
          if fileExists(srcFile):
            return srcFile
  
  return ""

proc buildWithNim(options: BuildOptions): bool =
  ## Build using nim compiler directly
  let mainFile = findMainFile()
  if mainFile == "":
    cli.showError("Could not find main source file to build")
    return false
  
  var cmd = utils.getNimCommand() & " c"
  
  # Add build flags
  if options.release:
    cmd.add(" -d:release --opt:speed")
  elif options.debug:
    cmd.add(" -d:debug --debuginfo")
  
  # Add output specification
  if options.output != "":
    cmd.add(" -o:" & options.output)
  else:
    # Default output to .build directory
    createDir(".build")
    let binName = mainFile.extractFilename().changeFileExt("")
    cmd.add(" -o:.build/" & binName)
  
  cmd.add(" " & mainFile)
  
  if options.verbose:
    echo "Building with: " & cmd
  
  let (output, exitCode) = execCmdEx(cmd)
  
  if exitCode != 0:
    cli.showError("Build failed:")
    echo output
    return false
  else:
    if options.verbose:
      echo output
    cli.showSuccess("Build completed successfully")
    return true

proc buildWithNimble(options: BuildOptions): bool =
  ## Build using nimble (fallback method)
  var cmd = "nimble build"
  
  if options.verbose:
    cmd.add(" --verbose")
  
  if options.verbose:
    echo "Building with nimble: " & cmd
  
  let (output, exitCode) = execCmdEx(cmd)
  
  if exitCode != 0:
    cli.showError("Nimble build failed:")
    echo output
    return false
  else:
    if options.verbose:
      echo output
    cli.showSuccess("Build completed successfully")
    return true

proc buildCommand*(args: seq[string]): bool =
  ## Main build command handler
  let options = parseBuildOptions(args)
  
  # Try nim compiler first, fallback to nimble
  if not buildWithNim(options):
    cli.showWarning("Nim build failed, trying nimble...")
    return buildWithNimble(options)
  
  return true