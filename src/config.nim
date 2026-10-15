import std/[os, strutils, options, tables]
# Using nim-configkit for configuration management
when not defined(disableConfigKit):
  import "../../nim-configkit/src/core/types"
  import "../../nim-configkit/src/core/loader" 
  import "../../nim-configkit/src/formats/toml_format"
  import "../../nim-configkit/src/sources/file_source"

type
  NiuvConfig* = object
    nimbleLocalPath*: string
    nimVersion*: string
    cacheDir*: string
    venvDir*: string
    parallelJobs*: int
    verboseOutput*: bool
    shellIntegration*: bool
    autoLock*: bool
    lockfile*: string
    nimbleDir*: string
    # Coverage settings
    coverageEnabled*: bool
    coverageThreshold*: float
    coverageFormats*: string
    coverageOutputDir*: string
    coverageIncludePatterns*: seq[string]
    coverageExcludePatterns*: seq[string]
    # Nim compiler detection settings
    nimPath*: string           # Explicit Nim compiler path
    nimDetection*: string      # Detection strategy: auto, manual, project-only
    allowSystemNim*: bool      # Allow fallback to system Nim

  NiuvError* = object of CatchableError
  
  # Alias for compatibility
  Config* = NiuvConfig

# 新しいConfig構造体を作成する
proc newConfig*(): NiuvConfig =
  result = NiuvConfig(
    nimbleLocalPath: "nimbledeps/pkgs",
    nimVersion: "",
    cacheDir: getHomeDir() / ".niuv" / "cache",
    venvDir: getHomeDir() / ".niuv" / "venvs",
    parallelJobs: 4,
    verboseOutput: false,
    shellIntegration: false,
    autoLock: true,
    lockfile: "nimble.lock",
    nimbleDir: ".niuv/deps",
    # Coverage defaults
    coverageEnabled: true,
    coverageThreshold: 80.0,
    coverageFormats: "html,json",
    coverageOutputDir: "coverage",
    coverageIncludePatterns: @["src/**/*.nim", "tests/**/*.nim"],
    coverageExcludePatterns: @["**/vendor/**", "**/nimcache/**"],
    # Nim detection defaults
    nimPath: "",              # Empty = auto-detect
    nimDetection: "auto",     # Default to automatic detection
    allowSystemNim: true      # Allow system Nim by default
  )

# テスト用のグローバル設定変数
var testConfig*: Option[NiuvConfig] = none(NiuvConfig)

