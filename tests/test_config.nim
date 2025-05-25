import std/[unittest, os, tables, strutils]
import results
import parsetoml
import ../src/utils  # countProcessorsを使用するため
import ../src/config
import ../src/cli
import ./testutils

suite "Configuration Tests":
  setup:
    # 元の作業ディレクトリを保存
    let originalDir = getCurrentDir()
    
    import std/times

    # テストごとに一意なディレクトリを作成
    let testId = $getCurrentProcessId() & "_" & $getTime().toUnix()
    let tempHome = absolutePath(getTempDir() / ("niuv_test_" & testId))
    
    try:
      # 既存ディレクトリがあれば削除
      if dirExists(tempHome):
        try:
          removeDir(tempHome)
        except OSError:
          log("Failed to remove existing test directory: " & tempHome)
          raise
      
      # 新規ディレクトリ作成
      createDir(tempHome)
      createDir(tempHome / ".niuv")
      
      # ディレクトリ作成を確認
      if not dirExists(tempHome) or not dirExists(tempHome / ".niuv"):
        raise newException(IOError, "Failed to create test directories")
      
      # 環境変数の設定（グローバル設定を完全に無視）
      putEnv("NIUV_TEST_MODE", "1")
      putEnv("NIUV_TEST_HOME", tempHome)
      putEnv("NIUV_NO_GLOBAL_CONFIG", "1")  # グローバル設定を無視
      when defined(windows):
        putEnv("USERPROFILE", tempHome)
        putEnv("APPDATA", tempHome / "AppData")
      else:
        putEnv("HOME", tempHome)
        putEnv("XDG_CONFIG_HOME", tempHome / ".config")
      
      # デフォルト設定を明示的に設定
      var defaultConfig = newConfig()
      defaultConfig.nimbleLocalPath = "nimbledeps/pkgs"
      defaultConfig.nimVersion = ""
      defaultConfig.parallelJobs = 4  # テスト用に固定値
      defaultConfig.verboseOutput = false
      defaultConfig.shellIntegration = false
      
      # 設定ファイルのディレクトリを確実に作成
      let configDir = tempHome / ".niuv"
      if not dirExists(configDir):
        createDir(configDir)
      
      let configPath = tempHome / ".niuv" / "config.toml"
      echo "Writing config to: ", configPath  # デバッグ用
      
      let writeRes = writeConfig(defaultConfig, configPath)
      if not writeRes.isOk:
        echo "Failed to write config: ", writeRes.error
        raise newException(IOError, "Failed to write config: " & $writeRes.error)
      
      # 設定ファイルが存在することを確認
      if not fileExists(configPath):
        echo "Config file not found at: ", configPath
        raise newException(IOError, "Config file not created: " & configPath)
        
      # 設定ファイルの内容を詳細にログ出力
      echo "=== Config file debug ==="
      echo "Path: ", configPath
      echo "Content:"
      try:
        let content = readFile(configPath)
        echo content
        echo "Content length: ", content.len
      except IOError as e:
        echo "Failed to read config file: ", e.msg
        raise
    finally:
      # 必ず元のディレクトリに戻す
      setCurrentDir(originalDir)
  
  teardown:
    # 元の作業ディレクトリを保存
    let originalDir = getCurrentDir()
    
    try:
      # テスト用ディレクトリの削除
      let tempHome = getEnv("NIUV_TEST_HOME")
      if dirExists(tempHome):
        try:
          setCurrentDir(tempHome)
          removeDir(tempHome)
        except OSError:
          log("Failed to remove test directory: " & tempHome)
          raise
      
      # 環境変数をクリア
      when defined(windows):
        putEnv("USERPROFILE", "")
      else:
        putEnv("HOME", "")
      putEnv("NIUV_TEST_MODE", "")
      putEnv("NIUV_TEST_HOME", "")
    finally:
      # 必ず元のディレクトリに戻す
      setCurrentDir(originalDir)
  
test "Default configuration when no config file exists":
    # テスト用の一時ディレクトリを準備
    let testDir = getTempDir() / "niuv_test_default_" & $getCurrentProcessId()
    createDir(testDir)
    
    # 環境変数を設定
    putEnv("NIUV_TEST_MODE", "1")
    putEnv("NIUV_TEST_HOME", testDir)
    
    # 設定ファイルがない状態でのデフォルト設定を取得
    let config = loadConfig()
    
    # デフォルト値のチェック
    check:
      normalizedPath(config.nimbleLocalPath) == normalizedPath("nimbledeps/pkgs")
      config.nimVersion == ""
      config.parallelJobs == 4  # テスト環境では固定値
      config.verboseOutput == false
      config.shellIntegration == false
    
    # 後片付け
    removeDir(testDir)
  
