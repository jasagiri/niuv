## fs.nim
## ======
##
## ファイルシステム操作ユーティリティ
##

import std/[os, strutils, sets, logging, times]

proc logInfo*(msg: string) =
  info(msg)

proc logWarning*(msg: string) =
  warn(msg)

proc logError*(msg: string) =
  error(msg)

proc ensureDirExists*(path: string): bool =
  ## ディレクトリが存在することを確認し、必要に応じて作成
  result = true
  
  if path.len == 0:
    logWarning("Cannot create directory with empty path")
    return false
    
  if dirExists(path):
    return true
  
  try:
    createDir(path)
    return dirExists(path)  # 作成したら必ず存在を確認
  except:
    logWarning("Warning: Unable to create directory: " & path)
    result = false

proc removeIfExists*(path: string): bool =
  ## パスが存在する場合に削除
  ## 戻り値：削除成功か（存在しなかった場合もtrue）
  result = true
  
  if fileExists(path):
    try:
      removeFile(path)
    except:
      logWarning("Warning: Unable to remove file: " & path)
      result = false
  elif dirExists(path):
    try:
      removeDir(path)
    except:
      logWarning("Warning: Unable to remove directory: " & path)
      result = false

proc cleanDirectory*(dir: string, keepDir = true): bool =
  ## ディレクトリの中身を削除
  ## keepDir: ディレクトリ自体は残す場合はtrue
  result = true
  
  if not dirExists(dir):
    return true
  
  try:
    if keepDir:
      for kind, path in walkDir(dir):
        case kind
        of pcFile, pcLinkToFile:
          removeFile(path)
        of pcDir, pcLinkToDir:
          removeDir(path)
    else:
      removeDir(dir)
  except:
    logWarning("Warning: Unable to clean directory: " & dir)
    result = false

proc findFiles*(dir, pattern: string, recursive = true): seq[string] =
  ## 指定ディレクトリから指定パターンに一致するファイルを検索
  result = @[]
  
  if not dirExists(dir):
    return result
  
  for kind, path in walkDir(dir, relative = false):
    if kind == pcFile:
      let fileName = path.extractFilename
      # 単純なワイルドカードマッチング
      if pattern.contains("*"):
        let parts = pattern.split("*")
        if parts.len == 1:
          # パターンが * だけの場合、すべてのファイル
          result.add(path)
        elif parts.len == 2:
          if parts[0].len == 0:  # *suffix
            if fileName.endsWith(parts[1]):
              result.add(path)
          elif parts[1].len == 0:  # prefix*
            if fileName.startsWith(parts[0]):
              result.add(path)
          else:  # prefix*suffix
            if fileName.startsWith(parts[0]) and fileName.endsWith(parts[1]):
              result.add(path)
      elif fileName == pattern:
        result.add(path)
    
    elif kind == pcDir and recursive:
      let subResults = findFiles(path, pattern, true)
      result.add(subResults)

proc findDirs*(dir, pattern: string, recursive = true): seq[string] =
  ## 指定ディレクトリから指定パターンに一致するディレクトリを検索
  result = @[]
  
  if not dirExists(dir):
    return result
  
  for kind, path in walkDir(dir, relative = false):
    if kind == pcDir:
      let dirName = path.extractFilename
      var matches = false
      
      # 単純なワイルドカードマッチング
      if pattern.contains("*"):
        let parts = pattern.split("*")
        if parts.len == 1:
          # パターンが * だけの場合、すべてのディレクトリ
          matches = true
        elif parts.len == 2:
          if parts[0].len == 0:  # *suffix
            matches = dirName.endsWith(parts[1])
          elif parts[1].len == 0:  # prefix*
            matches = dirName.startsWith(parts[0])
          else:  # prefix*suffix
            matches = dirName.startsWith(parts[0]) and dirName.endsWith(parts[1])
      elif dirName == pattern:
        matches = true
      
      if matches:
        result.add(path)
      
      if recursive:
        let subResults = findDirs(path, pattern, true)
        result.add(subResults)

proc copyDir*(source, dest: string, overwrite = true): bool =
  ## ディレクトリを再帰的にコピー
  result = true
  
  if not dirExists(source):
    logError("Error: Source directory does not exist: " & source)
    return false
  
  if not ensureDirExists(dest):
    return false
  
  for kind, path in walkDir(source):
    let destPath = dest / path.extractFilename
    
    case kind
    of pcFile, pcLinkToFile:
      try:
        if overwrite or not fileExists(destPath):
          copyFile(path, destPath)
      except:
        logWarning("Warning: Unable to copy file: " & path)
        result = false
    
    of pcDir, pcLinkToDir:
      if not copyDir(path, destPath, overwrite):
        result = false

proc isFileMatch*(file: string, patterns: HashSet[string]): bool =
  ## ファイルが指定されたパターンに一致するかチェック
  let filename = file.extractFilename
  for pattern in patterns:
    if pattern.contains("*"):
      # アスタリスクを含むパターンの場合、簡易的なワイルドカードマッチング
      let (prefix, suffix) = if pattern.startsWith("*"):
        ("", pattern[1..^1])
      elif pattern.endsWith("*"):
        (pattern[0..^2], "")
      else:
        let parts = pattern.split("*")
        if parts.len == 2:
          (parts[0], parts[1])
        else:
          continue
      
      if (prefix.len == 0 or filename.startsWith(prefix)) and
         (suffix.len == 0 or filename.endsWith(suffix)):
        return true
    else:
      # 完全一致
      if filename == pattern:
        return true
  false

proc getFileModificationTime*(file: string): int64 =
  ## ファイルの最終更新時間を取得（Unix timestamp）
  if not fileExists(file):
    return 0
    
  try:
    let modTime = getLastModificationTime(file)
    return toUnix(modTime)  # Convert TimeInfo to Unix timestamp
  except:
    return 0

proc isSymlink*(path: string): bool =
  ## パスがシンボリックリンクかどうかを判定する
  if path.len == 0 or not fileExists(path) and not dirExists(path):
    return false

  when defined(windows):
    # Windowsではシンボリックリンクの判定が複雑なので、簡易的な実装
    try:
      let attr = getFileInfo(path).kind
      return attr == pcLinkToFile or attr == pcLinkToDir
    except:
      return false
  else:
    try:
      let info = getFileInfo(path, followSymlink=false)
      return info.kind == pcLinkToFile or info.kind == pcLinkToDir
    except:
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
      except:
        logWarning("Failed to resolve symlink: " & path)
        return path  # 解決に失敗した場合は元のパスを返す
    return path
    
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
    except:
      logWarning("Failed to remove destination directory: " & dest)
      return false

  try:
    # Ensure parent directory exists
    let parentDir = parentDir(dest)
    if not dirExists(parentDir):
      if not ensureDirExists(parentDir):
        return false

    discard copyDir(src, dest)
    return dirExists(dest)  # 確実にコピーされたか確認
  except:
    logWarning("Failed to copy directory from " & src & " to " & dest)
    return false

when isMainModule:
  # テスト用のコード
  echo "File system utilities test"
  
  # ディレクトリ作成のテスト
  let testDir = "test_dir"
  echo "Creating directory: ", testDir
  if ensureDirExists(testDir):
    echo "Success!"
  else:
    echo "Failed!"
    
  # ファイル検索のテスト
  echo "Finding .nim files in current directory:"
  let nimFiles = findFiles(".", "*.nim")
  for file in nimFiles:
    echo "Found: ", file
    
  # クリーンアップ
  removeIfExists(testDir)