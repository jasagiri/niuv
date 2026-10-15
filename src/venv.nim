import std/[os, strutils, tables, json, sequtils, times, options]
# import results  # Temporarily disabled for local testing
import ./config, ./utils, ./cli

type
  VenvError* = object of CatchableError
  Venv* = object
    path*: string
    name*: string
    nimVersion*: string
    packages*: Table[string, string]

proc getVenvPath*(name: string): string =
  ## 仮想環境のフルパスを取得する
  let config = getMergedConfig()
  if config.isErr():
    raise newException(VenvError, "Failed to load config: " & config.error)
  result = config.get().venvDir / name

proc createVenv*(name: string, nimVersion: string = ""): Venv =
  ## 新しい仮想環境を作成する
  if name.len == 0:
    raise newException(VenvError, "Environment name cannot be empty")

  # Check if config is valid
  let configRes = getMergedConfig()
  if configRes.isErr():
    raise newException(VenvError, "Failed to load config: " & configRes.error)

  let venvPath = getVenvPath(name)
  if dirExists(venvPath):
    raise newException(VenvError, "Virtual environment already exists: " & name)

  try:
    createDir(venvPath)
  except CatchableError as e:
    raise newException(VenvError, "Failed to create environment directory: " & e.msg)

  # Use provided version or latest stable
  let actualNimVersion = if nimVersion.len > 0: nimVersion else: "2.2.4"

  result = Venv(
    path: venvPath,
    name: name,
    nimVersion: actualNimVersion,
    packages: initTable[string, string]()
  )

  # 必要なディレクトリを作成
  try:
    createDir(venvPath / "nimbledeps")
    createDir(venvPath / "nimbledeps/pkgs")
    createDir(venvPath / "bin")
  except CatchableError as e:
    # Clean up on failure
    try:
      removeDir(venvPath)
    except CatchableError:
      discard
    raise newException(VenvError, "Failed to create environment subdirectories: " & e.msg)

  # 仮想環境用の設定ファイルを作成
  try:
    let configJson = %*{
      "name": name,
      "nimVersion": actualNimVersion,
      "packages": {},
      "created": $now()
    }
    writeFile(venvPath / "venv.json", $configJson)
  except CatchableError as e:
    # Clean up on failure
    try:
      removeDir(venvPath)
    except CatchableError:
      discard
    raise newException(VenvError, "Failed to write environment config: " & e.msg)

  # nim.cfgファイルを作成
  try:
    writeFile(venvPath / "nim.cfg", """
--path:"$1/nimbledeps"
--define:testing
--nimblePath:"$1/nimbledeps/pkgs"
""" % [venvPath])
  except CatchableError as e:
    # Clean up on failure
    try:
      removeDir(venvPath)
    except CatchableError:
      discard
    raise newException(VenvError, "Failed to write nim.cfg: " & e.msg)

  # activateスクリプトを作成
  try:
    when defined(windows):
      writeFile(venvPath / "activate.bat", """
@echo off
set NIUV_ACTIVE_VENV=""" & name & """
set PATH=""" & venvPath & """\bin;%PATH%
echo Activated virtual environment: """ & name & """
""")
    else:
      writeFile(venvPath / "activate", """
#!/bin/sh
export NIUV_ACTIVE_VENV=""" & name & """
export PATH=""" & venvPath & """/bin:$PATH
echo "Activated virtual environment: """ & name & """"
""")
      try:
        setFilePermissions(venvPath / "activate", {fpUserRead, fpUserWrite, fpUserExec})
      except CatchableError as e:
        logWarning("Failed to set permissions on activate script: " & e.msg)
  except CatchableError as e:
    # Clean up on failure
    try:
      removeDir(venvPath)
    except CatchableError:
      discard
    raise newException(VenvError, "Failed to write activation script: " & e.msg)

