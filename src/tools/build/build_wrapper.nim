## build_wrapper.nim
## =================
##
## ビルド操作のコマンドラインラッパー
##

import os, parseopt, strutils
import "./build"

proc showHelp() =
  echo "Build Tool - ビルド操作"
  echo "Usage: build_wrapper [options] [target]"
  echo "Options:"
  echo "  --mode=DEBUG|RELEASE   ビルドモードの指定 (デフォルト: RELEASE)"
  echo "  --file=FILE            ビルド対象のファイル (btTestの場合)"
  echo "  --verbose              詳細な情報を表示"
  echo "  --help                 このヘルプを表示"
  echo "Target:"
  echo "  main                   メイン実行ファイルをビルド (デフォルト)"
  echo "  test                   指定されたテストファイルをビルド (--file が必要)"
  echo "  all-tests              すべてのテストをビルド"
  echo "  examples               例をビルド"
  echo "  all                    すべてをビルド"
  quit(0)

proc parseBuildMode(mode: string): BuildMode =
  case mode.toLowerAscii
  of "debug": bmDebug
  of "release": bmRelease
  else: bmRelease

proc parseBuildTarget(target: string): BuildTarget =
  case target.toLowerAscii
  of "main": btMain
  of "test": btTest
  of "all-tests", "alltests", "tests": btAllTests
  of "examples", "example": btExamples
  of "all": btAll
  else: btMain

proc main() =
  var config = newBuildConfig()
  var targetSpecified = false
  
  # コマンドライン引数の解析
  for kind, key, val in getopt():
    case kind
    of cmdLongOption, cmdShortOption:
      case key
      of "mode", "m":
        config.mode = parseBuildMode(val)
      of "file", "f":
        config.targetFile = val
      of "verbose", "v":
        config.verbose = true
      of "help", "h":
        showHelp()
      else:
        echo "Unknown option: ", key
        showHelp()
    of cmdArgument:
      config.target = parseBuildTarget(key)
      targetSpecified = true
    of cmdEnd:
      break
  
  # ターゲットとファイルの検証
  if config.target == btTest and config.targetFile.len == 0:
    echo "Error: Test target requires --file option"
    showHelp()
  
  # ビルド操作を実行
  if config.verbose:
    echo "Build mode: ", $config.mode
    echo "Build target: ", $config.target
    if config.targetFile.len > 0:
      echo "Target file: ", config.targetFile
  
  let success = build(config)
  
  if success:
    quit(0)
  else:
    quit(1)

when isMainModule:
  main()