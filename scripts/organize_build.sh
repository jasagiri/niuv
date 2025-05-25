#!/bin/bash
# Organize build artifacts into proper directories

set -e

# Create build directory structure
echo "Creating build directory structure..."
mkdir -p build/bin
mkdir -p build/tests
mkdir -p build/examples
mkdir -p build/tools
mkdir -p build/nimcache
mkdir -p build/coverage

# Move main executable
if [ -f "niuv" ]; then
    echo "Moving main niuv executable to build/bin/"
    mv niuv build/bin/
fi

# Move executables from src directory
echo "Moving executables from src/ to build/tools/"
for exe in src/cleanup src/testenv; do
    if [ -f "$exe" ] && [ -x "$exe" ]; then
        echo "  Moving $exe"
        mv "$exe" build/tools/
    fi
done

# Move test executables from root
echo "Moving test executables to build/tests/"
for exe in test_*; do
    if [ -f "$exe" ] && [ -x "$exe" ] && [[ ! "$exe" =~ \. ]]; then
        echo "  Moving $exe"
        mv "$exe" build/tests/
    fi
done

# Move debug executables
if [ -f "debug_sysinfo" ]; then
    echo "Moving debug_sysinfo to build/tools/"
    mv debug_sysinfo build/tools/
fi

# Move any remaining executables from tests directory
echo "Checking tests directory for executables..."
for exe in tests/*; do
    if [ -f "$exe" ] && [ -x "$exe" ] && [[ ! "$exe" =~ \. ]]; then
        basename=$(basename "$exe")
        echo "  Moving $exe to build/tests/$basename"
        mv "$exe" "build/tests/$basename"
    fi
done

# Clean up empty directories
echo "Cleaning up..."
find . -type d -empty -delete 2>/dev/null || true

echo "Build organization complete!"
echo ""
echo "Directory structure:"
echo "  build/"
echo "  ├── bin/        # Main executables"
echo "  ├── tests/      # Test executables"
echo "  ├── examples/   # Example executables"
echo "  ├── tools/      # Utility tools"
echo "  ├── nimcache/   # Nim compilation cache"
echo "  └── coverage/   # Coverage reports"