test "Save and load configuration with new options":
    # テスト用の一時ディレクトリを準備
    let testDir = getTempDir() / "niuv_test_config_" & $getCurrentProcessId()
    createDir(testDir)
    createDir(testDir / ".niuv")  # 確実にディレクトリを作成

    # テスト用の環境変数を設定
    putEnv("NIUV_TEST_MODE", "1")
    putEnv("NIUV_TEST_HOME", testDir)
    putEnv("NIUV_NO_GLOBAL_CONFIG", "1")

    # カスタム設定を作成
    var config = NiuvConfig(
      nimbleLocalPath: "custom/path",
      nimVersion: "1.6.8",
      cacheDir: testDir / ".niuv" / "cache",  # テストディレクトリを使用
      parallelJobs: 4,
      verboseOutput: true,
      shellIntegration: true,
      autoLock: false,
      lockfile: "custom.lock",
      nimbleDir: ".custom/deps"
    )

    # 設定を保存
    let res = saveConfig(config)
    check res.isOk

    # 設定ファイルが作成されたことを確認
    let testConfigFile = testDir / ".niuv" / "config.toml"
    check fileExists(testConfigFile)

    # TOMLの内容を確認
    let tomlContent = parsetoml.parseFile(testConfigFile)
    check:
      tomlContent["niuv"]["nimbleLocalPath"].getStr() == "custom/path"
      tomlContent["niuv"]["nimVersion"].getStr() == "1.6.8"
      tomlContent["niuv"]["parallelJobs"].getInt() == 4
      tomlContent["niuv"]["verboseOutput"].getBool() == true
      tomlContent["niuv"]["shellIntegration"].getBool() == true
      tomlContent["niuv"]["autoLock"].getBool() == false
      tomlContent["niuv"]["lockfile"].getStr() == "custom.lock"
      tomlContent["niuv"]["nimbleDir"].getStr() == ".custom/deps"

    # 設定をロード
    let loadedConfig = loadConfig()

    # 保存した値が正しくロードされることを確認
    check:
      normalizedPath(loadedConfig.nimbleLocalPath) == normalizedPath("custom/path")
      loadedConfig.nimVersion == "1.6.8"
      # キャッシュディレクトリのパスを修正 (テストモード用)
      normalizedPath(loadedConfig.cacheDir) == normalizedPath(testDir / ".niuv" / "cache")
      loadedConfig.parallelJobs == 4
      loadedConfig.verboseOutput == true
      loadedConfig.shellIntegration == true
      loadedConfig.autoLock == false
      loadedConfig.lockfile == "custom.lock"
      loadedConfig.nimbleDir == ".custom/deps"

    # テスト用環境変数をクリア
    putEnv("NIUV_TEST_MODE", "")
    putEnv("NIUV_TEST_HOME", "")
  
test "Update partial configuration":
  # 初期設定を作成
  var config = NiuvConfig(
    nimbleLocalPath: "initial/path",
    nimVersion: "1.6.0",
    cacheDir: getHomeDir() / ".niuv" / "cache",
    parallelJobs: 2,
    verboseOutput: false,
    shellIntegration: false
  )
  let saveRes = saveConfig(config)
  check saveRes.isOk
  
  # 部分的に設定を更新
  var updates = initTable[string, string]()
  updates["nimVersion"] = "1.6.8"
  updates["parallelJobs"] = "4"
  let updateRes = updateConfig(proc(c: var NiuvConfig) =
    c.nimVersion = updates["nimVersion"]
    c.parallelJobs = parseInt(updates["parallelJobs"])
  )
  check updateRes.isOk
  
  # 設定をロード
  let updatedConfig = loadConfig()
  
  # 更新された値だけが変更されていることを確認
  let expectedCacheDir = getHomeDir() / ".niuv" / "cache"
  # パス比較前に正規化
  let normalizedCacheDir = normalizedPath(updatedConfig.cacheDir)
  let normalizedExpected = normalizedPath(expectedCacheDir)
  
  check:
    normalizedPath(updatedConfig.nimbleLocalPath) == normalizedPath("initial/path")  # 変更なし
    updatedConfig.nimVersion == "1.6.8"  # 更新された
    normalizedCacheDir == normalizedExpected  # 正規化したパスで比較
    updatedConfig.parallelJobs == 4  # 更新された
    updatedConfig.verboseOutput == false  # 変更なし
    updatedConfig.shellIntegration == false  # 変更なし
  
test "Project-specific configuration":
    # テスト用の一時ディレクトリを準備
    let testDir = getTempDir() / "niuv_test_project_" & $getCurrentProcessId()
    createDir(testDir)
    
    # 環境変数を設定
    putEnv("NIUV_TEST_MODE", "1")
    putEnv("NIUV_TEST_HOME", testDir)
    
    # グローバル設定を作成
    var globalConfig = NiuvConfig(
      nimbleLocalPath: "global/path",
      nimVersion: "1.6.0",
      cacheDir: testDir / ".niuv" / "cache",
      parallelJobs: 2,
      verboseOutput: false,
      shellIntegration: false
    )
    let saveRes = saveConfig(globalConfig)
    if not saveRes.isOk:
      echo "Config save failed: " & $saveRes.error
      check false
  
    # プロジェクト設定ファイルを作成
    let projectConfig = """
    [tool.niuv]
    nimbleLocalPath = "project/path"
    nimVersion = "1.6.8"
    parallelJobs = 4
    """
    writeFile(testDir / "niuv.toml", projectConfig)
    
    # マージされた設定を取得
    let mergedConfig = getMergedConfig()
    if not mergedConfig.isOk:
      echo "Failed to merge config: " & $mergedConfig.error
      check false
    
    # プロジェクト設定が優先されることを確認
    check:
      normalizedPath(mergedConfig.get().nimbleLocalPath) == normalizedPath("project/path")
      mergedConfig.get().nimVersion == "1.6.8"
      normalizedPath(mergedConfig.get().cacheDir) == normalizedPath(testDir / ".niuv" / "cache")
      mergedConfig.get().parallelJobs == 4
      mergedConfig.get().verboseOutput == false
      mergedConfig.get().shellIntegration == false
    
    # 後片付け
    removeDir(testDir)

