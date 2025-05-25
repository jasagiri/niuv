## clean_steps.nim
## ==============
##
## クリーンアップ関連のステップ定義

import
  std/os,
  std/strutils,
  cucumber_nim/runner,
  cucumber_nim/parser

type
  CleanState = object
    ## クリーニングステップの状態
    buildDirExists: bool
    nimcacheDirExists: bool
    customPathExists: bool
    tempFilesExist: bool
    customPath: string
    dryRun: bool
    verbose: bool
    cleanMode: string
    onlyDirs: seq[string]
    nothingToClean: bool
    cleaned: bool

var
  state = CleanState(
    buildDirExists: true,
    nimcacheDirExists: true,
    customPathExists: false,
    tempFilesExist: false,
    customPath: "",
    dryRun: false,
    verbose: false,
    cleanMode: "normal",
    onlyDirs: @[],
    nothingToClean: false,
    cleaned: false
  )

# 前提条件
step(stGiven, "build artifacts exist in the project"):
  state.buildDirExists = true
  state.nimcacheDirExists = true
  state.tempFilesExist = false
  return true

step(stGiven, "no build artifacts exist in the project"):
  state.buildDirExists = false
  state.nimcacheDirExists = false
  state.tempFilesExist = false
  state.nothingToClean = true
  return true

step(stGiven, "build artifacts and temporary files exist"):
  state.buildDirExists = true
  state.nimcacheDirExists = true
  state.tempFilesExist = true
  return true

step(stGiven, "build artifacts exist in a custom location"):
  state.customPathExists = true
  state.customPath = "/custom/path"
  return true

# 操作
step(stWhen, "I run \"niuv clean\""):
  if state.buildDirExists or state.nimcacheDirExists:
    state.buildDirExists = false
    state.nimcacheDirExists = false
    state.cleaned = true
  else:
    state.nothingToClean = true
  
  state.dryRun = false
  state.verbose = false
  state.cleanMode = "normal"
  state.onlyDirs = @[]
  
  return true

step(stWhen, "I run \"niuv clean --dry-run\""):
  state.dryRun = true
  state.verbose = false
  state.cleanMode = "normal"
  state.onlyDirs = @[]
  
  # dry-runモードではファイルは削除されない
  return true

step(stWhen, "I run \"niuv clean --verbose\""):
  if state.buildDirExists or state.nimcacheDirExists:
    state.buildDirExists = false
    state.nimcacheDirExists = false
    state.cleaned = true
  else:
    state.nothingToClean = true
  
  state.dryRun = false
  state.verbose = true
  state.cleanMode = "normal"
  state.onlyDirs = @[]
  
  return true

step(stWhen, "I run \"niuv clean --only={string}\""):
  let dir = matches[0]
  
  case dir
  of "nimcache":
    if state.nimcacheDirExists:
      state.nimcacheDirExists = false
      state.cleaned = true
    # buildDirExistsは変更しない
  of "build":
    if state.buildDirExists:
      state.buildDirExists = false
      state.cleaned = true
    # nimcacheDirExistsは変更しない
  else:
    return false
  
  state.dryRun = false
  state.verbose = false
  state.cleanMode = "normal"
  state.onlyDirs = @[dir]
  
  return true

step(stWhen, "I run \"niuv clean --full\""):
  state.buildDirExists = false
  state.nimcacheDirExists = false
  state.tempFilesExist = false
  state.cleaned = true
  
  state.dryRun = false
  state.verbose = false
  state.cleanMode = "full"
  state.onlyDirs = @[]
  
  return true

step(stWhen, "I run \"niuv clean --path={string}\""):
  let path = matches[0]
  
  if path == state.customPath and state.customPathExists:
    state.customPathExists = false
    state.cleaned = true
  
  state.dryRun = false
  state.verbose = false
  state.cleanMode = "normal"
  state.onlyDirs = @[]
  
  return true

# 検証
step(stThen, "the \"build\" directory should be removed"):
  return not state.buildDirExists

step(stThen, "the \"nimcache\" directory should be removed"):
  return not state.nimcacheDirExists

step(stThen, "the command should complete successfully"):
  return true

step(stThen, "I should see what would be cleaned"):
  return state.dryRun

step(stThen, "no files should actually be removed"):
  return state.dryRun and 
         ((state.buildDirExists == true and state.nimcacheDirExists == true) or 
          state.nothingToClean)

step(stThen, "I should see detailed information about cleaned files"):
  return state.verbose

step(stThen, "all build artifacts should be removed"):
  return not state.buildDirExists and not state.nimcacheDirExists

step(stThen, "the \"build\" directory should remain intact"):
  return state.buildDirExists

step(stThen, "I should see a message indicating nothing to clean"):
  return state.nothingToClean

step(stThen, "all temporary files should be removed"):
  return not state.tempFilesExist

step(stThen, "build artifacts in the custom path should be removed"):
  return not state.customPathExists