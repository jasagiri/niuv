import std/[strutils, osproc, logging, json, os, re, strtabs]
import std/cpuinfo as cpu
import nim_detector

type
  NimblePackage* = object
    name*: string
    version*: string
    isDev*: bool

export NimblePackage  # テストで使用するため明示的にエクスポート

from std/times import getTime, toUnix

export cpu.countProcessors  # config.nimで使用するためエクスポート

# Nimコンパイラコマンドを取得するグローバル関数
proc getNimCommand*(): string =
  ## 利用可能なNimコンパイラのパスを返す
  getNimCommand("")

# ログ機能
var logger = newConsoleLogger(lvlInfo, "[$levelname] ")

proc setupLogging*(verbose: bool) =
  if verbose:
    logger.levelThreshold = lvlDebug
  else:
    logger.levelThreshold = lvlInfo
  addHandler(logger)

proc logDebug*(msg: string) =
  debug(msg)

proc logInfo*(msg: string) =
  info(msg)

proc logWarning*(msg: string) =
  warn(msg)

proc logError*(msg: string) =
  error(msg)

# プロセス実行ユーティリティ
proc execProcessEnv*(command: string, workingDir: string = "", env: StringTableRef = nil): int =
  ## 環境変数を設定してプロセスを実行する
  when defined(windows):
    let comspec = getEnv("COMSPEC", "cmd.exe")
    let p = startProcess(comspec, args=["/c", command], workingDir=workingDir, env=env)
    result = p.waitForExit()
    p.close()
  else:
    let shell = getEnv("SHELL", "/bin/sh")
    let p = startProcess(shell, args=["-c", command], workingDir=workingDir, env=env)
    result = p.waitForExit()
    p.close()

# プロジェクト関連のユーティリティ
proc findNimbleFile*(): string =
  ## カレントディレクトリから.nimbleファイルを検索する
  for file in walkFiles("*.nimble"):
    return file
  return ""

proc getProjectName*(): string =
  ## プロジェクト名を取得する
  let nimbleFile = findNimbleFile()
  if nimbleFile == "":
    return ""
  
  return extractFilename(nimbleFile).replace(".nimble", "")

# キャッシュ関連のユーティリティ
proc createCacheDir*(): bool =
  ## キャッシュディレクトリを作成する
  let cacheDir = getHomeDir() / ".niuv" / "cache"
  if not dirExists(cacheDir):
    try:
      createDir(cacheDir)
      return true
    except CatchableError as e:
      logWarning("Failed to create cache directory: " & cacheDir & " - Error: " & e.msg)
      return false
  return true

proc getCachedPackagePath*(packageName, version: string): string =
  ## キャッシュされたパッケージのパスを取得する
  let cacheDir = getHomeDir() / ".niuv" / "cache"
  let versionSuffix = if version != "": "-" & replacef(version, re"[<>=@]", "") else: ""
  let cachePath = cacheDir / (packageName & versionSuffix)
  
  if dirExists(cachePath):
    return cachePath
  
  # バージョン指定がない場合は、任意のバージョンを探す
  if version == "" or version.startsWith(">") or version.startsWith("<"):
    for kind, path in walkDir(cacheDir):
      if kind == pcDir and extractFilename(path).startsWith(packageName & "-"):
        return path
  
  return ""

