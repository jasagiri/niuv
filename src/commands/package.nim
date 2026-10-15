## Package management commands for niuv
## Provides nimble-compatible package operations with delegation

import std/[os, strutils, sequtils, tables, json]
import ../utils
import ../config  
import ../cli
import ../delegation/[base, nimble_adapter]

type
  PackageCommand* = enum
    pcSearch = "search"
    pcPublish = "publish"
    pcDevelop = "develop"
    pcPath = "path"
    pcDump = "dump"
    pcRefresh = "refresh"
    pcCheck = "check"
    pcUninstall = "uninstall"

proc searchCommand*(args: seq[string]): int =
  ## Search for packages
  if args.len == 0 or "--help" in args:
    echo """
niuv search - Search for Nim packages

Usage:
  niuv search <query> [options]

Options:
  --tag <tag>     Filter by tag
  --help, -h      Show this help

Examples:
  niuv search json           # Search for json packages
  niuv search web --tag http # Search web packages with http tag
"""
    return 0
  
  let config = loadDelegationConfig()
  let query = args[0]
  var options = initTable[string, string]()
  
  # Parse options
  var i = 1
  while i < args.len:
    if args[i] == "--tag" and i + 1 < args.len:
      options["tag"] = args[i + 1]
      inc i, 2
    else:
      inc i
  
  let result = config.searchPackages(query, options)
  
  if result.success:
    if result.value.packages.len == 0:
      showInfo("No packages found matching: " & query)
    else:
      echo "Found ", result.value.total, " packages:"
      echo ""
      for pkg in result.value.packages:
        echo pkg.name
        if pkg.description != "":
          echo "  ", pkg.description
        if pkg.url != "":
          echo "  URL: ", pkg.url
        echo ""
  else:
    showError("Search failed: " & result.error)
    return 1
  
  return 0

proc publishCommand*(args: seq[string]): int =
  ## Publish a package
  if "--help" in args:
    echo """
niuv publish - Publish a package to the Nim package registry

Usage:
  niuv publish [options]

Options:
  --token <token>   Authentication token
  --dry-run         Validate without publishing
  --help, -h        Show this help

Examples:
  niuv publish                    # Publish current package
  niuv publish --dry-run          # Validate package
"""
    return 0
  
  let config = loadDelegationConfig()
  var options = initTable[string, string]()
  
  # Parse options
  var dryRun = false
  var i = 0
  while i < args.len:
    case args[i]
    of "--token":
      if i + 1 < args.len:
        options["token"] = args[i + 1]
        inc i
    of "--dry-run":
      dryRun = true
    inc i
  
  if dryRun:
    # Just validate
    let validateResult = config.validatePackage(getCurrentDir())
    if validateResult.success:
      if validateResult.value.len == 0:
        showSuccess("Package validation passed")
      else:
        showWarning("Package validation issues:")
        for issue in validateResult.value:
          echo "  ", issue
    else:
      showError("Package validation failed: " & validateResult.error)
      return 1
  else:
    let result = config.publishPackage(getCurrentDir(), options)
    if result.success:
      showSuccess("Package published successfully")
      if result.value.packageUrl != "":
        echo "Package URL: ", result.value.packageUrl
    else:
      showError("Publish failed: " & result.error)
      return 1
  
  return 0

proc developCommand*(args: seq[string]): int =
  ## Link a package for development
  if args.len == 0 or "--help" in args:
    echo """
niuv develop - Link a package for development

Usage:
  niuv develop <path> [options]

Options:
  --global        Install globally
  --help, -h      Show this help

Examples:
  niuv develop ../mylib          # Link local package
  niuv develop . --global        # Link current directory globally
"""
    return 0
  
  let path = args[0]
  let globalInstall = "--global" in args
  
  # Create symlink in deps directory
  let targetPath = expandFilename(path)
  if not dirExists(targetPath):
    showError("Directory not found: " & path)
    return 1
  
  # Find package name from .nimble file
  let nimbleFiles = toSeq(walkFiles(targetPath / "*.nimble"))
  if nimbleFiles.len == 0:
    showError("No .nimble file found in: " & path)
    return 1
  
  let packageName = nimbleFiles[0].splitFile.name
  let depsDir = if globalInstall: getHomeDir() / ".nimble" / "pkgs" else: ".niuv" / "deps"
  let linkPath = depsDir / packageName
  
  createDir(depsDir)
  
  # Remove existing link/directory
  if symlinkExists(linkPath) or dirExists(linkPath):
    removeDir(linkPath)
  
  # Create symlink
  createSymlink(targetPath, linkPath)
  showSuccess("Linked " & packageName & " for development")
  echo "  Source: ", targetPath
  echo "  Link: ", linkPath
  
  return 0

