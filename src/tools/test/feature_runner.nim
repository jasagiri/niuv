## feature_runner.nim
## ===============
##
## CucumberスタイルのBDDテストを実行するツール
##

import
  std/os,
  std/parseopt,
  std/strutils,
  ../../../vendor/cucumber_nim/src/cucumber_nim

# Import all step definitions
import
  ../../../tests/steps/env_steps,
  ../../../tests/steps/install_steps,
  ../../../tests/steps/clean_steps,
  ../../../tests/steps/build_steps,
  ../../../tests/steps/test_steps,
  ../../../tests/steps/parallel_steps,
  ../../../tests/steps/config_steps,
  ../../../tests/steps/scaffold_steps

proc main() =
  var options = defaultOptions()
  
  # コマンドライン引数の解析
  for kind, key, val in getopt():
    case kind
    of cmdLongOption, cmdShortOption:
      case key
      of "f", "feature-dir": options.featureDir = val
      of "s", "step-dir": options.stepDefDir = val
      of "p", "pattern": options.pattern = val
      of "t", "tag": options.tags.add(val)
      of "r", "report": options.reportFormat = val
      of "o", "output": options.reportPath = val
      of "parallel": options.parallel = true
      of "v", "verbose": options.verbose = true
      of "h", "help":
        echo "Feature Runner - CucumberスタイルのBDDテスト実行ツール"
        echo "Usage: feature_runner [options]"
        echo "Options:"
        echo "  -f, --feature-dir=DIR  featureファイルのディレクトリ (デフォルト: tests/specs)"
        echo "  -s, --step-dir=DIR     ステップ定義のディレクトリ (デフォルト: tests/steps)"
        echo "  -p, --pattern=PATTERN  実行するfeatureファイルのパターン (デフォルト: *.feature)"
        echo "  -t, --tag=TAG          実行するタグ (複数指定可能)"
        echo "  -r, --report=FORMAT    レポート形式 (console, junit, html, json)"
        echo "  -o, --output=FILE      レポート出力先ファイル"
        echo "  --parallel             並列実行する"
        echo "  -v, --verbose          詳細な出力を表示する"
        echo "  -h, --help             このヘルプを表示する"
        quit(0)
      else: discard
    else: discard
  
  echo "Running Cucumber-style BDD tests..."
  echo "Feature directory: ", options.featureDir
  echo "Pattern: ", options.pattern
  echo "Report format: ", options.reportFormat
  if options.reportPath.len > 0:
    echo "Report output: ", options.reportPath
  
  # 出力ディレクトリが存在しない場合は作成
  if options.reportPath.len > 0:
    let outDir = parentDir(options.reportPath)
    if not dirExists(outDir) and outDir.len > 0:
      createDir(outDir)
  
  # インポート可能なすべてのステップ定義モジュールを読み込む
  # 注: 自動インポートはランタイムではできないため、ここではグローバルに
  # 登録されたステップ定義を使用します。実際の実装では、これらのステップ定義は
  # メイン実行ファイルから静的にインポートする必要があります。
  
  # テストを実行
  let success = cucumber_nim.run(options)
  if not success:
    quit(1)
  
  echo "All tests completed successfully."

when isMainModule:
  main()