proc savePackageToCache*(packageName, version: string, sourcePath: string): bool =
  ## パッケージをキャッシュに保存する
  if packageName.len == 0:
    logWarning("Cannot save package with empty name to cache")
    return false

  if not dirExists(sourcePath):
    logWarning("Source path does not exist: " & sourcePath)
    return false

  let cacheDir = getHomeDir() / ".niuv" / "cache"
  let versionSuffix = if version != "": "-" & replacef(version, re"[<>=@]", "") else: ""
  let cachePath = cacheDir / (packageName & versionSuffix)

  if not dirExists(cacheDir):
    try:
      createDir(cacheDir)
    except CatchableError as e:
      logWarning("Failed to create cache directory: " & cacheDir & " - Error: " & e.msg)
      return false

  # 既存のキャッシュがあれば削除
  if dirExists(cachePath):
    try:
      removeDir(cachePath)
    except CatchableError as e:
      logWarning("Failed to remove existing cache: " & cachePath & " - Error: " & e.msg)
      return false

  try:
    copyDir(sourcePath, cachePath)

    # キャッシュメタデータを作成
    let metaPath = cachePath / ".niuv-meta.json"
    let metaData = %* {
      "name": packageName,
      "version": version,
      "timestamp": $getTime().toUnix()
    }
    writeFile(metaPath, pretty(metaData))

    return true
  except CatchableError as e:
    logWarning("Failed to save package to cache: " & cachePath & " - Error: " & e.msg)
    return false

# 文字列処理ユーティリティ
proc truncateString*(s: string, maxLen: int): string =
  ## 文字列を指定した長さに切り詰める
  if s.len <= maxLen:
    return s
  return s[0..<(maxLen-3)] & "..."

proc formatDuration*(seconds: float): string =
  ## 秒数を読みやすい形式にフォーマットする
  if seconds < 0.001:
    return formatFloat(seconds * 1000000, ffDecimal, 2) & " μs"
  elif seconds < 1:
    return formatFloat(seconds * 1000, ffDecimal, 2) & " ms"
  elif seconds < 60:
    return formatFloat(seconds, ffDecimal, 2) & " s"
  elif seconds < 3600:
    let mins = int(seconds / 60)
    let secs = seconds - float(mins * 60)
    return $mins & " min " & formatFloat(secs, ffDecimal, 0) & " s"
  else:
    let hours = int(seconds / 3600)
    let mins = int((seconds - float(hours * 3600)) / 60)
    let secs = seconds - float(hours * 3600) - float(mins * 60)
    return $hours & " h " & $mins & " min " & formatFloat(secs, ffDecimal, 0) & " s"

# ファイルシステムユーティリティ
proc ensureDirExists*(dir: string): bool =
  ## ディレクトリが存在することを確認し、存在しなければ作成する
  if dir.len == 0:
    logWarning("Cannot create directory with empty path")
    return false

  if dirExists(dir):
    return true

  try:
    createDir(dir)
    return dirExists(dir)  # 作成したら必ず存在を確認
  except CatchableError as e:
    logWarning("Failed to create directory: " & dir & " - Error: " & e.msg)
    return false

proc cleanBuildArtifacts*(verbose: bool): bool =
  ## ビルドアーティファクトを削除する
  try:
    logInfo("Cleaning build artifacts...")

    # ビルドディレクトリを削除
    if dirExists("build"):
      removeDir("build")
      if verbose: logInfo("Removed: build/")

    # nimcache ディレクトリを削除
    if dirExists("nimcache"):
      removeDir("nimcache")
      if verbose: logInfo("Removed: nimcache/")

    # テストの実行ファイルを削除
    for kind, path in walkDir("tests", relative=false):
      if kind == pcFile and
         not path.endsWith(".nim") and
         (path.extractFilename().startsWith("test_") or path == "testutils"):
        removeFile(path)
        if verbose: logInfo("Removed: " & path)

    # デバッグシンボルディレクトリを削除
    for path in walkDirRec(".", {pcDir}):
      if path.endsWith(".dSYM"):
        removeDir(path)
        if verbose: logInfo("Removed: " & path)

    # 必要なディレクトリを再作成
    createDir("build/bin")
    createDir("build/tests")
    createDir("build/nimcache")
    createDir("build/docs")
    createDir("build/coverage")

    return true
  except CatchableError as e:
    logError("Failed to clean build artifacts: " & e.msg)
    return false

