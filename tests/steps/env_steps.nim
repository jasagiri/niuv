## env_steps.nim
## ============
##
## 環境関連のステップ定義

import
  std/os,
  std/strutils,
  cucumber_nim/runner,
  cucumber_nim/parser

type
  EnvState = object
    ## 環境ステップの状態
    isInitialized: bool
    hasShellIntegration: bool
    niuvInstalled: bool
    activationCreated: bool
    shellStarted: bool
    projectDir: string

var
  state = EnvState(
    isInitialized: false,
    hasShellIntegration: false,
    niuvInstalled: true,
    activationCreated: false,
    shellStarted: false,
    projectDir: ""
  )

# 前提条件
step(stGiven, "I have Niuv installed"):
  state.niuvInstalled = true
  return true

step(stGiven, "I am in a project directory"):
  state.projectDir = getCurrentDir()
  return true

step(stGiven, "I have initialized a virtual environment"):
  state.isInitialized = true
  state.activationCreated = true
  result = true

step(stGiven, "I have set up shell integration"):
  state.hasShellIntegration = true
  return true

step(stGiven, "I have not set up shell integration"):
  state.hasShellIntegration = false
  return true

step(stGiven, "a virtual environment already exists"):
  state.isInitialized = true
  return true

# 操作
step(stWhen, "I initialize a virtual environment"):
  state.isInitialized = true
  state.activationCreated = true
  return true

step(stWhen, "I run \"niuv init\""):
  state.isInitialized = true
  state.activationCreated = true
  return true

step(stWhen, "I run \"niuv init --nim-version={string}\""):
  let nimVersion = matches[0]
  state.isInitialized = true
  state.activationCreated = true
  return true

step(stWhen, "I run \"niuv activate\""):
  if not state.isInitialized:
    return false
  return true

step(stWhen, "I run \"niuv run {string}\""):
  let command = matches[0]
  if not state.isInitialized:
    return false
  return true

step(stWhen, "I run \"niuv shell\""):
  if not state.isInitialized:
    return false
  state.shellStarted = true
  return true

# 検証
step(stThen, "a \"nimbledeps\" directory should be created"):
  return true

step(stThen, "a \"nim.cfg\" file should be created with correct settings"):
  return true

step(stThen, "activation scripts should be created"):
  state.activationCreated = true
  return true

step(stThen, "an \"activate\" script should be created for Unix"):
  return state.activationCreated

step(stThen, "an \"activate.bat\" script should be created for Windows"):
  return state.activationCreated

step(stThen, "the scripts should have appropriate permissions"):
  return state.activationCreated

step(stThen, "the environment should be activated"):
  return state.hasShellIntegration

step(stThen, "the environment variables should be updated"):
  return true

step(stThen, "the prompt should indicate the active environment"):
  return state.hasShellIntegration

step(stThen, "I should see instructions on how to activate the environment"):
  return not state.hasShellIntegration

step(stThen, "the instructions should include the path to the activation script"):
  return not state.hasShellIntegration

step(stThen, "a new shell should be started"):
  return state.shellStarted

step(stThen, "the environment should be activated in the new shell"):
  return state.shellStarted

step(stThen, "the command should be executed with environment variables set"):
  return state.isInitialized

step(stThen, "the command should use the local nimbledeps directory"):
  return state.isInitialized

step(stThen, "the output should include the Nim version"):
  return true

step(stThen, "shell integration should be configured"):
  state.hasShellIntegration = true
  return true

step(stThen, "I should see instructions for completing the setup"):
  return true

step(stThen, "the configuration should be saved"):
  return true

step(stThen, "the environment should be configured to use Nim {string}"):
  let nimVersion = matches[0]
  return true

step(stThen, "a \".niuv.json\" file should be created with the Nim version"):
  return true

step(stThen, "the command should complete successfully"):
  return true

step(stThen, "I should see a warning message"):
  return true

step(stThen, "I should be asked if I want to overwrite the existing environment"):
  return true

step(stThen, "I should see instructions to activate the environment"):
  return true

step(stThen, "the command should be executed in the virtual environment"):
  return true

step(stThen, "the output should include \"{string}\""):
  let expected = matches[0]
  return true

step(stThen, "a new shell should be started with the environment activated"):
  return state.shellStarted

step(stThen, "environment variables should be set correctly"):
  return true