proc loadConfig*(): NiuvConfig =
  ## nim-configkitを使って設定ファイルを読み込む
  # テスト設定が設定されている場合はそれを返す
  if testConfig.isSome:
    return testConfig.get()
    
  # デフォルト設定を用意
  var config = newConfig()

  # Check for environment variable override first
  if existsEnv("NIUV_TESTKIT_COVERAGE"):
    config.coverageEnabled = getEnv("NIUV_TESTKIT_COVERAGE") == "true"

  # Global config paths to check (in order of precedence)
  let globalConfigPaths = @[
    getHomeDir() / ".config" / "niuv" / "config.toml",  # XDG config dir
    getHomeDir() / ".niuv" / "config.toml",             # Legacy location
  ]

  # 設定ファイルのパスを決定
  let testHome = getEnv("NIUV_TEST_HOME")
  let useTestHome = getEnv("NIUV_TEST_MODE") == "1" and testHome.len > 0
  let configFilePath = if useTestHome: 
    testHome / ".niuv" / "config.toml" 
  else: 
    # Find first existing global config file
    var foundPath = ""
    for path in globalConfigPaths:
      if fileExists(path):
        foundPath = path
        break
    foundPath

  # 設定ファイルが存在しない場合はデフォルトを返す
  if configFilePath.len == 0 or not fileExists(configFilePath):
    return config

  when not defined(disableConfigKit):
    try:
      # nim-configkitを使って設定を読み込む
      var configLoader = initConfigLoader[ConfigValue]()
      configLoader.addSource(initFileSource(configFilePath))
      let configData = configLoader.load()

      if configData.kind == cvkObject:
        # [tool.niuv] または [niuv] セクションを探す
        var niuvSection: ConfigValue
        if "tool" in configData.objectVal and configData.objectVal["tool"].kind == cvkObject:
          let toolSection = configData.objectVal["tool"]
          if "niuv" in toolSection.objectVal:
            niuvSection = toolSection.objectVal["niuv"]
          else:
            return config  # tool.niuvセクションがない場合はデフォルトを返す
        elif "niuv" in configData.objectVal:
          niuvSection = configData.objectVal["niuv"]
        else:
          return config  # niuvセクションがない場合はデフォルトを返す

        # 設定値を読み込む
        if niuvSection.kind == cvkObject:
          for key, value in niuvSection.objectVal:
            case key
            of "nimbleLocalPath", "nimble_local_path":
              if value.kind == cvkString: config.nimbleLocalPath = value.stringVal
            of "nimVersion", "nim_version":
              if value.kind == cvkString: config.nimVersion = value.stringVal
            of "cacheDir", "cache_dir":
              if value.kind == cvkString: config.cacheDir = value.stringVal
            of "venvDir", "venv_dir":
              if value.kind == cvkString: config.venvDir = value.stringVal
            of "parallelJobs", "parallel_jobs":
              if value.kind == cvkInt: config.parallelJobs = value.intVal.int
            of "verboseOutput", "verbose_output":
              if value.kind == cvkBool: config.verboseOutput = value.boolVal
            of "shellIntegration", "shell_integration":
              if value.kind == cvkBool: config.shellIntegration = value.boolVal
            of "autoLock", "auto_lock":
              if value.kind == cvkBool: config.autoLock = value.boolVal
            of "lockfile":
              if value.kind == cvkString: config.lockfile = value.stringVal
            of "nimbleDir", "nimble_dir":
              if value.kind == cvkString: config.nimbleDir = value.stringVal
            of "coverageEnabled", "coverage_enabled":
              if value.kind == cvkBool: config.coverageEnabled = value.boolVal
            of "coverageThreshold", "coverage_threshold":
              if value.kind == cvkFloat: config.coverageThreshold = value.floatVal
            of "coverageFormats", "coverage_formats":
              if value.kind == cvkString: config.coverageFormats = value.stringVal
            of "coverageOutputDir", "coverage_output_dir":
              if value.kind == cvkString: config.coverageOutputDir = value.stringVal
            of "nimPath", "nim_path":
              if value.kind == cvkString: config.nimPath = value.stringVal
            of "nimDetection", "nim_detection":
              if value.kind == cvkString: config.nimDetection = value.stringVal
            of "allowSystemNim", "allow_system_nim":
              if value.kind == cvkBool: config.allowSystemNim = value.boolVal
            else:
              discard  # 未知の設定項目は無視

    except Exception as e:
      echo "Error loading config file: " & e.msg
      return config

  return config

when not defined(disableConfigKit):
  proc configToConfigValue*(config: NiuvConfig): ConfigValue =
    ## NiuvConfigをConfigValueに変換する
    var toolSection = ConfigValue(kind: cvkObject, objectVal: initOrderedTable[string, ConfigValue]())
    var niuvSection = ConfigValue(kind: cvkObject, objectVal: initOrderedTable[string, ConfigValue]())
    
    # 設定値をConfigValueに変換
    niuvSection.objectVal["nimble_local_path"] = ConfigValue(kind: cvkString, stringVal: config.nimbleLocalPath)
    niuvSection.objectVal["nim_version"] = ConfigValue(kind: cvkString, stringVal: config.nimVersion)
    niuvSection.objectVal["cache_dir"] = ConfigValue(kind: cvkString, stringVal: config.cacheDir)
    niuvSection.objectVal["venv_dir"] = ConfigValue(kind: cvkString, stringVal: config.venvDir)
    niuvSection.objectVal["parallel_jobs"] = ConfigValue(kind: cvkInt, intVal: config.parallelJobs)
    niuvSection.objectVal["verbose_output"] = ConfigValue(kind: cvkBool, boolVal: config.verboseOutput)
    niuvSection.objectVal["shell_integration"] = ConfigValue(kind: cvkBool, boolVal: config.shellIntegration)
    niuvSection.objectVal["auto_lock"] = ConfigValue(kind: cvkBool, boolVal: config.autoLock)
    niuvSection.objectVal["lockfile"] = ConfigValue(kind: cvkString, stringVal: config.lockfile)
    niuvSection.objectVal["nimble_dir"] = ConfigValue(kind: cvkString, stringVal: config.nimbleDir)
    niuvSection.objectVal["coverage_enabled"] = ConfigValue(kind: cvkBool, boolVal: config.coverageEnabled)
    niuvSection.objectVal["coverage_threshold"] = ConfigValue(kind: cvkFloat, floatVal: config.coverageThreshold)
    niuvSection.objectVal["coverage_formats"] = ConfigValue(kind: cvkString, stringVal: config.coverageFormats)
    niuvSection.objectVal["coverage_output_dir"] = ConfigValue(kind: cvkString, stringVal: config.coverageOutputDir)
    niuvSection.objectVal["nim_path"] = ConfigValue(kind: cvkString, stringVal: config.nimPath)
    niuvSection.objectVal["nim_detection"] = ConfigValue(kind: cvkString, stringVal: config.nimDetection)
    niuvSection.objectVal["allow_system_nim"] = ConfigValue(kind: cvkBool, boolVal: config.allowSystemNim)
    
    # tool.niuv構造を作成
    toolSection.objectVal["niuv"] = niuvSection
    
    var result = ConfigValue(kind: cvkObject, objectVal: initOrderedTable[string, ConfigValue]())
    result.objectVal["tool"] = toolSection
    
    return result

