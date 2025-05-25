@echo off
rem Script to run all Niuv tests

echo === Niuv Test Runner ===
echo Running tests...

rem Go to project root directory
cd %~dp0\..

rem ビルドディレクトリが存在することを確認
if not exist "build\bin" mkdir build\bin
if not exist "build\tests" mkdir build\tests
if not exist "build\nimcache" mkdir build\nimcache

rem クリーンアップツールをコンパイル
echo Compiling cleanup tool...
nim c -d:release -o:build\bin\cleanup.exe src/cleanup.nim

rem テスト前のクリーンアップを実行
echo Cleaning up old test environments...
build\bin\cleanup.exe --hours=1

rem Set test environment variables
set NIUV_TEST_MODE=1
set NIUV_TEST_HOME=%CD%\testenv

rem Create test environment if it doesn't exist
if not exist "%NIUV_TEST_HOME%" (
  nim c -r --nimcache:build\nimcache src/testenv.nim
)

rem Run individual tests
echo Running Config Tests...
nim c -r --nimcache:build\nimcache --out:build\tests\test_config.exe tests/test_config.nim

echo Running Deps Tests...
nim c -r --nimcache:build\nimcache --out:build\tests\test_deps.exe tests/test_deps.nim

echo Running Env Tests...
nim c -r --nimcache:build\nimcache --out:build\tests\test_env.exe tests/test_env.nim

echo Running Install Tests...
nim c -r --nimcache:build\nimcache --out:build\tests\test_install.exe tests/test_install.nim

echo Running Parallel Tests...
nim c -r --nimcache:build\nimcache --out:build\tests\test_parallel.exe tests/test_parallel.nim

rem Run all tests
echo Running All Tests...
nim c -r --nimcache:build\nimcache --out:build\tests\test_all.exe tests/test_all.nim

rem テスト後のクリーンアップを再度実行
echo Final cleanup of test environments...
build\bin\cleanup.exe --hours=1

echo === Tests Completed ===