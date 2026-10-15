#\!/bin/bash
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