import std/[os, strutils]
import parsetoml, results

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
    coverageExcludePatterns: @["**/vendor/**", "**/nimcache/**"]
  )

proc loadConfig*(): NiuvConfig =
  ## 設定ファイルを読み込む
  let configFile = getHomeDir() / ".niuv" / "config.toml"

  # テストモードで設定されたテストホームがある場合はそちらを使用
  let testHome = getEnv("NIUV_TEST_HOME")
  let useTestHome = getEnv("NIUV_TEST_MODE") == "1" and testHome.len > 0
  let configFilePath = if useTestHome: testHome / ".niuv" / "config.toml" else: configFile

  # デフォルト設定を用意
  var config = newConfig()

  # 設定ファイルが存在しない場合はデフォルトを返す
  if not fileExists(configFilePath):
    return config

  # 設定ファイルがある場合は読み込む
  try:
    let tomlContent = parsetoml.parseFile(configFilePath)

    # TOML構造が旧形式（直接のキー）と新形式（[niuv]セクション内）の両方をサポート
    let niuvTable = if tomlContent.hasKey("niuv"): tomlContent["niuv"] else: tomlContent

    # 各設定項目を読み込む（項目がない場合はデフォルトを保持）
    if niuvTable.hasKey("nimbleLocalPath"):
      config.nimbleLocalPath = niuvTable["nimbleLocalPath"].getStr()
    if niuvTable.hasKey("nimVersion"):
      config.nimVersion = niuvTable["nimVersion"].getStr()
    if niuvTable.hasKey("cacheDir"):
      config.cacheDir = niuvTable["cacheDir"].getStr()
    if niuvTable.hasKey("venvDir"):
      config.venvDir = niuvTable["venvDir"].getStr()
    if niuvTable.hasKey("parallelJobs"):
      config.parallelJobs = niuvTable["parallelJobs"].getInt()
    if niuvTable.hasKey("verboseOutput"):
      config.verboseOutput = niuvTable["verboseOutput"].getBool()
    if niuvTable.hasKey("shellIntegration"):
      config.shellIntegration = niuvTable["shellIntegration"].getBool()
    if niuvTable.hasKey("autoLock"):
      config.autoLock = niuvTable["autoLock"].getBool()
    if niuvTable.hasKey("lockfile"):
      config.lockfile = niuvTable["lockfile"].getStr()
    if niuvTable.hasKey("nimbleDir"):
      config.nimbleDir = niuvTable["nimbleDir"].getStr()
    
    # Coverage settings
    if niuvTable.hasKey("coverageEnabled"):
      config.coverageEnabled = niuvTable["coverageEnabled"].getBool()
    if niuvTable.hasKey("coverageThreshold"):
      config.coverageThreshold = niuvTable["coverageThreshold"].getFloat()
    if niuvTable.hasKey("coverageFormats"):
      config.coverageFormats = niuvTable["coverageFormats"].getStr()
    if niuvTable.hasKey("coverageOutputDir"):
      config.coverageOutputDir = niuvTable["coverageOutputDir"].getStr()
    
  except Exception as e:
    echo "Error loading config file: " & e.msg
    return config

  return config

proc toToml*(config: NiuvConfig): string =
  ## NiuvConfigをTOML形式の文字列に変換する
  proc escapeToml(s: string): string =
    ## TOML仕様に準拠したエスケープ処理
    result = s.multiReplace([
      ("\\", "\\\\"),
      ("\"", "\\\""),
      ("\b", "\\b"),
      ("\t", "\\t"),
      ("\n", "\\n"),
      ("\r", "\\r"),
      ("\f", "\\f")
    ])

  var tomlContent = """
[niuv]
nimbleLocalPath = "$1"
nimVersion = "$2"
cacheDir = "$3"
venvDir = "$4"
parallelJobs = $5
verboseOutput = $6
shellIntegration = $7
autoLock = $8
lockfile = "$9"
nimbleDir = "$10"
coverageEnabled = $11
coverageThreshold = $12
coverageFormats = "$13"
coverageOutputDir = "$14"
""" % [
    escapeToml(config.nimbleLocalPath),
    escapeToml(config.nimVersion),
    escapeToml(config.cacheDir),
    escapeToml(config.venvDir),
    $config.parallelJobs,
    $config.verboseOutput,
    $config.shellIntegration,
    $config.autoLock,
    escapeToml(config.lockfile),
    escapeToml(config.nimbleDir),
    $config.coverageEnabled,
    $config.coverageThreshold,
    escapeToml(config.coverageFormats),
    escapeToml(config.coverageOutputDir)
  ]
  return tomlContent

proc writeConfig*(config: NiuvConfig, path: string): Result[void, string] =
  ## 設定をTOMLファイルに書き込む (テスト用の別バージョン)
  # ディレクトリがなければ作成
  let dir = splitPath(path).head
  if dir.len > 0 and not dirExists(dir):
    try:
      createDir(dir)
    except OSError as e:
      return err("Failed to create config directory '" & dir & "': " & e.msg)

  # 設定をTOML形式に変換して保存
  try:
    let tomlContent = toToml(config)
    writeFile(path, tomlContent)
    return ok()
  except IOError as e:
    return err("Failed to write config file '" & path & "': " & e.msg)
  except Exception as e:
    return err("Unexpected error: " & e.msg)

