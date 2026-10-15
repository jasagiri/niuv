## clean.nim
## ==========
##
## クリーンアップ操作の実装
##

import os, strutils, sets, sequtils

type
  CleanMode* = enum
    cmNormal,     # 通常のクリーン（ビルド成果物の削除）
    cmDetailed,   # 詳細なクリーン（一時ファイル、バックアップの削除）
    cmFull        # 完全なクリーン（nimbledepsを含む）

  CleanConfig* = object
    mode*: CleanMode
    dryRun*: bool      # 実際には削除せず、削除対象のみ表示
    verbose*: bool     # 詳細な情報を表示
    buildDir*: string  # ビルドディレクトリのパス
    dirs*: HashSet[string]       # 削除対象のディレクトリ
    patterns*: HashSet[string]   # 削除対象のファイルパターン

proc newCleanConfig*(mode = cmNormal, dryRun = false, verbose = false): CleanConfig =
  ## クリーン設定の作成
  result = CleanConfig(
    mode: mode,
    dryRun: dryRun,
    verbose: verbose,
    buildDir: "build",
    dirs: ["nimcache", "htmldocs", "coverage", ".DS_Store"].toHashSet,
    patterns: [".DS_Store", "*.bak", "*~", "*.swp", "*.o", "*.gcno", "*.gcda"].toHashSet
  )

  # modeに応じて削除対象を追加
  case mode
  of cmNormal:
    discard
  of cmDetailed:
    # 詳細モードでは一時ファイルやバックアップファイルも削除
    result.dirs.incl("tests/activate")
    result.dirs.incl("tests/build")
    result.dirs.incl("tests/examples")
  of cmFull:
    # 完全モードではnimbledepsも削除
    result.dirs.incl("nimbledeps")

proc ensureDirExists*(path: string) =
  ## ディレクトリが存在することを確認し、存在しなければ作成
  if not dirExists(path):
    try:
      createDir(path)
    except:
      echo "Warning: Unable to create directory: ", path

proc isFileMatch(file: string, patterns: HashSet[string]): bool =
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

proc removeDirectories*(config: CleanConfig): int =
  ## 指定されたディレクトリを削除
  var count = 0
  for dir in config.dirs:
    if dir.len == 0: continue
    
    # ディレクトリの存在確認
    if dirExists(dir):
      if config.verbose or config.dryRun:
        echo "Removing directory: ", dir
      
      if not config.dryRun:
        try:
          removeDir(dir)
          count += 1
        except:
          echo "Warning: Unable to remove directory: ", dir
    elif config.verbose:
      echo "Directory not found: ", dir
  
  count

proc cleanPatterns*(config: CleanConfig): int =
  ## 指定されたパターンに一致するファイルを削除
  var count = 0
  
  # カレントディレクトリからの再帰的な検索
  var filesToRemove: seq[string] = @[]
  
  for path in walkDirRec(".", {pcFile}):
    if isFileMatch(path, config.patterns):
      filesToRemove.add(path)
  
  # ファイルの削除
  for file in filesToRemove:
    if config.verbose or config.dryRun:
      echo "Removing file: ", file
    
    if not config.dryRun:
      try:
        removeFile(file)
        count += 1
      except:
        echo "Warning: Unable to remove file: ", file
  
  count

proc cleanBuildArtifacts*(config: CleanConfig): bool =
  ## ビルドアーティファクトを削除する
  try:
    if config.verbose:
      echo "Cleaning build artifacts..."
    
    # ビルドディレクトリを削除
    if dirExists(config.buildDir):
      if config.verbose or config.dryRun:
        echo "Removing: ", config.buildDir
      
      if not config.dryRun:
        removeDir(config.buildDir)
    
    # 指定されたディレクトリを削除
    let dirCount = removeDirectories(config)
    
    # ファイルパターンに一致するファイルを削除
    let fileCount = if config.mode != cmNormal: cleanPatterns(config) else: 0
    
    # 必要なディレクトリを再作成
    if not config.dryRun:
      ensureDirExists(config.buildDir)
      ensureDirExists(config.buildDir / "bin")
      ensureDirExists(config.buildDir / "tests")
      ensureDirExists(config.buildDir / "nimcache")
      ensureDirExists(config.buildDir / "docs")
      
      # 完全モードでnimbledepsを再作成
      if config.mode == cmFull:
        ensureDirExists("nimbledeps/pkgs")
        ensureDirExists("nimbledeps/pkgcache")
    
    if config.verbose:
      echo "Removed ", dirCount, " directories and ", fileCount, " files"
      echo "Clean operation completed successfully"
    
    return true
  except:
    echo "Error during clean operation: ", getCurrentExceptionMsg()
    return false

proc cleanAll*(config: CleanConfig): bool =
  ## 完全なクリーンアップを実行
  var fullConfig = config
  fullConfig.mode = cmFull
  cleanBuildArtifacts(fullConfig)