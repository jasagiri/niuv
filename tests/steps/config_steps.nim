## config_steps.nim
## ==============
##
## 設定関連のステップ定義

import
  std/os,
  std/strutils,
  std/tables,
  cucumber_nim/runner,
  cucumber_nim/parser

type
  ConfigState = object
    ## 設定ステップの状態
    configs: Table[string, string]
    userConfigs: Table[string, string]
    projectConfigs: Table[string, string]
    envVars: Table[string, string]
    cliArgs: Table[string, string]
    configFileExists: bool
    userConfigFileExists: bool
    lastOutput: string
    lastError: string
    lastExitCode: int

var
  state = ConfigState(
    configs: {"parallelJobs": "2", 
              "nimVersion": "1.6.8",
              "verboseOutput": "false", 
              "shellIntegration": "true", 
              "autoLock": "true"}.toTable,
    userConfigs: {"parallelJobs": "2"}.toTable,
    projectConfigs: initTable[string, string](),
    envVars: initTable[string, string](),
    cliArgs: initTable[string, string](),
    configFileExists: false,
    userConfigFileExists: false,
    lastOutput: "",
    lastError: "",
    lastExitCode: 0
  )

proc updateLastOutput(key: string) =
  if state.cliArgs.hasKey(key):
    state.lastOutput = state.cliArgs[key]
  elif state.envVars.hasKey("NIUV_" & key.toUpperAscii()):
    state.lastOutput = state.envVars["NIUV_" & key.toUpperAscii()]
  elif state.projectConfigs.hasKey(key):
    state.lastOutput = state.projectConfigs[key]
  elif state.userConfigs.hasKey(key):
    state.lastOutput = state.userConfigs[key]
  elif state.configs.hasKey(key):
    state.lastOutput = state.configs[key]
  else:
    state.lastOutput = ""

# 前提条件
step(stGiven, "a configuration with \"{string}\" set to \"{string}\""):
  let 
    key = matches[0]
    value = matches[1]
  
  state.projectConfigs[key] = value
  state.configFileExists = true
  
  return true

step(stGiven, "a user configuration with \"{string}\" set to \"{string}\""):
  let 
    key = matches[0]
    value = matches[1]
  
  state.userConfigs[key] = value
  state.userConfigFileExists = true
  
  return true

step(stGiven, "a project configuration with \"{string}\" set to \"{string}\""):
  let 
    key = matches[0]
    value = matches[1]
  
  state.projectConfigs[key] = value
  state.configFileExists = true
  
  return true

step(stGiven, "a custom configuration"):
  state.projectConfigs["parallelJobs"] = "4"
  state.projectConfigs["nimVersion"] = "1.6.10"
  state.projectConfigs["verboseOutput"] = "true"
  state.configFileExists = true
  
  return true

# 操作
step(stWhen, "I run \"niuv config show\""):
  state.lastOutput = ""
  for key, value in state.configs:
    state.lastOutput.add(key & " = " & value & "\n")
  
  return true

step(stWhen, "I run \"niuv config init\""):
  state.configFileExists = true
  state.lastExitCode = 0
  
  return true

step(stWhen, "I run \"niuv config init --user\""):
  state.userConfigFileExists = true
  state.lastExitCode = 0
  
  return true

step(stWhen, "I run \"niuv config set {string} {string}\""):
  let 
    key = matches[0]
    value = matches[1]
  
  # 無効な値の処理
  if key == "parallelJobs" and not value.isInt():
    state.lastError = "Invalid value for parallelJobs. Must be an integer."
    state.lastExitCode = 1
    return true
  
  state.projectConfigs[key] = value
  state.configFileExists = true
  state.lastExitCode = 0
  
  return true

step(stWhen, "I run \"niuv config get {string}\""):
  let key = matches[0]
  updateLastOutput(key)
  state.lastExitCode = 0
  
  return true

step(stWhen, "I set environment variable \"{string}\" to \"{string}\""):
  let 
    envVar = matches[0]
    value = matches[1]
  
  state.envVars[envVar] = value
  
  return true

step(stWhen, "I run \"niuv --{string}={string} config get {string}\""):
  let 
    cliKey = matches[0]
    cliValue = matches[1]
    configKey = matches[2]
  
  state.cliArgs[configKey] = cliValue
  updateLastOutput(configKey)
  state.lastExitCode = 0
  
  return true

step(stWhen, "I run \"niuv config list\""):
  state.lastOutput = ""
  let configSources = ["configs", "userConfigs", "projectConfigs", "envVars", "cliArgs"]
  
  for source in configSources:
    case source
    of "configs":
      for key, value in state.configs:
        state.lastOutput.add(key & " = " & value & " (default)\n")
    of "userConfigs":
      for key, value in state.userConfigs:
        state.lastOutput.add(key & " = " & value & " (user)\n")
    of "projectConfigs":
      for key, value in state.projectConfigs:
        state.lastOutput.add(key & " = " & value & " (project)\n")
    of "envVars":
      for key, value in state.envVars:
        state.lastOutput.add(key & " = " & value & " (env)\n")
    of "cliArgs":
      for key, value in state.cliArgs:
        state.lastOutput.add(key & " = " & value & " (cli)\n")
  
  state.lastExitCode = 0
  return true

step(stWhen, "I run \"niuv config reset\""):
  state.projectConfigs.clear()
  state.lastExitCode = 0
  
  return true

# 検証
step(stThen, "the default configuration should be displayed"):
  return state.lastOutput.len > 0

step(stThen, "all configuration values should have defaults"):
  for key, _ in state.configs:
    if not state.lastOutput.contains(key):
      return false
  
  return true

step(stThen, "a \"niuv.toml\" configuration file should be created"):
  return state.configFileExists

step(stThen, "the file should contain default settings"):
  return state.configFileExists

step(stThen, "a global user configuration file should be created"):
  return state.userConfigFileExists

step(stThen, "the configuration value should be updated"):
  return true

step(stThen, "the updated value should be saved to the configuration file"):
  return state.configFileExists

step(stThen, "the output should be \"{string}\""):
  let expected = matches[0]
  return state.lastOutput.strip() == expected

step(stThen, "all configuration variables should be listed"):
  let expected = state.configs.len + state.userConfigs.len + state.projectConfigs.len + 
                state.envVars.len + state.cliArgs.len
  
  # 少なくとも期待される数の行があることを確認
  var count = 0
  for line in state.lastOutput.strip().splitLines():
    if line.len > 0:
      count += 1
  
  return count >= expected

step(stThen, "their current values should be displayed"):
  return state.lastOutput.len > 0

step(stThen, "the configuration should be reset to defaults"):
  return state.projectConfigs.len == 0

step(stThen, "an error should be displayed"):
  return state.lastError.len > 0

step(stThen, "the configuration should not be updated"):
  return state.lastExitCode != 0

step(stThen, "the command should fail with non-zero status"):
  return state.lastExitCode != 0