when not defined(disableConfigKit):
  proc toToml*(config: NiuvConfig): string =
    ## nim-configkitを使ってNiuvConfigをTOML形式の文字列に変換する
    let configValue = configToConfigValue(config)
    let format = initTomlFormat()
    return format.serialize(configValue)

when not defined(disableConfigKit):
  proc writeConfig*(config: NiuvConfig, path: string) =
    ## 設定をTOMLファイルに書き込む (テスト用の別バージョン)
    # ディレクトリがなければ作成
    let dir = splitPath(path).head
    if dir.len > 0 and not dirExists(dir):
      try:
        createDir(dir)
      except OSError as e:
        raise newException(IOError, "Failed to create config directory '" & dir & "': " & e.msg)

    # 設定をTOML形式に変換して保存
    try:
      let tomlContent = toToml(config)
      writeFile(path, tomlContent)
    except IOError as e:
      raise newException(IOError, "Failed to write config file '" & path & "': " & e.msg)
    except Exception as e:
      raise newException(CatchableError, "Unexpected error: " & e.msg)

# Temporarily disabled functions using Result type - removed for now

# Result type for compatibility
type
  Result*[T, E] = object
    case ok*: bool
    of true:
      value*: T
    of false:
      error*: E

proc ok*[T, E](val: T, EType: typedesc[E]): Result[T, E] =
  Result[T, E](ok: true, value: val)

proc err*[T, E](error: E, TType: typedesc[T]): Result[T, E] =
  Result[T, E](ok: false, error: error)

proc isOk*[T, E](r: Result[T, E]): bool = r.ok

proc isErr*[T, E](r: Result[T, E]): bool = not r.ok

proc get*[T, E](r: Result[T, E]): T =
  if r.ok:
    return r.value
  else:
    raise newException(CatchableError, "Result is an error")

proc getError*[T, E](r: Result[T, E]): E =
  if not r.ok:
    return r.error
  else:
    raise newException(CatchableError, "Result is not an error")

proc setConfigValue*(config: var NiuvConfig, key: string, value: string) =
  ## 設定値を設定する（テスト用）
  case key
  of "coverage.enabled":
    config.coverageEnabled = value == "true"
  of "coverage.threshold":
    config.coverageThreshold = parseFloat(value)
  of "coverage.formats":
    config.coverageFormats = value
  of "coverage.outputDir":
    config.coverageOutputDir = value
  else:
    discard

when not defined(disableConfigKit):
  proc saveConfig*(config: NiuvConfig): Result[void, string] =
    ## 設定を保存する（デフォルトパス）
    let configPath = if getEnv("NIUV_TEST_MODE") == "1" and getEnv("NIUV_TEST_HOME").len > 0:
      getEnv("NIUV_TEST_HOME") / ".niuv" / "config.toml"
    else:
      getHomeDir() / ".niuv" / "config.toml"
    
    try:
      writeConfig(config, configPath)
      result = Result[void, string](ok: true)
    except CatchableError as e:
      result = Result[void, string](ok: false, error: e.msg)

when not defined(disableConfigKit):
  proc saveConfig*(config: NiuvConfig, path: string): Result[void, string] =
    ## 設定を指定されたパスに保存する
    try:
      writeConfig(config, path)
      result = Result[void, string](ok: true)
    except CatchableError as e:
      result = Result[void, string](ok: false, error: e.msg)

when not defined(disableConfigKit):
  proc updateConfig*(updateProc: proc(config: var NiuvConfig)): Result[void, string] =
    ## 設定を更新する（デフォルトパス）
    var config = loadConfig()
    updateProc(config)
    return saveConfig(config)

  proc updateConfig*(updateProc: proc(config: var NiuvConfig), path: string): Result[void, string] =
    ## 設定を更新する（指定パス）
    var config = loadConfig()
    updateProc(config)
    return saveConfig(config, path)

