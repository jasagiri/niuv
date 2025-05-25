@echo off
REM run_features.bat
REM Feature テスト実行スクリプト

REM 実行ディレクトリを確認
cd /d "%~dp0\.."

REM ビルドディレクトリを作成
if not exist build\bin mkdir build\bin
if not exist build\test_output mkdir build\test_output

REM テストランナーをコンパイル
nim c --nimcache:build/nimcache --out:build/bin/run_features tests/run_features.nim

REM コマンドライン引数を転送してテストを実行
build\bin\run_features %*