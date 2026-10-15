#!/bin/bash
set -e

# Create a backup directory
echo "Creating backup of the original project..."
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="../niuv_backup_$TIMESTAMP"
mkdir -p "$BACKUP_DIR"
cp -R . "$BACKUP_DIR"
echo "Backup created at $BACKUP_DIR"

# Create scripts directory if it doesn't exist
mkdir -p scripts/tests

# Move root level test scripts to scripts/tests directory if they don't already exist there
echo "Moving test scripts to scripts/tests directory..."
for script in test_*.sh; do
  if [ -f "$script" ] && [ ! -f "scripts/tests/$script" ]; then
    echo "Moving $script to scripts/tests/"
    cp "$script" "scripts/tests/"
  fi
done

# Remove temporary and generated directories
echo "Removing temporary and build directories..."
# Check if directories exist before removing
if [ -d "nimcache" ]; then
  echo "Removing nimcache directory"
  rm -rf nimcache
fi

if [ -d "active_env" ]; then
  echo "Removing active_env directory"
  rm -rf active_env
fi

# Remove duplicate files from root that exist in scripts/tests
echo "Removing duplicate script files from root..."
for script in scripts/tests/test_*.sh; do
  base_name=$(basename "$script")
  if [ -f "$base_name" ]; then
    echo "Removing duplicate $base_name from root"
    rm "$base_name"
  fi
done

# Remove .DS_Store files (macOS specific metadata)
echo "Removing .DS_Store files..."
find . -name ".DS_Store" -type f -delete

# Organize build artifacts
echo "Organizing build artifacts..."
mkdir -p build
# Move compiled binaries to build directory
for bin in src/niuv src/cleanup src/install src/testenv; do
  if [ -f "$bin" ]; then
    echo "Moving $bin to build/"
    mv "$bin" build/
  fi
done

# Create build directory if it doesn't exist
mkdir -p build

# Create a delete_list.txt file with paths that should be removed
echo "Creating build/delete_list.txt with list of files considered for removal..."
cat > build/delete_list.txt << EOL
# These files and directories were identified as potentially removable
# Comment out any line to prevent deletion

# Build caches
nimcache/

# Backup files
*.bak
*~
*.swp

# Temporary test environments
active_env/

# Compiled binaries in source directories
src/niuv
src/cleanup
src/install
src/testenv

# Root level test scripts (already moved to scripts/tests)
# test_final.sh
# test_fixed.sh
# test_improved.sh

# macOS metadata
.DS_Store
EOL

echo "Cleanup script completed successfully. Review build/delete_list.txt to finalize removal decisions."
echo "To complete removal of items in delete_list.txt, run: scripts/cleanup/delete_unnecessary_files.sh"