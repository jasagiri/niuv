@echo off
REM feature_report.bat
REM Featureテストのレポート生成スクリプト (Windows版)

REM 実行ディレクトリを確認
SET SCRIPT_DIR=%~dp0
cd %SCRIPT_DIR%\..\..

REM パラメータを取得
SET FORMAT=%1
IF "%FORMAT%"=="" SET FORMAT=html

SET OUTPUT=%2
IF "%OUTPUT%"=="" SET OUTPUT=build\test_output\feature_results.%FORMAT%

REM 出力ディレクトリを作成
FOR %%F IN ("%OUTPUT%") DO (
  IF NOT EXIST "%%~dpF" mkdir "%%~dpF"
)

REM Ensure the feature runner is compiled
nim c --nimcache:build/nimcache --out:build/bin/feature_runner src/tools/test/feature_runner.nim

REM レポートを生成
build\bin\feature_runner --report=%FORMAT% --output=%OUTPUT%

echo Feature report generated: %OUTPUT%