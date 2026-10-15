## VCS integration for niuv delegation system
## Integrates patterns from mcp-jujutsu and nim-testkit for VCS operations

import std/[os, osproc, strutils, tables, options, sequtils]
import base
import ../utils

type
  VCSType* = enum
    ## Supported VCS types
    vcsNone = "none"
    vcsGit = "git"
    vcsJujutsu = "jujutsu"
    vcsMercurial = "mercurial"
    vcsSVN = "subversion"
    vcsFossil = "fossil"

  VCSInfo* = object
    ## Information about a detected VCS
    vcsType*: VCSType
    rootDir*: string
    executable*: string
    version*: string
    features*: seq[string]
    available*: bool

  VCSConfig* = object
    ## VCS configuration for niuv
    primary*: VCSInfo
    fallback*: Option[VCSInfo]
    preferredType*: VCSType

  VCSCapability* = enum
    ## VCS-specific capabilities
    vcCommit = "commit"
    vcTag = "tag"
    vcBranch = "branch"
    vcStatus = "status"
    vcDiff = "diff"
    vcLog = "log"
    vcClone = "clone"
    vcPush = "push"
    vcPull = "pull"
    vcMerge = "merge"
    vcRelease = "release"

# VCS detection patterns from nim-testkit
proc detectVCSInDirectory*(dir: string): VCSType =
  ## Detect VCS type in a directory
  if dirExists(dir / ".git"):
    return vcsGit
  elif dirExists(dir / ".jj"):
    return vcsJujutsu
  elif dirExists(dir / ".hg"):
    return vcsMercurial
  elif dirExists(dir / ".svn"):
    return vcsSVN
  elif dirExists(dir / ".fossil"):
    return vcsFossil
  else:
    return vcsNone

proc getVCSExecutable*(vcsType: VCSType): string =
  ## Get executable name for VCS type
  case vcsType
  of vcsGit: "git"
  of vcsJujutsu: "jj"
  of vcsMercurial: "hg"
  of vcsSVN: "svn"
  of vcsFossil: "fossil"
  of vcsNone: ""

proc detectVCSInfo*(vcsType: VCSType, rootDir: string = getCurrentDir()): VCSInfo =
  ## Detect VCS information
  result = VCSInfo(
    vcsType: vcsType,
    rootDir: rootDir,
    executable: getVCSExecutable(vcsType),
    available: false
  )
  
  if vcsType == vcsNone:
    return
  
  # Check if executable is available
  if not checkToolAvailable(result.executable):
    return
  
  result.available = true
  
  # Get version
  try:
    let (output, exitCode) = execCmdEx(result.executable & " --version")
    if exitCode == 0:
      result.version = output.strip().splitLines()[0]
  except:
    result.version = "unknown"
  
  # Set features based on VCS type
  case vcsType
  of vcsGit:
    result.features = @["commit", "tag", "branch", "status", "diff", "log", "clone", "push", "pull", "merge", "release"]
  of vcsJujutsu:
    result.features = @["commit", "tag", "branch", "status", "diff", "log", "clone", "push", "pull", "release"]
  of vcsMercurial:
    result.features = @["commit", "tag", "branch", "status", "diff", "log", "clone", "push", "pull"]
  of vcsSVN:
    result.features = @["commit", "status", "diff", "log", "checkout", "update"]
  of vcsFossil:
    result.features = @["commit", "tag", "branch", "status", "diff", "timeline"]
  of vcsNone:
    result.features = @[]

proc autoDetectVCS*(startDir: string = getCurrentDir()): VCSConfig =
  ## Auto-detect VCS configuration
  var currentDir = startDir
  var detectedType = vcsNone
  
  # Walk up directories to find VCS root
  while currentDir != currentDir.parentDir():
    detectedType = detectVCSInDirectory(currentDir)
    if detectedType != vcsNone:
      break
    currentDir = currentDir.parentDir()
  
  if detectedType == vcsNone:
    currentDir = startDir
  
  result.primary = detectVCSInfo(detectedType, currentDir)
  
  # Set preferred type (Jujutsu > Git > others)
  result.preferredType = if result.primary.available: result.primary.vcsType else: vcsJujutsu

proc setupVCSDelegation*(config: var DelegationConfig, vcsConfig: VCSConfig) =
  ## Setup VCS delegation in niuv config
  if vcsConfig.primary.available:
    let vcsDelegate = DelegateInfo(
      name: $vcsConfig.primary.vcsType,
      command: vcsConfig.primary.executable,
      version: vcsConfig.primary.version,
      capabilities: @[dcTaskExecution], # VCS operations via task execution
      available: true
    )
    config.delegates[$vcsConfig.primary.vcsType] = vcsDelegate

