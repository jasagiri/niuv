## test_framework.nim
## ================
##
## niuvテスト統合フレームワーク
## このモジュールはPowerAssertとunittestを統合し、詳細な出力とテスト結果の統計表示を提供します
##

import std/[
  strutils,
  strformat,
  terminal,
  typetraits,
  tables,
  macros,
  sets,
  sequtils
]

# unittestモジュールのインポート
import std/unittest

# スキップエラーと検証エラーの型を独自定義
type
  CustomSkipError* = ref object of CatchableError
    errMsg*: string
  
  CustomAssertionError* = ref object of CatchableError
    errMsg*: string
# エクスポートしないようにする (名前空間衝突を避けるため)

# Power Assert モジュールのインポートは不要になった
# import ../vendor/power_assert_nim/src/power_assert

# テスト統計のための変数
var
  totalTests* = 0
  passedTests* = 0
  failedTests* = 0
  skippedTests* = 0
  currentSuite* = ""

type
  TestStatistics* = object
    total*: int
    passed*: int
    failed*: int
    skipped*: int
    suites*: CountTable[string]
    failedTestNames*: HashSet[string]

var statistics* = TestStatistics()

proc resetStatistics*() =
  ## テスト統計をリセット
  statistics = TestStatistics()
  statistics.suites = initCountTable[string]()
  statistics.failedTestNames = initHashSet[string]()
  totalTests = 0
  passedTests = 0
  failedTests = 0
  skippedTests = 0
  currentSuite = ""

# unittest.suiteを使わず独自実装
template suite*(name: string, body: untyped) =
  ## テストスイートを定義するテンプレート（統計情報も収集）
  block:
    let oldSuiteName = currentSuite
    currentSuite = name
    statistics.suites.inc(name)
    
    # 直接テストスイートを実装
    block:
      echo "Suite: ", name
      body
    
    currentSuite = oldSuiteName

# unittest.testを使わず独自実装
template test*(name: string, body: untyped) =
  ## テスト統計を収集するテストテンプレート
  block:
    totalTests.inc
    statistics.total.inc
    
    echo "  Test: ", name
    
    try:
      # 直接テストを実行
      body
      
      styledEcho(fgGreen, "    [PASS]")
      passedTests.inc
      statistics.passed.inc
    except CustomSkipError:
      styledEcho(fgYellow, "    [SKIP]")
      skippedTests.inc
      statistics.skipped.inc
    except:
      let msg = getCurrentExceptionMsg()
      styledEcho(fgRed, "    [FAIL] ", msg)
      failedTests.inc
      statistics.failed.inc
      statistics.failedTestNames.incl(
        if currentSuite.len > 0: currentSuite & "." & name else: name
      )

# unittest標準のテンプレートをオーバーライド
template check*(conditions: untyped) =
  ## PowerAssertを使用する拡張checkテンプレート - シンプルな実装
  let condResult = conditions
  if not condResult:
    let conditionStr = astToStr(conditions)
    var msg = "Assertion failed: " & conditionStr
    # 例外を直接作成
    if true:
      var e = new CustomAssertionError
      e.errMsg = msg
      raise e

# 再定義したスキップ関数
template skip*() =
  ## テストをスキップするテンプレート
  if true:  # unittest の skip と同様のブロックにするため
    var e = new CustomSkipError
    e.errMsg = "Test skipped"
    raise e

template fail*(msg: string) =
  ## テストを失敗させるテンプレート
  if true:  # unittest の fail と同様のブロックにするため
    var e = new AssertionDefect
    e.msg = msg
    raise e

template expect*(exceptions: varargs[typedesc], body: untyped) =
  ## 特定の例外を期待するテンプレート
  let raisedRightException = false
  try:
    body
    # 例外が発生しなかった場合は例外を発生させる
    if true:
      var e = new CustomAssertionError
      e.errMsg = "Expected exception not raised"
      raise e
  except CustomAssertionError as e:
    if e.errMsg == "Expected exception not raised": # 自前で定義した例外の検証
      raise e
  except:
    let e = getCurrentException()
    template doesMatchErr(ex: typedesc): bool =
      e of ex
    for exception in exceptions:
      if doesMatchErr(exception):
        return
    
    let exceptionType = $e.name
    let expectedTypes = exceptions.mapIt($it).join(" or ")
    # 期待した例外と異なる例外が発生
    if true:
      var e = new CustomAssertionError
      e.errMsg = "Expected " & expectedTypes & ", got " & exceptionType
      raise e

template require*(conditions: untyped) =
  ## PowerAssertを使用するrequireテンプレート - シンプルな実装
  let condResult = conditions
  if not condResult:
    let conditionStr = astToStr(conditions)
    var msg = "Requirement failed: " & conditionStr
    # 例外を直接作成
    if true:
      var e = new CustomAssertionError
      e.errMsg = msg
      raise e

template expectError*(errorType: typedesc, code: untyped) =
  ## エラー期待用のテンプレート - シンプルな実装
  var raised = false
  try:
    discard code
  except errorType:
    raised = true
  except CatchableError:
    let failMsg = "unexpected exception: " & getCurrentExceptionMsg()
    # 例外を直接作成
    if true:
      var e = new CustomAssertionError
      e.errMsg = failMsg
      raise e
  finally:
    if not raised:
      var failMsg = "Expected to raise " & $errorType
      # 例外を直接作成
      if true:
        var e = new CustomAssertionError
        e.errMsg = failMsg
        raise e

proc printStatistics*() =
  ## テスト結果の統計を標準出力に出力
  echo "\n==============================="
  echo "テスト結果統計:"
  echo "==============================="
  
  # 成功/失敗/スキップの数を表示
  styledEcho(styleBright, "テスト数合計: ", resetStyle, $statistics.total)
  
  if statistics.passed > 0:
    styledEcho(styleBright, fgGreen, "成功: ", resetStyle, $statistics.passed)
  
  if statistics.skipped > 0:
    styledEcho(styleBright, fgYellow, "スキップ: ", resetStyle, $statistics.skipped)
  
  if statistics.failed > 0:
    styledEcho(styleBright, fgRed, "失敗: ", resetStyle, $statistics.failed)
    
    # 失敗したテスト名の一覧
    echo "\n失敗したテスト:"
    for testName in statistics.failedTestNames:
      styledEcho(fgRed, "  - ", testName)
  
  # スイート別のテスト数
  if statistics.suites.len > 0:
    echo "\nスイート別テスト数:"
    for suite, count in statistics.suites:
      styledEcho(styleBright, "  ", suite, ": ", resetStyle, $count)
  
  # 成功率
  let successRate = if statistics.total > 0: 
                      float(statistics.passed) / float(statistics.total) * 100.0
                    else:
                      0.0
  echo "\n成功率: ", formatFloat(successRate, ffDecimal, 2), "%"
  echo "==============================="

proc exitWithCode*() =
  ## テスト結果に基づいて適切な終了コードで終了
  quit(if statistics.failed > 0: 1 else: 0)

template runTestsWithStatistics*(body: untyped) =
  ## テスト統計を収集しながらテストを実行するテンプレート
  resetStatistics()
  body
  printStatistics()
  exitWithCode()

when isMainModule:
  import os
  
  echo "niuv テストフレームワーク"
  echo "Usage: このモジュールは直接実行するのではなく、テストモジュールからインポートして使用します"
  echo "Example: import ../src/test_framework"
  echo "         runTestsWithStatistics:"
  echo "           test \"Example Test\":"
  echo "             check(1 + 1 == 2)"
  
  quit(0)