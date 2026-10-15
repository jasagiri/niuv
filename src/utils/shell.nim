## shell.nim
## =========
##
## シェル操作ユーティリティ
##

import std/[os, osproc, strutils, logging, strtabs]

proc logInfo*(msg: string) =
  info(msg)

proc logWarning*(msg: string) =
  warn(msg)

proc logError*(msg: string) =
  error(msg)

proc runCommand*(cmd: string, verbose = false): tuple[exitCode: int, output: string] =
  ## コマンドを実行し、終了コードと出力を返す
  if verbose:
    logInfo("Executing: " & cmd)
  
  # execCmdEx returns (output, exitCode), but we want (exitCode, output)
  let cmdResult = execCmdEx(cmd)
  result = (exitCode: cmdResult[1], output: cmdResult[0])
  
  if verbose:
    if result.output.len > 0:
      logInfo(result.output)
    
    if result.exitCode != 0:
      logWarning("Command failed with exit code: " & $result.exitCode)
    else:
      logInfo("Command completed successfully")
  
  return result

proc runCommandWithEnv*(cmd: string, env: StringTableRef = nil, workingDir: string = "", verbose = false): tuple[exitCode: int, output: string] =
  ## 環境変数とワーキングディレクトリを指定してコマンドを実行
  if verbose:
    logInfo("Executing: " & cmd)
    if workingDir.len > 0:
      logInfo("Working directory: " & workingDir)
  
  # execProcessを使ってコマンドを実行する
  var currentDir = getCurrentDir()
  
  if workingDir.len > 0:
    try:
      setCurrentDir(workingDir)
    except:
      logError("Failed to change to directory: " & workingDir)
  
  let cmdResult = execCmdEx(cmd, options = {poStdErrToStdOut, poUsePath, poEvalCommand}, env = env)
  let output = cmdResult[0]
  let exitCode = cmdResult[1]
  
  # 元のディレクトリに戻る
  if workingDir.len > 0:
    try:
      setCurrentDir(currentDir)
    except:
      logError("Failed to return to directory: " & currentDir)
  
  if verbose:
    if output.len > 0:
      logInfo(output)
    
    if exitCode != 0:
      logWarning("Command failed with exit code: " & $exitCode)
    else:
      logInfo("Command completed successfully")
  
  return (exitCode, output)

proc execProcessEnv*(command: string, workingDir: string = "", env: StringTableRef = nil): int =
  ## 環境変数を設定してプロセスを実行する（出力表示あり）
  when defined(windows):
    let comspec = getEnv("COMSPEC", "cmd.exe")
    let cmd = comspec & " /c " & command
    let p = startProcess(cmd, workingDir=workingDir, env=env, options={poStdErrToStdOut, poParentStreams})
    result = p.waitForExit()
    p.close()
  else:
    let shell = getEnv("SHELL", "/bin/sh")
    let cmd = shell & " -c \"" & command.replace("\"", "\\\"") & "\""
    let p = startProcess(cmd, workingDir=workingDir, env=env, options={poStdErrToStdOut, poParentStreams})
    result = p.waitForExit()
    p.close()

proc getWorkingDirectory*(): string =
  ## 現在の作業ディレクトリを取得
  return getCurrentDir()

proc getHomeDirectory*(): string =
  ## ホームディレクトリを取得
  when defined(windows):
    return getEnv("USERPROFILE")
  else:
    return getEnv("HOME")

proc getTempDirectory*(): string =
  ## 一時ディレクトリを取得
  when defined(windows):
    return getEnv("TEMP")
  else:
    return "/tmp"

proc isWindows*(): bool =
  ## Windowsプラットフォームかどうかを判定
  when defined(windows):
    return true
  else:
    return false

proc isMacOS*(): bool =
  ## macOSプラットフォームかどうかを判定
  when defined(macosx):
    return true
  else:
    return false

proc isLinux*(): bool =
  ## Linuxプラットフォームかどうかを判定
  when defined(linux):
    return true
  else:
    return false

proc getPlatformPathSeparator*(): char =
  ## プラットフォーム固有のパス区切り文字を取得
  when defined(windows):
    return '\\'
  else:
    return '/'

proc getPlatformExecutableExtension*(): string =
  ## プラットフォーム固有の実行可能ファイル拡張子を取得
  when defined(windows):
    return ".exe"
  else:
    return ""

proc getPlatformScriptExtension*(): string =
  ## プラットフォーム固有のスクリプト拡張子を取得
  when defined(windows):
    return ".bat"
  else:
    return ".sh"

proc getPlatformShellCommand*(): string =
  ## プラットフォーム固有のシェルコマンドを取得
  when defined(windows):
    return "cmd.exe /c"
  else:
    return "/bin/sh -c"

proc findExecutableInPath*(executable: string): string =
  ## PATHからバイナリを検索
  result = ""
  
  # プラットフォームに応じた拡張子追加
  var exeName = executable
  when defined(windows):
    if not exeName.endsWith(".exe"):
      exeName &= ".exe"
  
  # フルパスが与えられた場合はそのまま返す
  if fileExists(exeName):
    return absolutePath(exeName)
  
  # PATHを取得して検索
  let path = getEnv("PATH")
  let pathSep = when defined(windows): ';' else: ':'
  
  for dir in path.split(pathSep):
    let fullPath = dir / exeName
    if fileExists(fullPath):
      return fullPath
  
  return result  # 見つからなかった場合は空文字列

proc setEnvVars*(vars: openArray[(string, string)]): StringTableRef =
  ## 現在の環境変数に新しい変数を追加したStringTableRefを作成
  var currentEnv = newStringTable(modeCaseSensitive)
  
  # 現在の環境変数をコピー
  for key, val in envPairs():
    currentEnv[key] = val
  
  # 新しい変数を追加/更新
  for (key, val) in vars:
    currentEnv[key] = val
  
  return currentEnv

proc shellEscape*(s: string): string =
  ## シェルコマンドに安全に使用できるようにエスケープ
  when defined(windows):
    # Windowsの場合は二重引用符でくくる
    if s.contains(" ") or s.contains("\"") or s.contains("&") or s.contains("|") or s.contains("<") or s.contains(">"):
      return "\"" & s.replace("\"", "\"\"") & "\""
    return s
  else:
    # Unix-likeの場合はシングルクォートでくくる
    if s.contains("'"):
      # シングルクォートを含む場合は特殊処理
      return "'" & s.replace("'", "'\\''") & "'"
    elif s.contains(" ") or s.contains("\"") or s.contains("$") or s.contains("`") or s.contains("\\"):
      return "'" & s & "'"
    return s

when isMainModule:
  # テスト用のコード
  echo "Shell utilities test"
  
  # コマンド実行テスト
  let (exitCode, output) = runCommand("echo Hello, world!", true)
  echo "Exit code: ", exitCode
  echo "Output: ", output
  
  # 環境変数取得テスト
  echo "Working directory: ", getWorkingDirectory()
  echo "Home directory: ", getHomeDirectory()
  echo "Temp directory: ", getTempDirectory()
  
  # プラットフォーム情報
  echo "Platform is Windows: ", isWindows()
  echo "Platform is macOS: ", isMacOS()
  echo "Platform is Linux: ", isLinux()
  echo "Path separator: ", getPlatformPathSeparator()
  echo "Executable extension: ", getPlatformExecutableExtension()
  echo "Script extension: ", getPlatformScriptExtension()
  echo "Shell command: ", getPlatformShellCommand()