#!/bin/bash
set -e

echo "Testing final parallel.nim version..."

# Create a backup of the original file
cp src/parallel.nim src/parallel.nim.backup

# Copy our final version for testing
cp src/parallel_final.nim src/parallel.nim

# Run the test
cd tests
nim c -r test_retry.nim

# Run another test to ensure compatibility
nim c -r test_parallel.nim

# Restore the original file
cd ..
cp src/parallel.nim.backup src/parallel.nim
rm src/parallel.nim.backup

echo "All tests completed successfully!"