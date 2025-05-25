#!/bin/bash
# Script to compile all test files to the build/tests directory

echo "=== Compiling all test files ==="

# Create needed directories
mkdir -p build/tests build/nimcache

# Find all test files
find tests -name "test_*.nim" -type f | while read -r test_file; do
    # Extract test name
    test_name=$(basename "$test_file" .nim)
    echo "Compiling $test_name from $test_file"
    
    # Compile without running
    nim c --nimcache:build/nimcache --out:build/tests/$test_name "$test_file"
    
    if [ $? -eq 0 ]; then
        echo "✓ Successfully compiled $test_name"
    else
        echo "✗ Failed to compile $test_name"
    fi
done

echo "All tests compiled to build/tests/"