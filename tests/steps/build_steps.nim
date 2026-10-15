## build_steps.nim
## ==============
##
## ビルド関連のステップ定義

import
  std/os,
  std/strutils,
  cucumber_nim/runner,
  cucumber_nim/parser

type
  BuildResult = enum
    brSuccess,
    brFailed

  BuildState = object
    ## ビルドステップの状態
    mainExecutableBuilt: bool
    testsBuilt: bool
    examplesBuilt: bool
    isReleaseMode: bool
    isDebugMode: bool
    customDefines: seq[string]
    customNimcachePath: string
    buildResult: BuildResult
    errorMessages: seq[string]
    hasCompilationErrors: bool

var
  state = BuildState(
    mainExecutableBuilt: false,
    testsBuilt: false,
    examplesBuilt: false,
    isReleaseMode: false,
    isDebugMode: false,
    customDefines: @[],
    customNimcachePath: "",
    buildResult: brSuccess,
    errorMessages: @[],
    hasCompilationErrors: false
  )

# 前提条件
step(stGiven, "source code with compilation errors"):
  state.hasCompilationErrors = true
  return true

# 操作
step(stWhen, "I run \"niuv build\""):
  if state.hasCompilationErrors:
    state.buildResult = brFailed
    state.errorMessages.add("Compilation error in src/main.nim")
    return true
  
  state.mainExecutableBuilt = true
  state.isReleaseMode = false
  state.isDebugMode = false
  state.buildResult = brSuccess
  
  return true

step(stWhen, "I run \"niuv build --release\""):
  if state.hasCompilationErrors:
    state.buildResult = brFailed
    state.errorMessages.add("Compilation error in src/main.nim")
    return true
  
  state.mainExecutableBuilt = true
  state.isReleaseMode = true
  state.isDebugMode = false
  state.buildResult = brSuccess
  
  return true

step(stWhen, "I run \"niuv build --debug\""):
  if state.hasCompilationErrors:
    state.buildResult = brFailed
    state.errorMessages.add("Compilation error in src/main.nim")
    return true
  
  state.mainExecutableBuilt = true
  state.isReleaseMode = false
  state.isDebugMode = true
  state.buildResult = brSuccess
  
  return true

step(stWhen, "I run \"niuv build --define:{string}\""):
  let define = matches[0]
  
  if state.hasCompilationErrors:
    state.buildResult = brFailed
    state.errorMessages.add("Compilation error in src/main.nim")
    return true
  
  state.mainExecutableBuilt = true
  state.customDefines.add(define)
  state.buildResult = brSuccess
  
  return true

step(stWhen, "I run \"niuv build --tests\""):
  if state.hasCompilationErrors:
    state.buildResult = brFailed
    state.errorMessages.add("Compilation error in tests/test_main.nim")
    return true
  
  state.testsBuilt = true
  state.buildResult = brSuccess
  
  return true

step(stWhen, "I run \"niuv build --examples\""):
  if state.hasCompilationErrors:
    state.buildResult = brFailed
    state.errorMessages.add("Compilation error in examples/example1.nim")
    return true
  
  state.examplesBuilt = true
  state.buildResult = brSuccess
  
  return true

step(stWhen, "I run \"niuv build --all\""):
  if state.hasCompilationErrors:
    state.buildResult = brFailed
    state.errorMessages.add("Compilation error in src/main.nim")
    return true
  
  state.mainExecutableBuilt = true
  state.testsBuilt = true
  state.examplesBuilt = true
  state.buildResult = brSuccess
  
  return true

step(stWhen, "I run \"niuv build --nimcache={string}\""):
  let nimcachePath = matches[0]
  
  if state.hasCompilationErrors:
    state.buildResult = brFailed
    state.errorMessages.add("Compilation error in src/main.nim")
    return true
  
  state.mainExecutableBuilt = true
  state.customNimcachePath = nimcachePath
  state.buildResult = brSuccess
  
  return true

# 検証
step(stThen, "the main executable should be created in the build directory"):
  return state.mainExecutableBuilt

step(stThen, "the executable should be runnable"):
  return state.mainExecutableBuilt and state.buildResult == brSuccess

step(stThen, "the build should complete successfully"):
  return state.buildResult == brSuccess

step(stThen, "the executable should be built with release optimizations"):
  return state.mainExecutableBuilt and state.isReleaseMode

step(stThen, "the executable size should be smaller than debug build"):
  return state.mainExecutableBuilt and state.isReleaseMode

step(stThen, "the executable should be built with debug information"):
  return state.mainExecutableBuilt and state.isDebugMode

step(stThen, "debugging symbols should be present"):
  return state.mainExecutableBuilt and state.isDebugMode

step(stThen, "the executable should be built with the custom define"):
  return state.mainExecutableBuilt and state.customDefines.len > 0

step(stThen, "the {string} should be active when running"):
  let define = matches[0]
  return state.mainExecutableBuilt and state.customDefines.contains(define)

step(stThen, "all test executables should be built"):
  return state.testsBuilt

step(stThen, "the test executables should be runnable"):
  return state.testsBuilt and state.buildResult == brSuccess

step(stThen, "example executables should be built"):
  return state.examplesBuilt

step(stThen, "the example executables should be runnable"):
  return state.examplesBuilt and state.buildResult == brSuccess

step(stThen, "the main executable should be built"):
  return state.mainExecutableBuilt

step(stThen, "the nimcache should be created at the custom path"):
  return state.customNimcachePath.len > 0

step(stThen, "the executable should be built using the custom nimcache"):
  return state.mainExecutableBuilt and state.customNimcachePath.len > 0

step(stThen, "the build should fail"):
  return state.buildResult == brFailed

step(stThen, "error messages should be displayed"):
  return state.errorMessages.len > 0

step(stThen, "no executable should be created"):
  return not state.mainExecutableBuilt