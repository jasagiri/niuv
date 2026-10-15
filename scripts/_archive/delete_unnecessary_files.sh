#!/bin/bash
set -e

# Check if delete_list.txt exists
if [ ! -f "build/delete_list.txt" ]; then
  echo "Error: build/delete_list.txt not found. Run scripts/cleanup/cleanup_project.sh first."
  exit 1
fi

echo "Starting deletion of unnecessary files based on build/delete_list.txt..."

# Process the delete_list.txt file
while IFS= read -r line || [[ -n "$line" ]]; do
  # Skip comments and empty lines
  if [[ "$line" =~ ^#.*$ || -z "$line" ]]; then
    continue
  fi
  
  # Trim whitespace
  item=$(echo "$line" | xargs)
  
  if [ -e "$item" ]; then
    if [ -d "$item" ]; then
      echo "Removing directory: $item"
      rm -rf "$item"
    else
      echo "Removing file: $item"
      rm -f "$item"
    fi
  else
    echo "Warning: Item does not exist: $item"
  fi
done < build/delete_list.txt

echo "Deletion completed successfully."