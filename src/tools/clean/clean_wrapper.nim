## clean_wrapper.nim
## =================
##
## クリーンアップ操作のコマンドラインラッパー
##

import os, parseopt
import "./clean"

proc showHelp() =
  echo "Clean Tool - クリーンアップ操作"
  echo "Usage: clean_wrapper [options]"
  echo "Options:"
  echo "  --mode=NORMAL|DETAILED|FULL  クリーンモードの指定"
  echo "  --dry-run                    実際には削除せず削除対象を表示"
  echo "  --verbose                    詳細な情報を表示"
  echo "  --help                       このヘルプを表示"
  quit(0)

proc parseCleanMode(mode: string): CleanMode =
  case mode.toLowerAscii
  of "normal": cmNormal
  of "detailed": cmDetailed
  of "full": cmFull
  else: cmNormal

proc main() =
  var config = newCleanConfig()
  
  # コマンドライン引数の解析
  for kind, key, val in getopt():
    case kind
    of cmdLongOption, cmdShortOption:
      case key
      of "mode", "m":
        config.mode = parseCleanMode(val)
      of "dry-run", "n":
        config.dryRun = true
      of "verbose", "v":
        config.verbose = true
      of "help", "h":
        showHelp()
      else:
        echo "Unknown option: ", key
        showHelp()
    of cmdArgument:
      case key
      of "detailed":
        config.mode = cmDetailed
      of "full":
        config.mode = cmFull
      else:
        echo "Unknown argument: ", key
        showHelp()
    of cmdEnd:
      break

  # 詳細モードの場合は自動的に詳細情報表示
  if config.mode in {cmDetailed, cmFull}:
    config.verbose = true
  
  # クリーン操作を実行
  let success = cleanBuildArtifacts(config)
  
  if success:
    quit(0)
  else:
    quit(1)

when isMainModule:
  main()