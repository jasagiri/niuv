import std/[os, parseopt, strutils, terminal, tables]

proc showError*(msg: string) =
  ## エラーメッセージを表示する
  styledEcho(styleBright, fgRed, "Error: ", resetStyle, msg)

proc showWarning*(msg: string) =
  ## 警告メッセージを表示する
  styledEcho(styleBright, fgYellow, "Warning: ", resetStyle, msg)

proc showInfo*(msg: string) =
  ## 情報メッセージを表示する
  styledEcho(styleBright, fgCyan, "Info: ", resetStyle, msg)

proc showSuccess*(msg: string) =
  ## 成功メッセージを表示する
  styledEcho(styleBright, fgGreen, "Success: ", resetStyle, msg)

type
  CliOptions* = object
    # Core options
    nimVersion*: string
    verbose*: bool
    includeDev*: bool
    parallelJobs*: int
    cacheDir*: string
    force*: bool
    autoLock*: bool
    lockfile*: string
    nimbleDir*: string
    
    # Resolver options
    useResolver*: bool         # Use SAT solver-based resolver
    minimalVersions*: bool     # Prefer minimal versions
    conservativeVersions*: bool # Prefer currently installed versions
    forceResolve*: bool       # Force re-resolution ignoring lockfile
    
    # Project generation options (for scaffold integration)
    description*: string  # Project description
    author*: string       # Project author
    license*: string      # Project license
    dirPath*: string      # Project directory

# この関数の初期宣言
proc initProject*(options: CliOptions): bool

proc newCliOptions*(nimVersion: string = "", verbose: bool = false, includeDev: bool = false,
                   parallelJobs: int = 0, cacheDir: string = "", force: bool = false,
                   autoLock: bool = true, lockfile: string = "nimble.lock",
                   nimbleDir: string = ".niuv/deps", useResolver: bool = false,
                   minimalVersions: bool = false, conservativeVersions: bool = false,
                   forceResolve: bool = false, description: string = "",
                   author: string = "", license: string = "MIT", 
                   dirPath: string = ""): CliOptions =
  ## デフォルトのCLIオプションを作成する
  result = CliOptions(
    # Core options
    nimVersion: nimVersion,
    verbose: verbose,
    includeDev: includeDev,
    parallelJobs: parallelJobs,  # 0は自動（CPUコア数）
    cacheDir: cacheDir,
    force: force,
    autoLock: autoLock,
    lockfile: lockfile,
    nimbleDir: nimbleDir,
    
    # Resolver options
    useResolver: useResolver,
    minimalVersions: minimalVersions,
    conservativeVersions: conservativeVersions,
    forceResolve: forceResolve,
    
    # Project generation options
    description: description,
    author: author,
    license: license,
    dirPath: dirPath
  )

proc parseOptions*(args: seq[string], options: var CliOptions) =
  ## コマンドライン引数をパースする
  var p = initOptParser(args)

  while true:
    p.next()
    case p.kind
    of cmdEnd: break
    of cmdLongOption, cmdShortOption:
      case p.key
      # Core options
      of "nim-version", "n":
        options.nimVersion = p.val
      of "verbose", "v":
        options.verbose = true
      of "dev", "d":
        options.includeDev = true
      of "parallel", "j":
        if p.val != "":
          options.parallelJobs = parseInt(p.val)
      of "cache-dir", "c":
        options.cacheDir = p.val
      of "force", "f":
        options.force = true
      of "no-lock":
        options.autoLock = false
      of "lockfile", "l":
        options.lockfile = p.val
      of "nimble-dir":
        options.nimbleDir = p.val
      
      # Resolver options
      of "use-resolver":
        options.useResolver = true
      of "minimal-versions":
        options.minimalVersions = true
      of "conservative-versions":
        options.conservativeVersions = true
      of "force-resolve":
        options.forceResolve = true
        
      # Project generation options
      of "desc", "description":
        options.description = p.val
      of "author", "a":
        options.author = p.val
      of "license":
        options.license = p.val
      of "dir":
        options.dirPath = p.val
        
      of "help", "h":
        # ヘルプフラグはメイン関数で処理
        discard
      of "init":
        # テスト用デバッグ出力
        let isTestMode = getEnv("NIUV_TEST_MODE") == "1"
        if isTestMode:
          echo "[DEBUG parseOptions] Init flag detected"

        if not initProject(options):
          if isTestMode:
            echo "[DEBUG parseOptions] initProject failed"
          quit(1)

        if isTestMode:
          echo "[DEBUG parseOptions] initProject succeeded"
        quit(0)
      else:
        styledEcho(styleBright, fgYellow, "Warning: Unknown option: ", p.key)
    of cmdArgument:
      # 引数はメイン関数で処理済み
      discard


