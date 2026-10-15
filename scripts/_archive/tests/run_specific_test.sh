#!/bin/sh
# Run specific tests

# Default values
VERBOSE=""
OUTPUT_FILE=""
GENERATE_REPORT=""
FAIL_FAST=""
TEST_DIR="tests"

# Handle options
while [ $# -gt 0 ]; do
  case "$1" in
    -v|--verbose) 
      VERBOSE="--verbose"
      ;;
    -o=*|--output=*) 
      OUTPUT_FILE="--output=${1#*=}"
      ;;
    -r|--report) 
      GENERATE_REPORT="--report"
      ;;
    -f|--fail-fast) 
      FAIL_FAST="--fail-fast"
      ;;
    -d=*|--test-dir=*) 
      TEST_DIR="${1#*=}"
      ;;
    -h|--help)
      echo "Usage: run_specific_test.sh [options] <test_file1> [test_file2] ..."
      echo "Options:"
      echo "  -h, --help              このヘルプを表示"
      echo "  -v, --verbose           詳細な出力を表示"
      echo "  -o=FILE, --output=FILE   テスト出力をFILEに保存"
      echo "  -r, --report            テストレポートを生成"
      echo "  -f, --fail-fast         最初のテスト失敗時に停止"
      echo "  -d=DIR, --test-dir=DIR   テストディレクトリ（デフォルト: tests）"
      exit 0
      ;;
    -*)
      echo "Unknown option: $1"
      echo "Run 'run_specific_test.sh --help' for usage information"
      exit 1
      ;;
    *)
      # 引数を収集して後で処理する
      TEST_FILES="$TEST_FILES $1"
      ;;
  esac
  shift
done

# テストファイルが指定されているか確認
if [ -z "$TEST_FILES" ]; then
  echo "Error: No test files specified"
  echo "Run 'run_specific_test.sh --help' for usage information"
  exit 1
fi

# テストを実行
echo "Running tests: $TEST_FILES"
nim c -r src/tools/test/run_specific_test.nim $VERBOSE $OUTPUT_FILE $GENERATE_REPORT $FAIL_FAST --test-dir="$TEST_DIR" $TEST_FILES

# テスト実行結果のステータスコードを返す
exit $?