@echo off
REM Run specific tests

REM Default values
set VERBOSE=
set OUTPUT_FILE=
set GENERATE_REPORT=
set FAIL_FAST=
set TEST_DIR=tests
set TEST_FILES=

REM Parse command line arguments
:arg_loop
if "%~1"=="" goto arg_done
set ARG=%~1

if "%ARG%"=="-v" (
  set VERBOSE=--verbose
) else if "%ARG%"=="--verbose" (
  set VERBOSE=--verbose
) else if "%ARG:~0,3%"=="-o=" (
  set OUTPUT_FILE=--output=%ARG:~3%
) else if "%ARG:~0,9%"=="--output=" (
  set OUTPUT_FILE=--output=%ARG:~9%
) else if "%ARG%"=="-r" (
  set GENERATE_REPORT=--report
) else if "%ARG%"=="--report" (
  set GENERATE_REPORT=--report
) else if "%ARG%"=="-f" (
  set FAIL_FAST=--fail-fast
) else if "%ARG%"=="--fail-fast" (
  set FAIL_FAST=--fail-fast
) else if "%ARG:~0,3%"=="-d=" (
  set TEST_DIR=%ARG:~3%
) else if "%ARG:~0,11%"=="--test-dir=" (
  set TEST_DIR=%ARG:~11%
) else if "%ARG%"=="-h" (
  echo Usage: run_specific_test.bat [options] ^<test_file1^> [test_file2] ...
  echo Options:
  echo   -h, --help              このヘルプを表示
  echo   -v, --verbose           詳細な出力を表示
  echo   -o=FILE, --output=FILE   テスト出力をFILEに保存
  echo   -r, --report            テストレポートを生成
  echo   -f, --fail-fast         最初のテスト失敗時に停止
  echo   -d=DIR, --test-dir=DIR   テストディレクトリ（デフォルト: tests）
  exit /b 0
) else if "%ARG%"=="--help" (
  echo Usage: run_specific_test.bat [options] ^<test_file1^> [test_file2] ...
  echo Options:
  echo   -h, --help              このヘルプを表示
  echo   -v, --verbose           詳細な出力を表示
  echo   -o=FILE, --output=FILE   テスト出力をFILEに保存
  echo   -r, --report            テストレポートを生成
  echo   -f, --fail-fast         最初のテスト失敗時に停止
  echo   -d=DIR, --test-dir=DIR   テストディレクトリ（デフォルト: tests）
  exit /b 0
) else if "%ARG:~0,1%"=="-" (
  echo Unknown option: %ARG%
  echo Run 'run_specific_test.bat --help' for usage information
  exit /b 1
) else (
  REM テストファイルの追加
  set TEST_FILES=%TEST_FILES% %1
)
shift
goto arg_loop
:arg_done

REM テストファイルが指定されているか確認
if "%TEST_FILES%"=="" (
  echo Error: No test files specified
  echo Run 'run_specific_test.bat --help' for usage information
  exit /b 1
)

REM テストを実行
echo Running tests:%TEST_FILES%
nim c -r src/tools/test/run_specific_test.nim %VERBOSE% %OUTPUT_FILE% %GENERATE_REPORT% %FAIL_FAST% --test-dir="%TEST_DIR%" %TEST_FILES%

REM テスト実行結果のステータスコードを返す
exit /b %ERRORLEVEL%