proc deleteVenv*(name: string) =
  ## 仮想環境を削除する
  if name.len == 0:
    raise newException(VenvError, "Environment name cannot be empty")

  let venvPath = getVenvPath(name)
  if not dirExists(venvPath):
    raise newException(VenvError, "Virtual environment not found: " & name)

  try:
    removeDir(venvPath)
  except CatchableError as e:
    raise newException(VenvError, "Failed to delete environment: " & e.msg)

proc listVenvs*(): seq[Venv] =
  ## 利用可能な仮想環境の一覧を取得する
  result = @[]

  let config = getMergedConfig()
  if config.isErr():
    logWarning("Failed to get config: " & config.error)
    return

  let venvDir = config.get().venvDir
  logDebug("Searching venvs in: " & venvDir)

  # Check if directory exists
  if not dirExists(venvDir):
    logDebug("Venv directory does not exist: " & venvDir)
    logDebug("Current working dir: " & getCurrentDir())
    try:
      # Try to create the directory
      createDir(venvDir)
      logDebug("Created venv directory: " & venvDir)
    except CatchableError as e:
      logWarning("Failed to create venv directory: " & venvDir & " - Error: " & e.msg)
      return
    return  # Return empty list since we just created the directory

  var count = 0
  try:
    for venv in walkDir(venvDir):
      if venv.kind == pcDir:
        let configFile = venv.path / "venv.json"
        if fileExists(configFile):
          try:
            let jsonConfig = parseFile(configFile)
            if jsonConfig.hasKey("name") and jsonConfig.hasKey("nimVersion"):
              var packages = initTable[string, string]()
              if jsonConfig.hasKey("packages") and jsonConfig["packages"].kind == JObject:
                packages = to(jsonConfig["packages"], Table[string, string])

              result.add Venv(
                path: venv.path,
                name: jsonConfig["name"].getStr(),
                nimVersion: jsonConfig["nimVersion"].getStr(),
                packages: packages
              )
              count.inc
            else:
              logWarning("Invalid venv.json (missing required fields) in: " & venv.path)
          except JsonParsingError as e:
            logWarning("Invalid venv.json in: " & venv.path & " - Error: " & e.msg)
            continue  # 無効な設定ファイルはスキップ
          except KeyError as e:
            logWarning("Missing field in venv.json: " & venv.path & " - Error: " & e.msg)
            continue
  except CatchableError as e:
    logWarning("Error listing venvs: " & e.msg)

  logDebug("Found " & $count & " valid venvs")

proc activateVenv*(name: string) =
  ## 仮想環境をアクティベートする
  if name.len == 0:
    raise newException(VenvError, "Environment name cannot be empty")

  let venvPath = getVenvPath(name)
  if not dirExists(venvPath):
    raise newException(VenvError, "Virtual environment not found: " & name)

  # activateスクリプトの存在確認
  let activateScript = when defined(windows): venvPath / "activate.bat" else: venvPath / "activate"
  if not fileExists(activateScript):
    logWarning("Activation script not found: " & activateScript)
    # Try to recreate activation script
    try:
      when defined(windows):
        writeFile(activateScript, """
@echo off
set NIUV_ACTIVE_VENV=""" & name & """
set PATH=""" & venvPath & """\bin;%PATH%
echo Activated virtual environment: """ & name & """
""")
      else:
        writeFile(activateScript, """
#!/bin/sh
export NIUV_ACTIVE_VENV=""" & name & """
export PATH=""" & venvPath & """/bin:$PATH
echo "Activated virtual environment: """ & name & """"
""")
        setFilePermissions(activateScript, {fpUserRead, fpUserWrite, fpUserExec})
    except CatchableError as e:
      logWarning("Failed to recreate activation script: " & e.msg)

  # 環境変数を設定
  try:
    putEnv("NIUV_ACTIVE_VENV", name)
    when defined(windows):
      putEnv("PATH", venvPath / "bin" & ";" & getEnv("PATH"))
    else:
      putEnv("PATH", venvPath / "bin" & ":" & getEnv("PATH"))
    logDebug("Activated environment: " & name)
  except CatchableError as e:
    raise newException(VenvError, "Failed to activate environment: " & e.msg)