proc saveConfig*(config: NiuvConfig, path: string = ""): Result[void, string] =
  ## 設定をTOMLファイルに保存する
  # テストモードの場合はテストホームを使用
  var configPath = if path.len > 0: path else: getHomeDir() / ".niuv" / "config.toml"
  let testHome = getEnv("NIUV_TEST_HOME")
  let useTestHome = getEnv("NIUV_TEST_MODE") == "1" and testHome.len > 0
  if useTestHome and path.len == 0:
    configPath = testHome / ".niuv" / "config.toml"
    # テスト用ディレクトリが存在するか確認し、なければ作成
    if not dirExists(testHome / ".niuv"):
      try:
        createDir(testHome / ".niuv")
      except OSError as e:
        return err("Failed to create test config directory '" & testHome / ".niuv" & "': " & e.msg)

  # ディレクトリがなければ作成 (再帰的に作成)
  let dir = configPath.splitPath().head
  if dir.len > 0 and not dirExists(dir):
    try:
      createDir(dir)
    except OSError as e:
      return err("Failed to create config directory '" & dir & "': " & e.msg)

  # 設定をTOML形式に変換して保存
  try:
    let tomlContent = toToml(config)
    writeFile(configPath, tomlContent)
    return ok()
  except IOError as e:
    return err("Failed to write config file '" & configPath & "': " & e.msg)
  except TomlError as e:
    return err("Invalid TOML format in generated content: " & e.msg)
  except Exception as e:
    return err("Unexpected error: " & e.msg)

var testConfig* = NiuvConfig()  # テスト用の設定（初期化済み）

proc setTestConfig*(config: NiuvConfig) =
  ## テスト用に設定を上書きする
  testConfig = config

proc getMergedConfig*(): Result[NiuvConfig, string] =
  ## プロジェクト固有の設定とグローバル設定をマージして返す
  var config: NiuvConfig

  try:
    # テスト設定が優先（venvDirが設定されている場合）
    if testConfig.venvDir.len > 0:
      config = testConfig
    else:
      config = loadConfig()

    # プロジェクト設定ファイルのパス（テストモードでは環境変数から取得）
    var projectConfigFile = getCurrentDir() / "niuv.toml"
    let testHome = getEnv("NIUV_TEST_HOME")
    if getEnv("NIUV_TEST_MODE") == "1" and testHome.len > 0:
      projectConfigFile = testHome / "niuv.toml"

    # プロジェクト設定ファイルを探す
    if fileExists(projectConfigFile):
      let tomlContent = parsetoml.parseFile(projectConfigFile)
      # プロジェクト設定ファイルはtool.niuvセクションか直接のキー値を受け入れる
      var toolNiuv: TomlValueRef

      if tomlContent.hasKey("tool"):
        let toolValue = tomlContent["tool"]
        if toolValue.hasKey("niuv"):
          toolNiuv = toolValue["niuv"]

      # 古い形式もサポート（niuv.tomlのルートに設定）
      if toolNiuv.isNil:
        toolNiuv = tomlContent

      # snake_caseとcamelCaseの両方をサポート
      let keys = ["nimbleLocalPath", "nimble_local_path", "nimVersion", "nim_version",
                "parallelJobs", "parallel_jobs", "verboseOutput", "verbose_output",
                "shellIntegration", "shell_integration", "autoLock", "auto_lock",
                "lockfile", "nimbleDir", "nimble_dir"]

      # プロジェクト設定で上書き
      for key in keys:
        if toolNiuv.hasKey(key):
          case key
          of "nimbleLocalPath", "nimble_local_path":
            config.nimbleLocalPath = toolNiuv[key].getStr()
          of "nimVersion", "nim_version":
            config.nimVersion = try:
              toolNiuv[key].getStr()
            except:
              ""
          of "parallelJobs", "parallel_jobs":
            config.parallelJobs = toolNiuv[key].getInt()
          of "verboseOutput", "verbose_output":
            config.verboseOutput = toolNiuv[key].getBool()
          of "shellIntegration", "shell_integration":
            config.shellIntegration = toolNiuv[key].getBool()
          of "autoLock", "auto_lock":
            config.autoLock = toolNiuv[key].getBool()
          of "lockfile":
            config.lockfile = toolNiuv[key].getStr()
          of "nimbleDir", "nimble_dir":
            config.nimbleDir = toolNiuv[key].getStr()

    return ok(config)
  except IOError as e:
    return err("IOError: " & e.msg)
  except TomlError as e:
    return err("TomlError: " & e.msg)
  except Exception as e:
    return err("Unexpected error: " & e.msg)

proc updateConfig*(updater: proc(c: var NiuvConfig), path: string = ""): Result[void, string] =
  ## 設定を更新して保存する
  # テストモードの場合はテストホームを使用
  var configPath = if path.len > 0: path else: getHomeDir() / ".niuv" / "config.toml"
  let testHome = getEnv("NIUV_TEST_HOME")
  let useTestHome = getEnv("NIUV_TEST_MODE") == "1" and testHome.len > 0
  if useTestHome and path.len == 0:
    configPath = testHome / ".niuv" / "config.toml"

  try:
    var config = loadConfig()
    updater(config)
    return saveConfig(config, configPath)
  except Exception as e:
    return err("Failed to update config: " & e.msg)

# Coverage configuration utility methods
proc getConfigValue*(config: Config, key: string, default: string = ""): string =
  ## Get configuration value by key with dot notation support
  case key
  of "coverage.enabled":
    result = $config.coverageEnabled
  of "coverage.threshold":
    result = $config.coverageThreshold
  of "coverage.formats":
    result = config.coverageFormats
  of "coverage.outputDir":
    result = config.coverageOutputDir
  else:
    result = default

proc setConfigValue*(config: var Config, key: string, value: string) =
  ## Set configuration value by key with dot notation support
  case key
  of "coverage.enabled":
    config.coverageEnabled = value.toLowerAscii() == "true"
  of "coverage.threshold":
    config.coverageThreshold = parseFloat(value)
  of "coverage.formats":
    config.coverageFormats = value
  of "coverage.outputDir":
    config.coverageOutputDir = value
  else:
    discard

