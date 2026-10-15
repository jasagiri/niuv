#!/bin/bash
# run_features.sh
# Feature テスト実行スクリプト

# 実行ディレクトリを確認
SCRIPT_DIR=$(dirname "$0")
cd "$SCRIPT_DIR/.."

# ビルドディレクトリを作成
mkdir -p build/bin
mkdir -p build/test_output

# テストランナーをコンパイル
nim c --nimcache:build/nimcache --out:build/bin/run_features tests/run_features.nim

# コマンドライン引数を転送してテストを実行
build/bin/run_features "$@"