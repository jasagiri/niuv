## Nimble adapter for niuv
## Delegates package registry operations to nimble while providing enhanced functionality

import std/[os, osproc, strutils, sequtils, json, tables, re]
import base
import ../utils

type
  PackageInfo* = object
    name*: string
    url*: string
    description*: string
    version*: string
    license*: string
    tags*: seq[string]
    
  SearchResult* = object
    packages*: seq[PackageInfo]
    total*: int
    
  PublishResult* = object
    success*: bool
    packageUrl*: string
    message*: string

proc parseNimbleSearch(output: string): seq[PackageInfo] =
  ## Parse nimble search output
  result = @[]
  var currentPkg: PackageInfo
  var inPackage = false
  
  for line in output.splitLines():
    if line.match(re"^(\w+).*:$"):
      if inPackage and currentPkg.name != "":
        result.add(currentPkg)
      currentPkg = PackageInfo()
      currentPkg.name = line.split(":")[0].strip()
      inPackage = true
    elif inPackage and line.startsWith("  url:"):
      currentPkg.url = line.split(":", 1)[1].strip().strip(chars = {'"'})
    elif inPackage and line.startsWith("  description:"):
      currentPkg.description = line.split(":", 1)[1].strip().strip(chars = {'"'})
  
  if inPackage and currentPkg.name != "":
    result.add(currentPkg)

proc searchPackages*(config: DelegationConfig, query: string, options: Table[string, string] = initTable[string, string]()): DelegateResult[SearchResult] =
  ## Search for packages using nimble
  config.delegateOr(dcPackageSearch):
    var args = @["search"]
    
    # Add search options
    if "tag" in options:
      args.add("--tag=" & options["tag"])
    
    args.add(query)
    
    result = delegate.executeDelegate(args, proc(output: string): SearchResult =
      let packages = parseNimbleSearch(output)
      SearchResult(packages: packages, total: packages.len)
    )
  do:
    # Fallback: Return empty results
    result = DelegateResult[SearchResult](
      success: true,
      value: SearchResult(packages: @[], total: 0),
      usedDelegate: "none",
      error: "Package search requires nimble"
    )

proc publishPackage*(config: DelegationConfig, packagePath: string, options: Table[string, string] = initTable[string, string]()): DelegateResult[PublishResult] =
  ## Publish a package using nimble
  config.delegateOr(dcPackagePublish):
    var args = @["publish"]
    
    # Handle authentication if provided
    if "token" in options:
      putEnv("NIMBLE_TOKEN", options["token"])
    
    result = delegate.executeDelegate(args, proc(output: string): PublishResult =
      if output.contains("successfully"):
        PublishResult(
          success: true,
          message: output,
          packageUrl: "" # Extract from output if available
        )
      else:
        PublishResult(
          success: false,
          message: output
        )
    )
  do:
    # Fallback: Cannot publish without nimble
    result = DelegateResult[PublishResult](
      success: false,
      error: "Package publishing requires nimble",
      usedDelegate: "none"
    )

proc getPackageMetadata*(config: DelegationConfig, packageName: string): DelegateResult[JsonNode] =
  ## Get package metadata using nimble dump
  config.delegateOr(dcPackageMetadata):
    let args = @["dump", packageName]
    
    result = delegate.executeDelegate(args, proc(output: string): JsonNode =
      # Parse nimble dump output (ini-like format) to JSON
      result = newJObject()
      for line in output.splitLines():
        if "=" in line:
          let parts = line.split("=", 1)
          let key = parts[0].strip()
          let value = parts[1].strip().strip(chars = {'"'})
          
          case key
          of "requires":
            if "requires" notin result:
              result["requires"] = newJArray()
            result["requires"].add(newJString(value))
          else:
            result[key] = newJString(value)
    )
  do:
    # Fallback: Try to read .nimble file directly
    let nimbleFile = packageName & ".nimble"
    if fileExists(nimbleFile):
      # Parse .nimble file
      result = DelegateResult[JsonNode](
        success: true,
        value: %* {"name": packageName, "source": "local"},
        usedDelegate: "native"
      )
    else:
      result = DelegateResult[JsonNode](
        success: false,
        error: "Cannot get metadata without nimble",
        usedDelegate: "none"
      )

proc refreshPackages*(config: DelegationConfig): DelegateResult[bool] =
  ## Refresh package list using nimble
  config.delegateOr(dcPackageMetadata):
    let args = @["refresh"]
    
    result = delegate.executeDelegate(args, proc(output: string): bool =
      output.contains("successfully") or output.contains("Done")
    )
  do:
    # Fallback: Nothing to refresh without registry
    result = DelegateResult[bool](
      success: true,
      value: false,
      usedDelegate: "none",
      error: "Package refresh requires nimble"
    )

proc executeTasks*(config: DelegationConfig, tasks: seq[string], options: Table[string, string] = initTable[string, string]()): DelegateResult[seq[string]] =
  ## Execute nimble tasks
  config.delegateOr(dcTaskExecution):
    var outputs: seq[string] = @[]
    
    for task in tasks:
      var args = @[task]
      
      # Add task-specific options
      if "args" in options:
        args.add(options["args"].split(" "))
      
      let taskResult = delegate.executeDelegate(args, proc(output: string): string = output)
      if taskResult.success:
        outputs.add(taskResult.value)
      else:
        return DelegateResult[seq[string]](
          success: false,
          error: "Task " & task & " failed: " & taskResult.error,
          usedDelegate: delegate.name
        )
    
    result = DelegateResult[seq[string]](
      success: true,
      value: outputs,
      usedDelegate: delegate.name
    )
  do:
    # Fallback: Parse and execute tasks from .nimble file
    result = DelegateResult[seq[string]](
      success: false,
      error: "Task execution requires nimble or custom implementation",
      usedDelegate: "none"
    )

proc validatePackage*(config: DelegationConfig, packagePath: string): DelegateResult[seq[string]] =
  ## Validate package structure using nimble check
  config.delegateOr(dcPackageMetadata):
    let args = @["check"]
    
    result = delegate.executeDelegate(args, proc(output: string): seq[string] =
      # Parse validation errors/warnings
      result = @[]
      for line in output.splitLines():
        if line.contains("Error:") or line.contains("Warning:"):
          result.add(line)
    )
  do:
    # Fallback: Basic validation
    var issues: seq[string] = @[]
    
    # Check for .nimble file
    let nimbleFiles = toSeq(walkFiles("*.nimble"))
    if nimbleFiles.len == 0:
      issues.add("Error: No .nimble file found")
    elif nimbleFiles.len > 1:
      issues.add("Warning: Multiple .nimble files found")
    
    # Check for src directory
    if not dirExists("src"):
      issues.add("Warning: No src directory found")
    
    result = DelegateResult[seq[string]](
      success: true,
      value: issues,
      usedDelegate: "native"
    )