## test_report_wrapper.nim
## =====================
##
## テストレポート生成ツールのラッパー
##

import std/[os, osproc, strutils, logging]
import ../../utils/shell
import test_report

proc main() =
  # コマンドライン引数
  let args = commandLineParams()
  var options = ""
  
  for arg in args:
    options &= " " & shellEscape(arg)
  
  # プラットフォームに応じたスクリプト実行
  let exitCode = when defined(windows):
    execProcessEnv("scripts\\tests\\generate_test_report.bat" & options)
  else:
    execProcessEnv("sh scripts/tests/generate_test_report.sh" & options)
  
  if exitCode != 0:
    echo "Error: Test report generation failed with exit code: ", exitCode
    quit(exitCode)

when isMainModule:
  main()