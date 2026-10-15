#!/usr/bin/env nim
## Enhanced niuv with PATH-independent installation and auto-setup
import std/[os, strutils, terminal, osproc]
import ./src/installation/auto_installer
import ./src/project/auto_setup

const
  NIUV_VERSION = "1.0.0-enhanced"

proc showVersion() =
  styledEcho(styleBright, fgGreen, "Enhanced niuv version ", NIUV_VERSION)
  echo ""
  echo "New Enhanced Features:"
  echo "  ✅ PATH-independent installation with shell detection"
  echo "  ✅ Automatic project configuration generation"
  echo "  ✅ Cross-platform installation methods"
  echo "  ✅ Robust wrapper script generation"
  echo "  ✅ Project type detection (Library/App/Framework/Service/Tool)"
  echo ""

proc showHelp() =
  styledEcho(styleBright, fgGreen, "Enhanced niuv - Nim Virtual Environment Manager with PATH Solutions")
  echo ""
  echo "Enhanced Commands:"
  echo "  install-self [options]     Auto-install niuv to system PATH with robust wrapper"
  echo "  auto-setup [options]       Auto-configure niuv.toml for current project"
  echo "  version                    Show enhanced version information"
  echo "  help                       Show this help"
  echo ""
  echo "Key Features:"
  echo "  • Solves PATH command not found issues (dirname, mkdir)"
  echo "  • Works transparently across all projects"
  echo "  • Automatic shell configuration (bash, zsh, fish, tcsh)"
  echo "  • Project type detection and optimal configuration"
  echo ""
  echo "For detailed help: niuv <command> --help"

proc main() =
  if paramCount() < 1:
    showHelp()
    quit(0)

  let command = paramStr(1)
  var args = commandLineParams()
  args.delete(0)

  case command:
  of "version":
    showVersion()
  of "help", "--help", "-h":
    showHelp()
  of "install-self":
    let result = installSelfCommand(args)
    quit(result)
  of "auto-setup":
    let result = autoSetupCommand(args)
    quit(result)
  else:
    echo "Enhanced niuv - Command: '", command, "' not implemented in this demo version"
    echo ""
    echo "Available enhanced commands:"
    echo "  niuv install-self  # Auto-install with PATH solution"
    echo "  niuv auto-setup    # Auto-configure project"
    echo "  niuv version       # Show version"
    echo "  niuv help          # Show help"
    echo ""
    echo "This demonstrates the enhanced features that solve the PATH problems"
    echo "and provide automatic project configuration."
    quit(1)

when isMainModule:
  main()