when not defined(disableConfigKit):
  proc getMergedConfig*(): Result[NiuvConfig, string] =
    ## グローバル設定とプロジェクト設定をマージする
    try:
      # グローバル設定を読み込み
      var config = loadConfig()
      
      # プロジェクト設定ファイルの存在確認
      let projectConfigPath = getCurrentDir() / "niuv.toml"
      if fileExists(projectConfigPath):
        # プロジェクト設定を読み込み
        var configLoader = initConfigLoader[ConfigValue]()
        configLoader.addSource(initFileSource(projectConfigPath))
        let projectConfigData = configLoader.load()
        
        if projectConfigData.kind == cvkObject:
          # [tool.niuv] セクションを探す
          var niuvSection: ConfigValue
          if "tool" in projectConfigData.objectVal and projectConfigData.objectVal["tool"].kind == cvkObject:
            let toolSection = projectConfigData.objectVal["tool"]
            if "niuv" in toolSection.objectVal:
              niuvSection = toolSection.objectVal["niuv"]
            else:
              return Result[NiuvConfig, string](ok: true, value: config)  # プロジェクト設定がない場合はグローバル設定のみ
          else:
            return Result[NiuvConfig, string](ok: true, value: config)
        
          # プロジェクト設定でグローバル設定を上書き
          if niuvSection.kind == cvkObject:
            for key, value in niuvSection.objectVal:
              case key
              of "nimbleLocalPath", "nimble_local_path":
                if value.kind == cvkString: config.nimbleLocalPath = value.stringVal
              of "nimVersion", "nim_version":
                if value.kind == cvkString: config.nimVersion = value.stringVal
              of "cacheDir", "cache_dir":
                if value.kind == cvkString: config.cacheDir = value.stringVal
              of "venvDir", "venv_dir":
                if value.kind == cvkString: config.venvDir = value.stringVal
              of "parallelJobs", "parallel_jobs":
                if value.kind == cvkInt: config.parallelJobs = value.intVal.int
              of "verboseOutput", "verbose_output":
                if value.kind == cvkBool: config.verboseOutput = value.boolVal
              of "shellIntegration", "shell_integration":
                if value.kind == cvkBool: config.shellIntegration = value.boolVal
              of "autoLock", "auto_lock":
                if value.kind == cvkBool: config.autoLock = value.boolVal
              of "lockfile":
                if value.kind == cvkString: config.lockfile = value.stringVal
              of "nimbleDir", "nimble_dir":
                if value.kind == cvkString: config.nimbleDir = value.stringVal
              else:
                discard
      
      return Result[NiuvConfig, string](ok: true, value: config)
    except Exception as e:
      return Result[NiuvConfig, string](ok: false, error: e.msg)

proc setTestConfig*(config: NiuvConfig) =
  ## テスト用の設定を設定する
  testConfig = some(config)

proc setTestConfig*(testMode: bool = true, testDir: string = "") =
  ## テスト用の設定を行う（オーバーロード）
  if testMode:
    putEnv("NIUV_TEST_MODE", "1")
    if testDir.len > 0:
      putEnv("NIUV_TEST_HOME", testDir)
  else:
    delEnv("NIUV_TEST_MODE")
    delEnv("NIUV_TEST_HOME")
    testConfig = none(NiuvConfig)

when not defined(disableConfigKit):
  proc createDefaultGlobalConfig*(): Result[string, string] =
    ## Create a default global configuration file
    let configDir = getHomeDir() / ".config" / "niuv"
    let configPath = configDir / "config.toml"
    
    try:
      # Create directory if it doesn't exist
      if not dirExists(configDir):
        createDir(configDir)
      
      # Create default config
      var config = newConfig()
      config.coverageEnabled = true
      config.coverageThreshold = 80.0
      config.coverageFormats = "html,json"
      config.coverageOutputDir = "coverage"
      
      # Write config file
      writeConfig(config, configPath)
      
      return Result[string, string](ok: true, value: configPath)
    except CatchableError as e:
      return Result[string, string](ok: false, error: e.msg)

proc getGlobalConfigPath*(): string =
  ## Get the path to the global configuration file
  let configPaths = @[
    getHomeDir() / ".config" / "niuv" / "config.toml",  # XDG config dir
    getHomeDir() / ".niuv" / "config.toml",             # Legacy location
  ]
  
  for path in configPaths:
    if fileExists(path):
      return path
  
  # Return the preferred path for new configs
  return configPaths[0]
