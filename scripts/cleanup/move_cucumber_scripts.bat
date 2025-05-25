@echo off
REM move_cucumber_scripts.bat
REM Moves the cucumber feature test scripts from tests/ to scripts/features/

REM 実行ディレクトリを確認
SET SCRIPT_DIR=%~dp0
cd %SCRIPT_DIR%\..\..\

REM Create build directories if they don't exist
if not exist build\bin mkdir build\bin
if not exist build\test_output mkdir build\test_output

REM Copy run_features.nim to its new location if it doesn't exist
if not exist src\tools\test\feature_runner.nim (
  if not exist src\tools\test mkdir src\tools\test
  copy /Y tests\run_features.nim src\tools\test\feature_runner.nim
  echo Copied run_features.nim to src\tools\test\feature_runner.nim
)

REM Make sure the scripts directory exists
if not exist scripts\features mkdir scripts\features

REM Copy run_features.sh to its new location if needed
if exist tests\run_features.sh (
  copy /Y tests\run_features.sh scripts\features\
  echo Copied run_features.sh to scripts\features\
)

REM Copy run_features.bat to its new location if needed
if exist tests\run_features.bat (
  copy /Y tests\run_features.bat scripts\features\
  echo Copied run_features.bat to scripts\features\
)

REM Print a warning
echo.
echo NOTICE: Feature tests scripts have been moved:
echo - Test script now in: src\tools\test\feature_runner.nim
echo - Shell scripts now in: scripts\features\
echo.
echo The old locations are maintained for backward compatibility,
echo but will be removed in a future release.
echo.