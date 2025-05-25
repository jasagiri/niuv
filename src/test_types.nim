## test_types.nim
## ==============
##
## Common types for test framework to avoid circular imports
##

type
  TestRunnerMode* = enum
    trmSingle,     # 単一のテストファイルを実行
    trmPattern,    # パターンに一致するテストファイルを実行
    trmAll         # すべてのテストを実行

  TestBackend* = enum
    tbNiuv         # 従来のniuvテストランナー
    tbTestKit      # nim-testkitバックエンド

  TestRunnerConfig* = object
    mode*: TestRunnerMode
    testFiles*: seq[string]  # 単一テストモード用
    pattern*: string         # パターンモード用
    verbose*: bool
    outputDir*: string
    generateReport*: bool
    failFast*: bool
    testDir*: string
    backend*: TestBackend    # テストバックエンドの選択

proc newTestRunnerConfig*(): TestRunnerConfig =
  ## テストランナー設定のデフォルト値を作成
  result = TestRunnerConfig(
    mode: trmAll,
    testFiles: @[],
    pattern: "test_*.nim",
    verbose: false,
    outputDir: "build/test_output",
    generateReport: true,
    failFast: false,
    testDir: "tests",
    backend: tbNiuv  # デフォルトは従来のniuvバックエンド
  )