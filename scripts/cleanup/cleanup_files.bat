@echo off
REM 不要なファイルの削除スクリプト

echo === 不要なファイルの削除 ===

REM 重複している並列処理関連ファイル
del /q .\src\parallel_clean.nim
del /q .\src\parallel_final.nim
del /q .\src\parallel_fixed.nim
del /q .\src\parallel_improved_final.nim
del /q .\src\parallel_improved_fixed.nim
del /q .\src\parallel_improved.nim

REM バックアップファイル
del /q .\src\parallel.nim.bak
del /q .\src\parallel.bak

REM 一時ファイル
rmdir /s /q .\tests\test_parallel.dSYM

REM 統合済みテストディレクトリ
rmdir /s /q .\test
rmdir /s /q .\testenv
rmdir /s /q .\testresults
if exist .\test_project rmdir /s /q .\test_project

REM パッチファイル（コミット済みの変更）
del /q .\parallel_fix.patch
del /q .\parallel_full.patch
del /q .\parallel.patch

echo 不要なファイルを削除しました