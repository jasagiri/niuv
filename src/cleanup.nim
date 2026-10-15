import std/[os, re, times, strutils]

proc isTestEnvironmentDir(dirPath: string): bool =
  ## テスト環境ディレクトリかどうかを判定する
  ## 例: env1_1746093832.445277, active_env_1746094206.870977
  let dirName = lastPathPart(dirPath)
  
  # 正規表現でテスト環境ディレクトリかどうか判定
  let envPattern = re"^(env\d+|active_env)_\d+\.\d+$"
  return dirName.match(envPattern)

proc isOlderThan(dirPath: string, hours: int): bool =
  ## ディレクトリが指定した時間より古いかどうかを判定する
  try:
    let fileInfo = getFileInfo(dirPath)
    let lastModTime = fileInfo.lastWriteTime
    let currentTime = getTime()
    let diffTime = currentTime - lastModTime
    
    return diffTime > initDuration(hours = hours)
  except:
    # エラーが発生した場合は古いと判断する（安全に削除するため）
    return true

proc cleanupTestEnvironments*(rootDir: string = getCurrentDir(), dryRun: bool = false,
                             olderThanHours: int = 24): seq[string] =
  ## テスト環境ディレクトリをクリーンアップする
  ## rootDir: クリーンアップを開始するルートディレクトリ
  ## dryRun: 削除せず、削除対象を表示するだけの場合はtrue
  ## olderThanHours: 指定時間より古いディレクトリのみ削除
  
  result = @[]
  
  for dirPath in walkDir(rootDir, relative = false):
    if dirPath.kind == pcDir:
      # テスト環境ディレクトリかつ指定時間より古い場合
      if isTestEnvironmentDir(dirPath.path) and isOlderThan(dirPath.path, olderThanHours):
        result.add(dirPath.path)
        
        if not dryRun:
          try:
            echo "Removing old test environment: ", dirPath.path
            removeDir(dirPath.path)
          except:
            echo "Warning: Failed to remove directory: ", dirPath.path

proc cleanupAllTestEnvironments*(dryRun: bool = false, olderThanHours: int = 24): int =
  ## プロジェクト内のすべてのテスト環境ディレクトリをクリーンアップする
  ## dryRun: 削除せず、削除対象を表示するだけの場合はtrue
  ## olderThanHours: 指定時間より古いディレクトリのみ削除
  ## 戻り値: 削除したディレクトリの数
  
  let rootDir = getCurrentDir()
  let dirsToRemove = cleanupTestEnvironments(rootDir, dryRun, olderThanHours)
  
  if dryRun:
    echo "Dry run: ", dirsToRemove.len, " directories would be removed:"
    for dir in dirsToRemove:
      echo "  ", dir
  else:
    echo "Cleaned up ", dirsToRemove.len, " old test environment directories"
  
  return dirsToRemove.len

when isMainModule:
  import parseopt
  
  var 
    dryRun = false
    olderThanHours = 24
  
  var p = initOptParser()
  while true:
    p.next()
    case p.kind
    of cmdEnd: break
    of cmdShortOption, cmdLongOption:
      case p.key
      of "dry-run", "n":
        dryRun = true
      of "hours", "h":
        try:
          olderThanHours = parseInt(p.val)
        except:
          echo "Invalid hour value, using default (24)"
      of "help":
        echo "Usage: cleanup [options]"
        echo "Options:"
        echo "  --dry-run, -n     Don't actually remove any files, just show what would be removed"
        echo "  --hours=X, -h X   Remove files older than X hours (default: 24)"
        quit(0)
    of cmdArgument:
      # 引数は無視
      discard
  
  discard cleanupAllTestEnvironments(dryRun, olderThanHours)