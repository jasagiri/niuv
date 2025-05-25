#!/bin/bash
# Script to compile all example files to the build/examples directory

echo "=== Compiling all example files ==="

# Create needed directories
mkdir -p build/examples build/nimcache

# Find all example files
find examples -name "*.nim" -type f | while read -r example_file; do
    # Extract example name
    example_name=$(basename "$example_file" .nim)
    echo "Compiling $example_name from $example_file"
    
    # Compile without running
    nim c --nimcache:build/nimcache --out:build/examples/$example_name "$example_file"
    
    if [ $? -eq 0 ]; then
        echo "✓ Successfully compiled $example_name"
    else
        echo "✗ Failed to compile $example_name"
    fi
done

echo "All examples compiled to build/examples/"