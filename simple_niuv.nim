#!/usr/bin/env nim
## Simplified niuv build that focuses on the enhanced features
import std/[os, strutils, terminal, times, osproc, parsecfg, sequtils]
import ./src/deps, ./src/env, ./src/install, ./src/utils, ./src/cli
import ./src/testing/[niuv_testing, test_coverage]
import ./src/commands/[build, task, package]
import ./src/installation/auto_installer
import ./src/project/auto_setup

const
  NIUV_VERSION = "1.0.0-enhanced"

proc showVersion() =
  echo "Enhanced niuv version ", NIUV_VERSION
  echo "Features:"
  echo "  ✅ PATH-independent installation (install-self)"
  echo "  ✅ Automatic project configuration (auto-setup)"
  echo "  ✅ Shell detection and wrapper generation"
  echo "  ✅ Cross-platform installation support"

proc showHelp() =
  echo "Enhanced niuv - Nim Virtual Environment Manager"
  echo ""
  echo "Core Commands:"
  echo "  install-self [options]     Auto-install niuv to system PATH"
  echo "  auto-setup [options]       Auto-configure niuv.toml for project"
  echo "  version                    Show version information"
  echo "  help                       Show this help"
  echo ""
  echo "Standard Commands:"
  echo "  init                       Initialize environment"
  echo "  install                    Install dependencies"
  echo "  build                      Build project"
  echo "  test                       Run tests"
  echo "  add <package>              Add dependency"
  echo "  remove <package>           Remove dependency"
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
  of "init":
    var options: CliOptions
    parseOptions(args, options)
    let success = initializeEnvironment(options)
    quit(if success: 0 else: 1)
  of "install":
    var options: CliOptions
    parseOptions(args, options)
    let success = installPackages(options)
    quit(if success: 0 else: 1)
  of "build":
    let success = buildCommand(args)
    quit(if success: 0 else: 1)
  of "test":
    # Simple test runner
    let testFiles = @["tests/test_all.nim"]
    var allPassed = true
    for testFile in testFiles:
      if fileExists(testFile):
        echo "Running: ", testFile
        let (output, exitCode) = execCmdEx("nim c -r " & testFile)
        if exitCode != 0:
          echo "FAILED: ", testFile
          echo output
          allPassed = false
        else:
          echo "PASSED: ", testFile
    quit(if allPassed: 0 else: 1)
  of "add":
    if args.len == 0:
      echo "Error: Package name required"
      quit(1)
    let success = addPackage(args[0])
    quit(if success: 0 else: 1)
  of "remove":
    if args.len == 0:
      echo "Error: Package name required"
      quit(1)
    let success = removePackage(args[0])
    quit(if success: 0 else: 1)
  of "task":
    let result = taskCommand(args)
    quit(result)
  else:
    echo "Unknown command: ", command
    echo "Run 'niuv help' for available commands"
    quit(1)

when isMainModule:
  main()