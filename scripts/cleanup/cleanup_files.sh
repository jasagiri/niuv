#!/bin/bash
# Cleanup script for temporary files (Unix equivalent of cleanup_files.bat)
set -e

echo "=== Cleaning up unnecessary files ==="

# Duplicate parallel processing related files
rm -f ./src/parallel_clean.nim
rm -f ./src/parallel_final.nim
rm -f ./src/parallel_fixed.nim
rm -f ./src/parallel_improved_final.nim
rm -f ./src/parallel_improved_fixed.nim
rm -f ./src/parallel_improved.nim

# Backup files
rm -f ./src/parallel.nim.bak
rm -f ./src/parallel.bak

# Temporary files
rm -rf ./tests/test_parallel.dSYM

# Integrated test directories
rm -rf ./test
rm -rf ./testenv
rm -rf ./testresults
[ -d "./test_project" ] && rm -rf ./test_project

# Patch files (already committed changes)
rm -f ./parallel_fix.patch
rm -f ./parallel_full.patch
rm -f ./parallel.patch

echo "Unnecessary files have been removed"