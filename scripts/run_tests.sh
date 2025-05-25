#!/bin/bash
# Script to run all Niuv tests

echo "=== Niuv Test Runner ==="
echo "Running tests..."

# Ensure we're in the project root
cd "$(dirname "$0")/.."

# ビルドディレクトリが存在することを確認
mkdir -p build/bin build/tests build/nimcache

# クリーンアップツールをコンパイル
echo "Compiling cleanup tool..."
nim c -d:release -o:build/bin/cleanup src/cleanup.nim

# テスト前のクリーンアップを実行
echo "Cleaning up old test environments..."
./build/bin/cleanup --hours=1

# Set test environment variables
export NIUV_TEST_MODE=1
export NIUV_TEST_HOME="$(pwd)/testenv"

# Create test environment if it doesn't exist
if [ ! -d "$NIUV_TEST_HOME" ]; then
  nim c -r --nimcache:build/nimcache src/testenv.nim
fi

# Build test runner
echo "Building test runner..."
nim c --nimcache:build/nimcache --out:build/bin/testrunner src/testrunner.nim

# Run all tests using the test runner
echo "Running tests with test runner..."
./build/bin/testrunner --verbose --output:build/tests

# テスト後のクリーンアップを再度実行
echo "Final cleanup of test environments..."
./build/bin/cleanup --hours=1

echo "=== Tests Completed ==="