## Release script for niuv using nim-testkit
## Uses ntk release commands for standardized release process

import std/[os, strutils, strformat, osproc]

proc runCommand(cmd: string): int =
  echo "Running: ", cmd
  result = execCmd(cmd)
  if result != 0:
    echo "Command failed with exit code: ", result

proc main() =
  echo "=== niuv Release Process ==="
  echo ""
  
  # Check if ntk is available
  if execCmd("ntk --version") != 0:
    echo "Error: nim-testkit (ntk) is not installed"
    echo "Please install it first: nimble install nim-testkit"
    quit(1)
  
  # Parse command line arguments
  let args = commandLineParams()
  if args.len == 0:
    echo """
Usage: nim r scripts/release.nim <command> [options]

Commands:
  check              Run pre-release checks
  prepare <type>     Prepare release (patch|minor|major|alpha|beta|rc)
  execute <type>     Execute full release process
  report             Generate release report

Examples:
  nim r scripts/release.nim check
  nim r scripts/release.nim prepare minor
  nim r scripts/release.nim execute patch --dry-run
"""
    quit(0)
  
  let command = args[0]
  var exitCode = 0
  
  # Load VCS configuration from niuv.toml
  var vcsOption = "--vcs=git"  # Default to git for niuv
  if fileExists("niuv.toml"):
    # Simple check for Jujutsu enablement
    let tomlContent = readFile("niuv.toml")
    if tomlContent.contains("enableJujutsu = true"):
      vcsOption = "--vcs=jujutsu"
      echo "Jujutsu support enabled in niuv.toml"
  
  case command
  of "check":
    echo "Running pre-release checks..."
    exitCode = runCommand(&"ntk release check --coverage=75 {vcsOption}")
    
  of "prepare":
    if args.len < 2:
      echo "Error: Release type required"
      echo "Usage: nim r scripts/release.nim prepare <type>"
      quit(1)
    
    let releaseType = args[1]
    echo &"Preparing {releaseType} release..."
    exitCode = runCommand(&"ntk release prepare {releaseType} {vcsOption}")
    
  of "execute":
    if args.len < 2:
      echo "Error: Release type required"
      echo "Usage: nim r scripts/release.nim execute <type>"
      quit(1)
    
    let releaseType = args[1]
    var cmd = &"ntk release execute {releaseType} {vcsOption}"
    
    # Check for dry-run
    if args.len > 2 and args[2] == "--dry-run":
      cmd.add(" --dry-run")
    
    echo &"Executing {releaseType} release..."
    exitCode = runCommand(cmd)
    
  of "report":
    echo "Generating release report..."
    exitCode = runCommand(&"ntk release report {vcsOption}")
    
  else:
    echo "Unknown command: ", command
    exitCode = 1
  
  if exitCode == 0:
    echo "\n✅ Release process completed successfully"
  else:
    echo "\n❌ Release process failed"
  
  quit(exitCode)

when isMainModule:
  main()