## Base delegation framework for niuv
## Provides interfaces and utilities for delegating functionality to external tools

import std/[os, osproc, strutils, sequtils, json, tables, options]
import ../utils

type
  DelegateCapability* = enum
    ## Capabilities that can be delegated to external tools
    dcTestDiscovery = "test_discovery"
    dcTestExecution = "test_execution"
    dcCoverageAnalysis = "coverage_analysis"
    dcPackageSearch = "package_search"
    dcPackagePublish = "package_publish"
    dcPackageMetadata = "package_metadata"
    dcTaskExecution = "task_execution"
    dcBenchmarking = "benchmarking"
    dcDocGeneration = "doc_generation"

  DelegateInfo* = object
    ## Information about a delegate tool
    name*: string
    command*: string
    version*: string
    capabilities*: seq[DelegateCapability]
    available*: bool

  DelegationConfig* = object
    ## Configuration for delegation behavior
    enabled*: bool
    preferDelegation*: bool  # Prefer delegation over native implementation
    delegates*: Table[string, DelegateInfo]
    fallbackEnabled*: bool

  DelegateResult*[T] = object
    ## Result of a delegated operation
    success*: bool
    value*: T
    error*: string
    usedDelegate*: string

proc checkToolAvailable*(command: string): bool =
  ## Check if a tool is available in PATH
  try:
    let (output, exitCode) = execCmdEx(command & " --version")
    result = exitCode == 0
  except:
    result = false

proc detectDelegate*(name: string, command: string, capabilities: seq[DelegateCapability]): DelegateInfo =
  ## Detect if a delegate tool is available
  result = DelegateInfo(
    name: name,
    command: command,
    capabilities: capabilities,
    available: false
  )
  
  if checkToolAvailable(command):
    result.available = true
    try:
      let (output, _) = execCmdEx(command & " --version")
      result.version = output.strip()
    except:
      result.version = "unknown"

proc loadDelegationConfig*(configPath: string = ""): DelegationConfig =
  ## Load delegation configuration
  result = DelegationConfig(
    enabled: true,
    preferDelegation: true,
    fallbackEnabled: true,
    delegates: initTable[string, DelegateInfo]()
  )
  
  # Auto-detect common delegates
  let nimTestKit = detectDelegate(
    "nim-testkit",
    "nimtestkit",
    @[dcTestDiscovery, dcTestExecution, dcCoverageAnalysis, dcBenchmarking, dcDocGeneration]
  )
  if nimTestKit.available:
    result.delegates["nim-testkit"] = nimTestKit
  
  let nimble = detectDelegate(
    "nimble",
    "nimble",
    @[dcPackageSearch, dcPackagePublish, dcPackageMetadata, dcTaskExecution]
  )
  if nimble.available:
    result.delegates["nimble"] = nimble

proc findDelegate*(config: DelegationConfig, capability: DelegateCapability): Option[DelegateInfo] =
  ## Find a delegate that supports a specific capability
  for name, delegate in config.delegates:
    if delegate.available and capability in delegate.capabilities:
      return some(delegate)
  return none(DelegateInfo)

proc executeDelegate*[T](delegate: DelegateInfo, args: seq[string], parser: proc(output: string): T): DelegateResult[T] =
  ## Execute a delegated command and parse the result
  try:
    let cmd = delegate.command & " " & args.join(" ")
    let (output, exitCode) = execCmdEx(cmd)
    
    if exitCode == 0:
      result.success = true
      result.value = parser(output)
      result.usedDelegate = delegate.name
    else:
      result.success = false
      result.error = output
      result.usedDelegate = delegate.name
  except Exception as e:
    result.success = false
    result.error = e.msg
    result.usedDelegate = delegate.name

# Convenience templates for common delegation patterns
template delegateOr*(config: DelegationConfig, capability: DelegateCapability, delegateBody, fallbackBody: untyped) =
  ## Delegate to external tool or use fallback implementation
  if config.enabled:
    let delegateOpt = config.findDelegate(capability)
    if delegateOpt.isSome:
      let delegate {.inject.} = delegateOpt.get
      delegateBody
    elif config.fallbackEnabled:
      fallbackBody
    else:
      raise newException(ValueError, "No delegate available for " & $capability & " and fallback disabled")
  else:
    fallbackBody

template tryDelegate*(config: DelegationConfig, capability: DelegateCapability, delegateBody: untyped): bool =
  ## Try to delegate, return true if successful
  if config.enabled:
    let delegateOpt = config.findDelegate(capability)
    if delegateOpt.isSome:
      let delegate {.inject.} = delegateOpt.get
      delegateBody
      true
    else:
      false
  else:
    false