proc cleanAll*(verbose: bool): bool =
  ## すべてのアーティファクトとnimbledepsを削除する
  try:
    # まず通常のクリーンを実行
    discard cleanBuildArtifacts(verbose)

    # nimbledepsディレクトリを削除
    if dirExists("nimbledeps"):
      logInfo("Cleaning nimbledeps...")
      removeDir("nimbledeps")
      if verbose: logInfo("Removed: nimbledeps/")

    # nimbledepsディレクトリを再作成
    createDir("nimbledeps/pkgs")
    createDir("nimbledeps/pkgcache")

    return true
  except CatchableError as e:
    logError("Failed to clean all artifacts: " & e.msg)
    return false

proc safeCopyDir*(src, dest: string): bool =
  ## 安全にディレクトリをコピーする
  if src.len == 0 or dest.len == 0:
    logWarning("Source or destination path is empty")
    return false

  if not dirExists(src):
    logWarning("Source directory does not exist: " & src)
    return false

  if src == dest:
    logWarning("Source and destination directories are the same: " & src)
    return false

  if dirExists(dest):
    try:
      removeDir(dest)
    except CatchableError as e:
      logWarning("Failed to remove destination directory: " & dest & " - Error: " & e.msg)
      return false

  try:
    # Ensure parent directory exists
    let parentDir = parentDir(dest)
    if not dirExists(parentDir):
      if not ensureDirExists(parentDir):
        return false

    copyDir(src, dest)
    return dirExists(dest)  # 確実にコピーされたか確認
  except CatchableError as e:
    logWarning("Failed to copy directory from " & src & " to " & dest & " - Error: " & e.msg)
    return false

proc isSymlink*(path: string): bool =
  ## パスがシンボリックリンクかどうかを判定する
  if path.len == 0 or not fileExists(path) and not dirExists(path):
    return false

  when defined(windows):
    # Windowsではシンボリックリンクの判定が複雑なので、簡易的な実装
    try:
      let attr = getFileInfo(path).kind
      return attr == pcLinkToFile or attr == pcLinkToDir
    except CatchableError:
      return false
  else:
    try:
      let info = getFileInfo(path, followSymlink=false)
      return info.kind == pcLinkToFile or info.kind == pcLinkToDir
    except CatchableError:
      return false

proc resolveSymlink*(path: string): string =
  ## シンボリックリンクを解決する
  if path.len == 0:
    return ""

  when defined(windows):
    return path  # Windowsでは簡易実装
  else:
    if isSymlink(path):
      try:
        return expandSymlink(path)
      except CatchableError:
        logWarning("Failed to resolve symlink: " & path)
        return path  # 解決に失敗した場合は元のパスを返す
    return path

# システム情報ユーティリティ
proc getSystemInfo*(): JsonNode =
  ## システム情報を取得する
  result = newJObject()

  # OS情報
  result["os"] = %* {
    "name": hostOS,
    "arch": hostCPU
  }

  # CPU情報
  try:
    let cpuCount = cpu.countProcessors()
    result["cpu"] = %* {
      "count": cpuCount
    }
  except CatchableError:
    result["cpu"] = %* {
      "count": 1  # デフォルト値
    }

  # Nim情報 - 新しいnim_detectorを使用
  var nimVersion = "Unknown"
  var nimPath = "nim"
  var nimSource = "unknown"
  
  let bestCompiler = selectBestNimCompiler()
  if bestCompiler.isValid:
    nimVersion = bestCompiler.version
    nimPath = bestCompiler.path
    nimSource = bestCompiler.source
  else:
    # フォールバック: 直接nimコマンドを試す
    try:
      let (output, exitCode) = execCmdEx("nim --version")
      if exitCode == 0:
        for line in output.splitLines():
          if line.startsWith("Nim Compiler Version"):
            nimVersion = line.split("Version")[1].strip()
            break
    except CatchableError as e:
      logWarning("Failed to get Nim version: " & e.msg)

  result["nim"] = %* {
    "version": nimVersion,
    "path": nimPath,
    "source": nimSource
  }

  # User情報
  try:
    let username = getEnv("USER", getEnv("USERNAME", "unknown"))
    let homeDir = getHomeDir()
    result["user"] = %* {
      "name": username,
      "home": homeDir
    }
  except CatchableError:
    discard  # ユーザー情報は省略可能


