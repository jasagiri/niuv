## run_specific_test_wrapper.nim
## =========================
##
## 特定のテスト実行ツールのラッパー
##

import std/[os, osproc, strutils, logging]
import ../../utils/shell
import run_specific_test

proc main() =
  # コマンドライン引数
  let args = commandLineParams()
  var options = ""
  
  for arg in args:
    options &= " " & shellEscape(arg)
  
  # プラットフォームに応じたスクリプト実行
  let exitCode = when defined(windows):
    execProcessEnv("scripts\\tests\\run_specific_test.bat" & options)
  else:
    execProcessEnv("sh scripts/tests/run_specific_test.sh" & options)
  
  if exitCode != 0:
    echo "Error: Test run failed with exit code: ", exitCode
    quit(exitCode)

when isMainModule:
  main()