proc pathCommand*(args: seq[string]): int =
  ## Show package paths
  if "--help" in args:
    echo """
niuv path - Show package installation paths

Usage:
  niuv path [package]

Options:
  --help, -h      Show this help

Examples:
  niuv path              # Show all package paths
  niuv path json         # Show path for json package
"""
    return 0
  
  let depsDir = ".niuv" / "deps"
  let globalDir = getHomeDir() / ".nimble" / "pkgs"
  
  if args.len > 0:
    # Show specific package path
    let packageName = args[0]
    
    # Check local first
    let localPath = depsDir / packageName
    if dirExists(localPath):
      echo localPath
      return 0
    
    # Check global
    for dir in walkDirs(globalDir / packageName & "*"):
      echo dir
      return 0
    
    showError("Package not found: " & packageName)
    return 1
  else:
    # Show all paths
    echo "Package paths:"
    echo ""
    
    if dirExists(depsDir):
      echo "Local packages (.niuv/deps):"
      for dir in walkDirs(depsDir / "*"):
        echo "  ", dir.splitPath.tail
    
    if dirExists(globalDir):
      echo "\nGlobal packages (~/.nimble/pkgs):"
      for dir in walkDirs(globalDir / "*"):
        echo "  ", dir.splitPath.tail
  
  return 0

proc dumpCommand*(args: seq[string]): int =
  ## Dump package metadata
  if args.len == 0 or "--help" in args:
    echo """
niuv dump - Dump package metadata

Usage:
  niuv dump [package]

Options:
  --json          Output as JSON
  --help, -h      Show this help

Examples:
  niuv dump              # Dump current package
  niuv dump json         # Dump json package metadata
"""
    return 0
  
  let config = loadDelegationConfig()
  let packageName = if args.len > 0 and args[0] != "--json": args[0] else: ""
  let asJson = "--json" in args
  
  let result = config.getPackageMetadata(packageName)
  
  if result.success:
    if asJson:
      echo result.value.pretty()
    else:
      # Format as key=value
      for key, value in result.value.pairs:
        if value.kind == JString:
          echo key, " = \"", value.getStr, "\""
        elif value.kind == JArray:
          for item in value:
            echo key, " = \"", item.getStr, "\""
        else:
          echo key, " = ", value
  else:
    showError("Failed to get metadata: " & result.error)
    return 1
  
  return 0

proc refreshCommand*(args: seq[string]): int =
  ## Refresh package list
  if "--help" in args:
    echo """
niuv refresh - Refresh package list from registry

Usage:
  niuv refresh [options]

Options:
  --help, -h      Show this help
"""
    return 0
  
  let config = loadDelegationConfig()
  showInfo("Refreshing package list...")
  
  let result = config.refreshPackages()
  
  if result.success:
    if result.value:
      showSuccess("Package list refreshed successfully")
    else:
      showInfo("Package refresh not available without nimble")
  else:
    showError("Refresh failed: " & result.error)
    return 1
  
  return 0

proc checkCommand*(args: seq[string]): int =
  ## Validate package structure
  if "--help" in args:
    echo """
niuv check - Validate package structure

Usage:
  niuv check [options]

Options:
  --help, -h      Show this help
"""
    return 0
  
  let config = loadDelegationConfig()
  showInfo("Checking package structure...")
  
  let result = config.validatePackage(getCurrentDir())
  
  if result.success:
    if result.value.len == 0:
      showSuccess("Package structure is valid")
    else:
      showWarning("Found " & $result.value.len & " issues:")
      for issue in result.value:
        echo "  ", issue
      return 1
  else:
    showError("Check failed: " & result.error)
    return 1
  
  return 0

proc uninstallCommand*(args: seq[string]): int =
  ## Uninstall a package
  if args.len == 0 or "--help" in args:
    echo """
niuv uninstall - Uninstall a package

Usage:
  niuv uninstall <package> [options]

Options:
  --global        Uninstall from global packages
  --help, -h      Show this help

Examples:
  niuv uninstall json            # Uninstall json package
  niuv uninstall json --global   # Uninstall from global
"""
    return 0
  
  let packageName = args[0]
  let globalUninstall = "--global" in args
  
  let depsDir = if globalUninstall: getHomeDir() / ".nimble" / "pkgs" else: ".niuv" / "deps"
  
  # Find package directory
  var found = false
  for dir in walkDirs(depsDir / packageName & "*"):
    removeDir(dir)
    showSuccess("Uninstalled: " & dir.splitPath.tail)
    found = true
  
  if not found:
    showError("Package not found: " & packageName)
    return 1
  
  return 0

proc packageCommand*(command: string, args: seq[string]): int =
  ## Main package command dispatcher
  case command
  of "search":
    return searchCommand(args)
  of "publish":
    return publishCommand(args)
  of "develop":
    return developCommand(args)
  of "path":
    return pathCommand(args)
  of "dump":
    return dumpCommand(args)
  of "refresh":
    return refreshCommand(args)
  of "check":
    return checkCommand(args)
  of "uninstall":
    return uninstallCommand(args)
  else:
    showError("Unknown package command: " & command)
    return 1