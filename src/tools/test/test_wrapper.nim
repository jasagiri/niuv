## test_wrapper.nim
## ===============
##
## テスト操作のコマンドラインラッパー
##

import os, parseopt, strutils
import "./test"

proc showHelp() =
  echo "Test Tool - テスト操作"
  echo "Usage: test_wrapper [options] [test_file]"
  echo "Options:"
  echo "  --mode=NORMAL|VERBOSE|QUIET  テストモードの指定"
  echo "  --pattern=PATTERN            テストファイルのパターン (デフォルト: test_*.nim)"
  echo "  --output=DIR                 テスト結果出力ディレクトリ"
  echo "  --help                       このヘルプを表示"
  echo "Arguments:"
  echo "  test_file                    実行する単一のテストファイル (オプション)"
  quit(0)

proc parseTestMode(mode: string): TestMode =
  case mode.toLowerAscii
  of "normal": tmNormal
  of "verbose": tmVerbose
  of "quiet": tmQuiet
  else: tmNormal

proc main() =
  var config = newTestConfig()
  
  # コマンドライン引数の解析
  for kind, key, val in getopt():
    case kind
    of cmdLongOption, cmdShortOption:
      case key
      of "mode", "m":
        config.mode = parseTestMode(val)
      of "pattern", "p":
        config.pattern = val
      of "output", "o":
        config.outputDir = val
      of "verbose", "v":
        config.mode = tmVerbose
      of "quiet", "q":
        config.mode = tmQuiet
      of "help", "h":
        showHelp()
      else:
        echo "Unknown option: ", key
        showHelp()
    of cmdArgument:
      config.singleTest = key
    of cmdEnd:
      break
  
  # 設定の表示
  if config.mode == tmVerbose:
    echo "Test mode: ", $config.mode
    if config.singleTest.len > 0:
      echo "Test file: ", config.singleTest
    else:
      echo "Test pattern: ", config.pattern
    echo "Output directory: ", config.outputDir
  
  # テスト操作を実行
  let success = runTests(config)
  
  if success:
    quit(0)
  else:
    quit(1)

when isMainModule:
  main()