#!/bin/bash

# Script to run the cancellation demo

# Compile the demo
echo "Compiling cancellation demo..."
nim c -o:cancellation_demo cancellation_demo.nim

# Check if compilation was successful
if [ $? -ne 0 ]; then
  echo "Compilation failed! Exiting."
  exit 1
fi

# Default option if none provided
OPTION=${1:-"task-id"}

# Run the demo with the specified option
echo "Running cancellation demo with option: $OPTION"
./cancellation_demo $OPTION

# Clean up
echo "Cleaning up..."
rm -f cancellation_demo