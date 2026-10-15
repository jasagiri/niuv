#!/bin/bash
# move_cucumber_scripts.sh
# Moves the cucumber feature test scripts from tests/ to scripts/features/

# 実行ディレクトリを確認
SCRIPT_DIR=$(dirname "$0")
cd "$SCRIPT_DIR/../.."

# Create build directories if they don't exist
mkdir -p build/bin
mkdir -p build/test_output

# Copy run_features.nim to its new location if it doesn't exist
if [ ! -f "src/tools/test/feature_runner.nim" ]; then
  mkdir -p src/tools/test
  cp -v tests/run_features.nim src/tools/test/feature_runner.nim
  echo "Copied run_features.nim to src/tools/test/feature_runner.nim"
fi

# Make sure the scripts directory exists
mkdir -p scripts/features

# Copy run_features.sh to its new location if needed
if [ -f "tests/run_features.sh" ]; then
  cp -v tests/run_features.sh scripts/features/
  chmod +x scripts/features/run_features.sh
  echo "Copied run_features.sh to scripts/features/"
fi

# Copy run_features.bat to its new location if needed
if [ -f "tests/run_features.bat" ]; then
  cp -v tests/run_features.bat scripts/features/
  echo "Copied run_features.bat to scripts/features/"
fi

# Print a warning
echo "
NOTICE: Feature tests scripts have been moved:
- Test script now in: src/tools/test/feature_runner.nim
- Shell scripts now in: scripts/features/

The old locations are maintained for backward compatibility,
but will be removed in a future release.
"