proc initProject*(options: CliOptions): bool =
  ## 新しいniuvプロジェクトを初期化
  # テスト用デバッグ出力
  let isTestMode = getEnv("NIUV_TEST_MODE") == "1"
  if isTestMode:
    echo "[DEBUG initProject wrapper] Called initProject in cli.nim"

  # デバッグの場合、自分で作業を実施
  var configFile = getCurrentDir() / "niuv.toml"

  # テストモードの場合はテストホームを使用
  let testHome = getEnv("NIUV_TEST_HOME")
  let useTestHome = isTestMode and testHome.len > 0
  if useTestHome:
    configFile = testHome / "niuv.toml"

  # 既存ファイルがある場合
  if fileExists(configFile):
    if isTestMode:
      echo "[DEBUG initProject wrapper] Config file already exists"
    return false

  # 新規ファイルを作成
  try:
    # デフォルトの内容
    let content = "[tool.niuv]\nnim_version = \"" & options.nimVersion &
      "\"\nparallel_jobs = " & $options.parallelJobs &
      "\nauto_lock = " & $options.autoLock &
      "\nlockfile = \"" & options.lockfile &
      "\"\nnimble_dir = \"" & options.nimbleDir &
      "\"\nverbose_output = " & $options.verbose &
      "\nshell_integration = true\n"

    # テスト環境の場合、ディレクトリの存在を確認
    if useTestHome and not dirExists(testHome):
      try:
        createDir(testHome)
      except:
        discard  # テスト中のエラーは無視

    writeFile(configFile, content)

    if isTestMode:
      echo "[DEBUG initProject wrapper] Created file: " & configFile

    return true
  except:
    if isTestMode:
      echo "[DEBUG initProject wrapper] Failed to create file"
    return false


proc confirmPrompt*(question: string): bool =
  ## ユーザーに確認を求める
  # テストモードの場合は特別な対応（テスト環境変数によって回答を決定）
  let isTestMode = getEnv("NIUV_TEST_MODE") == "1"  # 直接使用（環境がインポートされていないので）
  if isTestMode:
    let testResponse = getEnv("NIUV_TEST_RESPONSE", "")
    if testResponse == "y":
      echo question & " [y/N] y"
      return true
    elif testResponse == "n":
      echo question & " [y/N] n"
      return false
    # 応答指定がなければ対話モードに戻る

  stdout.write(question & " [y/N] ")
  let answer = stdin.readLine().toLowerAscii()
  return answer == "y" or answer == "yes"

proc selectOption*[T](options: openArray[T], prompt: string = "Select an option:"): T =
  ## ユーザーにオプションから選択させる
  styledEcho(styleBright, prompt)
  
  for i, option in options:
    echo "  ", i+1, ": ", $option
  
  while true:
    stdout.write("Enter number (1-" & $options.len & "): ")
    let input = stdin.readLine()
    
    try:
      let choice = parseInt(input)
      if choice >= 1 and choice <= options.len:
        return options[choice-1]
    except:
      discard
    
    showError("Invalid selection. Please enter a number between 1 and " & $options.len)

proc progressBar*(current, total: int, width: int = 40) =
  ## プログレスバーを表示する
  let percent = if total > 0: current * 100 div total else: 100
  let numChars = if total > 0: current * width div total else: width
  
  stdout.write("\r[")
  for i in 0..<width:
    if i < numChars:
      stdout.write("#")
    else:
      stdout.write(" ")
  
  stdout.write("] " & align($percent, 3) & "%")
  stdout.flushFile()
  
  if current >= total:
    stdout.write("\n")

proc showSpinner*(msg: string): proc () =
  ## スピナーを表示する（非ブロッキング）
  var spinChars = @["|", "/", "-", "\\"]
  var i = 0
  var active = true
  
  # スピナーを更新するプロシージャ
  proc update() {.thread, nimcall.} =
    while active:
      stdout.write("\r" & msg & " " & spinChars[i])
      stdout.flushFile()
      i = (i + 1) mod spinChars.len
      sleep(100)
  
  # 新しいスレッドでスピナーを実行
  var thread: Thread[void]
  createThread(thread, update)
  
  # スピナーを停止するプロシージャを返す
  proc stop() =
    active = false
    joinThread(thread)
    stdout.write("\r" & msg & " Done!     \n")
  
  return stop

proc tableOutput*(data: Table[string, string]) =
  ## テーブル形式でデータを表示する
  var maxKeyLen = 0
  for key in data.keys:
    maxKeyLen = max(maxKeyLen, key.len)
  
  for key, value in data.pairs:
    let paddedKey = key & " ".repeat(maxKeyLen - key.len)
    styledEcho(styleBright, paddedKey, ": ", resetStyle, value)