test "Initialize niuv.toml with CLI options":
    # テスト用の一時ディレクトリを準備 - テスト専用のディレクトリを使用
    let testDir = getTempDir() / "niuv_test_init_" & $getCurrentProcessId()
    createDir(testDir)

    # 現在のディレクトリを保存
    let originalDir = getCurrentDir()
    try:
      # テスト用ディレクトリに移動
      setCurrentDir(testDir)

      # 環境変数を設定
      putEnv("NIUV_TEST_MODE", "1")
      putEnv("NIUV_TEST_HOME", testDir)

      # CLIオプションを準備
      var options = newCliOptions()
      options.nimVersion = "2.0.6"
      options.nimbleDir = ".custom/deps"
      options.lockfile = "custom.lock"
      options.autoLock = false

      # niuv.tomlを初期化
      check initProject(options) == true

      # ファイルが作成されたことを確認
      let configFile = testDir / "niuv.toml"
      check fileExists(configFile)

      # 内容を確認
      let content = readFile(configFile)
      check:
        "nim_version = \"2.0.6\"" in content
        "nimble_dir = \".custom/deps\"" in content
        "lockfile = \"custom.lock\"" in content
        "auto_lock = false" in content

    finally:
      # テスト後のクリーンアップ
      setCurrentDir(originalDir)
      if dirExists(testDir):
        removeDir(testDir)
  
test "Load config with exception handling":
    # Create a malformed TOML file
    let configDir = getEnv("NIUV_TEST_HOME") / ".niuv"
    createDir(configDir)
    let configPath = configDir / "config.toml"
    writeFile(configPath, """
[niuv
invalid toml syntax
""")
    
    # Should return default config when parsing fails
    let config = loadConfig()
    check config.nimbleLocalPath == "nimbledeps/pkgs"  # Default value
    
test "Error handling in getMergedConfig":
    # Make sure we're in the test directory
    let testHome = getEnv("NIUV_TEST_HOME")
    if testHome.len > 0 and dirExists(testHome):
      setCurrentDir(testHome)
    
    # Create a malformed project TOML file
    let projectPath = testHome / "niuv.toml"
    writeFile(projectPath, """
[tool.niuv
invalid syntax here
""")
    
    let result = getMergedConfig()
    check result.isErr
    check result.error.contains("TomlError")
    
test "Test setTestConfig":
    # Clean up any bad config files from previous tests
    let testHome = getEnv("NIUV_TEST_HOME")
    if testHome.len > 0:
      let badToml = testHome / "niuv.toml"
      if fileExists(badToml):
        removeFile(badToml)
      let badConfig = testHome / ".niuv" / "config.toml"
      if fileExists(badConfig):
        removeFile(badConfig)
    
    var testConfig = newConfig()
    testConfig.venvDir = "/test/venv"
    testConfig.parallelJobs = 8
    
    setTestConfig(testConfig)
    
    # getMergedConfig should use test config when venvDir is set
    let result = getMergedConfig()
    check result.isOk
    check result.get.venvDir == "/test/venv"
    check result.get.parallelJobs == 8
    
    # Reset test config
    setTestConfig(NiuvConfig())

test "Error handling in saveConfig":
    # Try to save to an invalid path
    let invalidPath = "/nonexistent/path/config.toml"
    var config = newConfig()
    
    let result = saveConfig(config, invalidPath)
    check result.isErr
    check result.error.contains("Failed to create config directory")
    
test "Error handling in updateConfig":
    # Try to update config at invalid path
    let invalidPath = "/nonexistent/path/config.toml"
    
    proc updater(c: var NiuvConfig) =
      c.nimVersion = "2.2.0"
    
    let result = updateConfig(updater, invalidPath)
    check result.isErr
    
test "New configuration options":
    var config = NiuvConfig(
      nimbleLocalPath: "custom/path",
      nimVersion: "1.6.8",
      cacheDir: getHomeDir() / ".niuv" / "custom_cache",
      parallelJobs: 4,
      verboseOutput: true,
      shellIntegration: true
    )
    discard saveConfig(config)
    
    let loadedConfig = loadConfig()
    check:
      normalizedPath(loadedConfig.nimbleLocalPath) == normalizedPath("custom/path")
      loadedConfig.nimVersion == "1.6.8"


