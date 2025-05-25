## cucumber_adapter.nim
## =================
##
## Stub for cucumber_nim integration
## NOTE: cucumber_nim dependency has been removed
##

import std/[
  strutils,
  strformat,
  times,
  os,
  terminal,
  tables,
  sets,
  json
]

# niuv のテストフレームワークコンポーネントをインポート
import 
  reporting,
  test_enhanced

# Minimal stub types to allow compilation
type
  TestFrameworkPlugin* = ref object
    formatters*: seq[ReportFormatter]
    stepResults*: seq[TestResult]

# Stub implementation for run function
proc run*(plugin: TestFrameworkPlugin, options: seq[string] = @[]): int =
  ## Cucumber adapter stub - returns 0 (success)
  echo "Cucumber integration is currently disabled"
  return 0

# Stub for withTestFramework
proc withTestFramework*(formatters: seq[ReportFormatter] = @[]): TestFrameworkPlugin =
  ## Creates a stub test framework plugin
  result = TestFrameworkPlugin(
    formatters: formatters,
    stepResults: @[]
  )