# VCS operation delegation patterns from mcp-jujutsu
proc executeVCSCommand*(vcsInfo: VCSInfo, args: seq[string], workDir: string = ""): tuple[output: string, exitCode: int] =
  ## Execute VCS command with error handling
  let actualWorkDir = if workDir == "": vcsInfo.rootDir else: workDir
  let cmd = vcsInfo.executable & " " & args.join(" ")
  
  try:
    result = execCmdEx(cmd, workingDir = actualWorkDir)
  except OSError as e:
    result = (output: "Error executing VCS command: " & e.msg, exitCode: 1)

proc delegateVCSOperation*(vcsConfig: VCSConfig, operation: string, args: seq[string] = @[]): DelegateResult[string] =
  ## Delegate a VCS operation
  if not vcsConfig.primary.available:
    return DelegateResult[string](
      success: false,
      error: "No VCS available",
      usedDelegate: "none"
    )
  
  let (output, exitCode) = executeVCSCommand(vcsConfig.primary, @[operation] & args)
  
  result = DelegateResult[string](
    success: exitCode == 0,
    value: if exitCode == 0: output else: "",
    error: if exitCode != 0: output else: "",
    usedDelegate: $vcsConfig.primary.vcsType
  )

# Release management integration patterns
proc isWorkspaceClean*(vcsConfig: VCSConfig): bool =
  ## Check if workspace has no uncommitted changes
  let result = delegateVCSOperation(vcsConfig, "status", @["--porcelain"])
  if result.success:
    return result.value.strip().len == 0
  return false

proc createReleaseBranch*(vcsConfig: VCSConfig, version: string): DelegateResult[string] =
  ## Create a release branch
  case vcsConfig.primary.vcsType
  of vcsGit:
    return delegateVCSOperation(vcsConfig, "checkout", @["-b", "release/" & version])
  of vcsJujutsu:
    return delegateVCSOperation(vcsConfig, "branch", @["create", "release/" & version])
  else:
    return DelegateResult[string](
      success: false,
      error: "Release branch creation not supported for " & $vcsConfig.primary.vcsType,
      usedDelegate: $vcsConfig.primary.vcsType
    )

proc tagRelease*(vcsConfig: VCSConfig, version: string, message: string = ""): DelegateResult[string] =
  ## Create a release tag
  let tagMessage = if message == "": "Release " & version else: message
  
  case vcsConfig.primary.vcsType
  of vcsGit:
    return delegateVCSOperation(vcsConfig, "tag", @["-a", version, "-m", tagMessage])
  of vcsJujutsu:
    return delegateVCSOperation(vcsConfig, "tag", @[version, "-m", tagMessage])
  else:
    return DelegateResult[string](
      success: false,
      error: "Release tagging not supported for " & $vcsConfig.primary.vcsType,
      usedDelegate: $vcsConfig.primary.vcsType
    )

# Workspace VCS coordination patterns from mcp-jujutsu multi-repo
proc getVCSStatus*(vcsConfig: VCSConfig): Table[string, string] =
  ## Get detailed VCS status information
  result = initTable[string, string]()
  
  result["vcs_type"] = $vcsConfig.primary.vcsType
  result["root_dir"] = vcsConfig.primary.rootDir
  result["executable"] = vcsConfig.primary.executable
  result["version"] = vcsConfig.primary.version
  
  if vcsConfig.primary.available:
    let statusResult = delegateVCSOperation(vcsConfig, "status")
    result["status"] = if statusResult.success: statusResult.value else: statusResult.error
    
    let currentResult = case vcsConfig.primary.vcsType
      of vcsGit: delegateVCSOperation(vcsConfig, "rev-parse", @["HEAD"])
      of vcsJujutsu: delegateVCSOperation(vcsConfig, "log", @["-r", "@", "--no-graph", "-T", "commit_id"])
      else: DelegateResult[string](success: false, error: "Not supported")
    
    if currentResult.success:
      result["current_commit"] = currentResult.value.strip()

# Template for integrating VCS operations into niuv commands
template withVCSIntegration*(body: untyped) =
  ## Template to setup VCS integration in niuv commands
  let vcsConfig {.inject.} = autoDetectVCS()
  var delegationConfig {.inject.} = loadDelegationConfig()
  setupVCSDelegation(delegationConfig, vcsConfig)
  body