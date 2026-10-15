#!/bin/bash
#
# Script Name: ci_script.sh
# Description: CI/CD automation script for Niuv projects that handles environment setup,
#              dependency installation, testing, building, and release artifact creation
# Usage: ./scripts/ci/ci_script.sh
# Dependencies: 
#   - nimble: Nim package manager (for installing niuv if not present)
#   - niuv: The niuv build tool (will be installed if missing)
# Parameters: None
# Output: 
#   - Initialized niuv environment with Nim 2.2.0
#   - Installed project dependencies
#   - Test execution results
#   - Compiled release binary in dist/
#   - Release artifacts in dist/ directory
# Error Conditions:
#   - Failed to install niuv
#   - Environment initialization failure
#   - Dependency installation errors
#   - Test failures (script will exit)
#   - Build compilation errors
#   - Missing required files for distribution
# Examples:
#   # Run CI pipeline
#   ./scripts/ci/ci_script.sh
#   
#   # Run in GitHub Actions
#   - name: Run CI
#     run: ./scripts/ci/ci_script.sh
#
# Example CI/CD script for Niuv integration

set -e  # Exit on error

# Install Niuv if not already installed
if \! command -v niuv &> /dev/null; then
    echo "Installing Niuv..."
    nimble install niuv
fi

# Initialize environment with specific Nim version
echo "Initializing Niuv environment..."
niuv init --nim-version=2.2.0 --verbose

# Install dependencies (including dev for testing)
echo "Installing dependencies..."
niuv install --dev --parallel=4

# Run tests
echo "Running tests..."
niuv run nim c -r tests/all_tests.nim

# Build release version
echo "Building release version..."
niuv run nim c -d:release -o:app src/main.nim

# Create release artifacts
echo "Creating release artifacts..."
mkdir -p dist
cp app dist/
cp -r public dist/
cp README.md LICENSE dist/

echo "CI/CD process completed successfully\!"
EOF < /dev/null