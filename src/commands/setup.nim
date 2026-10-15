## Setup command for niuv
## Handles first-time setup and configuration

import std/[os, strutils, strformat, osproc]
import ../cli
import ../utils
import ../config

proc showSetupInstructions*() =
  ## Show setup instructions for first-time users
  echo """
[1m[32mniuv Setup Instructions[0m

niuv has been built successfully! To use it globally, you have several options:

[1m1. Local User Installation (Recommended)[0m
   Run: nimble installLocal
   This will create a symlink in ~/.local/bin/

[1m2. System-wide Installation[0m
   Run: sudo ln -s $(pwd)/niuv /usr/local/bin/niuv

[1m3. Add to PATH[0m
   Add this to your shell configuration:
   export PATH="$(pwd):$PATH"

[1m4. Create an Alias[0m
   Add this to your shell configuration:
   alias niuv="$(pwd)/niuv"

After installation, verify with: niuv version
"""

proc detectShell(): string =
  ## Detect user's shell
  let shell = getEnv("SHELL", "")
  if shell.contains("zsh"):
    return "zsh"
  elif shell.contains("bash"):
    return "bash"
  elif shell.contains("fish"):
    return "fish"
  else:
    return "unknown"

proc getShellConfigFile(shell: string): string =
  ## Get shell configuration file path
  case shell
  of "zsh":
    return expandTilde("~/.zshrc")
  of "bash":
    if fileExists(expandTilde("~/.bash_profile")):
      return expandTilde("~/.bash_profile")
    else:
      return expandTilde("~/.bashrc")
  of "fish":
    return expandTilde("~/.config/fish/config.fish")
  else:
    return ""

proc setupCommand*(args: seq[string]): int =
  ## Main setup command
  if "--help" in args or "-h" in args:
    echo """
niuv setup - Configure niuv for your system

Usage:
  niuv setup [options]

Options:
  --config       Create global configuration file
  --shell        Setup shell integration
  --help, -h     Show this help

Examples:
  niuv setup                # Full setup wizard
  niuv setup --config       # Create global config only
  niuv setup --shell        # Setup shell integration only
"""
    return 0
  
  var setupConfig = false
  var setupShell = false
  
  # Parse arguments
  if args.len == 0:
    # No arguments, do full setup
    setupConfig = true
    setupShell = true
  else:
    for arg in args:
      case arg
      of "--config":
        setupConfig = true
      of "--shell":
        setupShell = true
  
  # Setup global configuration
  if setupConfig:
    echo "[1m[36mSetting up global configuration...[0m"
    let configPath = getGlobalConfigPath()
    
    if fileExists(configPath):
      echo &"✓ Global config already exists at: {configPath}"
    else:
      let result = createDefaultGlobalConfig()
      if result.ok:
        echo &"✓ Created global config at: {result.value}"
        echo ""
        echo "Default configuration includes:"
        echo "  - TestKit coverage enabled by default"
        echo "  - Coverage threshold: 80%"
        echo "  - Coverage formats: HTML, JSON"
        echo ""
        echo "You can edit this file to customize your settings."
      else:
        echo &"✗ Failed to create config: {result.error}"
        return 1
  
  # Setup shell integration
  if setupShell:
    echo ""
    echo "[1m[36mSetting up shell integration...[0m"
    
    # Check if niuv is already in PATH
    let niuvPath = findExe("niuv")
    if niuvPath != "":
      echo &"✓ niuv is already available at: {niuvPath}"
      let currentVersion = execCmdEx("niuv version")
      if currentVersion[1] == 0:
        echo currentVersion[0].strip()
    else:
      # Not in PATH, show setup options
      echo "[1m[33mniuv is not in your PATH[0m"
      echo ""
      showSetupInstructions()
      
      # Detect shell and suggest configuration
      let shell = detectShell()
      if shell != "unknown":
        let configFile = getShellConfigFile(shell)
        if configFile != "":
          echo &"\nDetected shell: {shell}"
          echo &"Configuration file: {configFile}"
  
  # Show final message
  if setupConfig or setupShell:
    echo ""
    echo "[1m[32mSetup complete![0m"
    echo ""
    echo "You can now use niuv with TestKit coverage enabled by default."
    echo "To override coverage settings, you can:"
    echo "  1. Edit the global config at: " & getGlobalConfigPath()
    echo "  2. Set NIUV_TESTKIT_COVERAGE=false environment variable"
    echo "  3. Use --no-coverage flag when running tests"
  
  return 0