#!/bin/bash
set -e

echo "Testing fixed parallel.nim file..."

# Create a backup of the original file
cp src/parallel.nim src/parallel.nim.backup

# Copy our fixed version for testing
cp src/parallel_fixed.nim src/parallel.nim

# Run the test
cd tests
nim c -r test_retry.nim

# Restore the original file
cd ..
cp src/parallel.nim.backup src/parallel.nim
rm src/parallel.nim.backup

echo "Test completed successfully!"