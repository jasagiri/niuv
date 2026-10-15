#!/bin/bash
# feature_report.sh
# Featureテストのレポート生成スクリプト

# 実行ディレクトリを確認
SCRIPT_DIR=$(dirname "$0")
cd "$SCRIPT_DIR/../.."

# パラメータを取得
FORMAT=${1:-html}
OUTPUT=${2:-build/test_output/feature_results.$FORMAT}

# 出力ディレクトリを作成
mkdir -p $(dirname "$OUTPUT")

# Ensure the feature runner is compiled
nim c --nimcache:build/nimcache --out:build/bin/feature_runner src/tools/test/feature_runner.nim

# レポートを生成
build/bin/feature_runner --report="$FORMAT" --output="$OUTPUT"

echo "Feature report generated: $OUTPUT"