#!/bin/bash
# niuv + testkit Release Environment Setup Script
# This script sets up a reproducible release environment using niuv and nim-testkit

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Command history log
HISTORY_LOG="setup-history.log"
echo "=== niuv Release Setup Started at $(date) ===" >> "$HISTORY_LOG"

# Function to log and execute commands
execute() {
    echo "$ $*" >> "$HISTORY_LOG"
    "$@"
    local status=$?
    if [ $status -ne 0 ]; then
        log_error "Command failed: $*"
        exit $status
    fi
    return $status
}

# Check prerequisites
log_info "Checking prerequisites..."

# Check if Nim is installed
if ! command -v nim &> /dev/null; then
    log_error "Nim is not installed. Please install Nim first."
    echo "Visit: https://nim-lang.org/install.html" >> "$HISTORY_LOG"
    exit 1
fi

# Check if niuv is available
NIUV_PATH="./nimdeps/dev/niuv/niuv"
if [ ! -f "$NIUV_PATH" ]; then
    log_warning "niuv not found at $NIUV_PATH. Building niuv..."
    execute cd nimdeps/dev/niuv
    execute nimble build -d:release
    execute cd ../../..
fi

# Make niuv executable
execute chmod +x "$NIUV_PATH"

# Create niuv alias for convenience
log_info "Creating niuv alias..."
echo "alias niuv='$(pwd)/$NIUV_PATH'" >> ~/.bashrc
echo "alias niuv='$(pwd)/$NIUV_PATH'" >> ~/.zshrc 2>/dev/null || true

# Initialize niuv environment
log_info "Initializing niuv environment..."

# Create niuv.toml configuration
cat > niuv.toml << 'EOF'
# niuv Configuration for Hourai Project

[project]
name = "hourai"
version = "0.0.1"
description = "Distributed Computing Infrastructure"
author = "Hourai Team"
license = "Apache-2.0"

[environments]
# Development environment
[environments.dev]
nim_version = "2.0.0"
dependencies = [
    "chronos >= 3.0.0",
    "chronicles >= 0.10.0", 
    "results >= 0.3.0",
    "stew >= 0.1.0"
]

# Test environment
[environments.test]
nim_version = "2.0.0"
dependencies = [
    "chronos >= 3.0.0",
    "chronicles >= 0.10.0",
    "results >= 0.3.0",
    "stew >= 0.1.0",
    "unittest2 >= 0.0.5"
]
test_command = "nimble test"

# Release environment
[environments.release]
nim_version = "2.0.0"
dependencies = [
    "chronos >= 3.0.0",
    "chronicles >= 0.10.0",
    "results >= 0.3.0",
    "stew >= 0.1.0"
]
build_flags = "-d:release -d:danger --opt:speed"

[scripts]
# Convenience scripts
test = "nim-testkit run"
build = "nimble build"
release = "./scripts/make-release.sh"
clean = "rm -rf nimcache/ build/"

[testkit]
# nim-testkit configuration
test_dir = "tests"
coverage = true
parallel = true
verbose = false
EOF

log_success "Created niuv.toml"

# Initialize niuv environments
log_info "Creating niuv environments..."

# Create environments
execute $NIUV_PATH create dev
execute $NIUV_PATH create test  
execute $NIUV_PATH create release

# Set up nim-testkit configuration
log_info "Setting up nim-testkit..."

# Create testkit configuration
mkdir -p .testkit
cat > .testkit/config.toml << 'EOF'
# nim-testkit Configuration

[general]
test_directory = "tests"
test_pattern = "test_*.nim"
timeout = 300  # 5 minutes per test

[coverage]
enabled = true
format = ["html", "lcov", "console"]
threshold = 80  # Minimum coverage percentage
exclude = ["tests/*", "benchmarks/*", "examples/*"]

[parallel]
enabled = true
workers = 4
isolation = true  # Run each test in isolation

[reporting]
verbose = true
show_skipped = true
show_timings = true
junit_output = "test-results.xml"

[environments]
# Test environments
[[environments]]
name = "unit"
directory = "tests/unit"
tags = ["unit"]

[[environments]]
name = "integration"  
directory = "tests/integration"
tags = ["integration"]
setup = "nimble install -y"

[[environments]]
name = "benchmark"
directory = "benchmarks"
tags = ["bench", "performance"]
flags = "-d:release -d:danger"

[hooks]
# Pre/post test hooks
pre_test = [
    "echo 'Starting test run...'",
    "nim --version"
]

post_test = [
    "echo 'Test run complete'",
    "if [ -f coverage.html ]; then open coverage.html; fi"
]

[matrix]
# Test matrix for CI
nim_versions = ["2.0.0", "stable", "devel"]
os = ["linux", "macos", "windows"]
EOF

log_success "Created nim-testkit configuration"

# Create release automation script
log_info "Creating release automation script..."

cat > scripts/make-release.sh << 'EOF'
#!/bin/bash
# Automated Release Script using niuv and testkit

set -euo pipefail

# Configuration
NIUV="./nimdeps/dev/niuv/niuv"
TESTKIT="./nimdeps/dev/nim-testkit/testkit"
VERSION="${1:-}"

if [ -z "$VERSION" ]; then
    echo "Usage: $0 <version>"
    echo "Example: $0 0.0.1"
    exit 1
fi

echo "🚀 Starting release process for v$VERSION..."

# Step 1: Switch to test environment
echo "📋 Step 1: Running tests in test environment..."
$NIUV use test
$NIUV exec -- $TESTKIT run --all --coverage

# Check test results
if [ ! -f "test-results.xml" ]; then
    echo "❌ Tests failed!"
    exit 1
fi

# Check coverage
COVERAGE=$(grep -oP 'coverage="\K[0-9.]+' coverage.xml | head -1)
if (( $(echo "$COVERAGE < 80" | bc -l) )); then
    echo "❌ Coverage too low: $COVERAGE% (minimum: 80%)"
    exit 1
fi

echo "✅ All tests passed with $COVERAGE% coverage"

# Step 2: Build in release environment
echo "📦 Step 2: Building release artifacts..."
$NIUV use release
$NIUV exec -- nimble build -d:release -d:danger --opt:speed

# Step 3: Create release artifacts
echo "📁 Step 3: Creating release artifacts..."
mkdir -p "releases/v$VERSION"

# Copy binaries
cp core/tamayura/tamayura "releases/v$VERSION/"
cp core/yugen/yugen "releases/v$VERSION/"
cp core/kotozute/kotozute "releases/v$VERSION/"

# Create archives for each platform
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    tar -czf "releases/hourai-v$VERSION-linux-x64.tar.gz" -C "releases/v$VERSION" .
elif [[ "$OSTYPE" == "darwin"* ]]; then
    tar -czf "releases/hourai-v$VERSION-macos-x64.tar.gz" -C "releases/v$VERSION" .
fi

# Step 4: Generate checksums
echo "🔐 Step 4: Generating checksums..."
cd releases
shasum -a 256 *.tar.gz > "hourai-v$VERSION.sha256"
cd ..

# Step 5: Update version in project files
echo "📝 Step 5: Updating version numbers..."
sed -i.bak "s/version.*=.*\".*\"/version       = \"$VERSION\"/" core/hourai.nimble
sed -i.bak "s/version.*=.*\".*\"/version = \"$VERSION\"/" niuv.toml

# Step 6: Generate release notes
echo "📄 Step 6: Generating release notes..."
cat > "releases/RELEASE_NOTES_v$VERSION.md" << NOTES
# Release Notes - v$VERSION

Release Date: $(date +%Y-%m-%d)

## Test Results
- Total Tests: $(grep -c '<testcase' test-results.xml)
- Test Coverage: $COVERAGE%
- Build Status: ✅ Success

## Artifacts
- Linux x64: hourai-v$VERSION-linux-x64.tar.gz
- macOS x64: hourai-v$VERSION-macos-x64.tar.gz

## Checksums
\`\`\`
$(cat releases/hourai-v$VERSION.sha256)
\`\`\`

## Installation
\`\`\`bash
# Download and extract
wget https://github.com/hourai/hourai/releases/download/v$VERSION/hourai-v$VERSION-linux-x64.tar.gz
tar -xzf hourai-v$VERSION-linux-x64.tar.gz

# Verify checksum
shasum -a 256 -c hourai-v$VERSION.sha256
\`\`\`
NOTES

echo "✅ Release v$VERSION prepared successfully!"
echo ""
echo "Next steps:"
echo "  1. Review release notes: releases/RELEASE_NOTES_v$VERSION.md"
echo "  2. Commit changes: jj new -m 'release: v$VERSION'"
echo "  3. Create tag: jj tag create v$VERSION"
echo "  4. Push to GitHub: jj git push --branch release-v$VERSION"
EOF

chmod +x scripts/make-release.sh
log_success "Created release automation script"

# Create test structure
log_info "Creating test structure..."

mkdir -p tests/{unit,integration,benchmarks}

# Create sample unit test
cat > tests/unit/test_protocol.nim << 'EOF'
import unittest2
import chronos
import ../../core/protocol/nine_p

suite "9P2010 Protocol Tests":
  test "message serialization":
    let msg = TamayuraStoreRequest(
      tag: 1,
      fid: 42,
      data: @[1'u8, 2, 3, 4]
    )
    
    let serialized = msg.serialize()
    let deserialized = deserializeTamayuraStoreRequest(serialized)
    
    check deserialized.isOk
    check deserialized.get.tag == msg.tag
    check deserialized.get.fid == msg.fid
    check deserialized.get.data == msg.data

  test "error code formatting":
    let err = ErrorCode("TAMAYURA-4001")
    check err.domain == "TAMAYURA"
    check err.code == 4001
EOF

# Create sample integration test
cat > tests/integration/test_domains.nim << 'EOF'
import unittest2
import chronos
import ../../core/tamayura/api
import ../../core/yugen/actors
import ../../core/kotozute/network

suite "Domain Integration Tests":
  test "tamayura + yugen integration":
    # Test storage accessed through actor system
    let system = newActorSystem()
    let storage = system.spawn(StorageActor)
    
    let key = "test-key"
    let data = @[1'u8, 2, 3, 4, 5]
    
    waitFor storage.store(key, data)
    let retrieved = waitFor storage.retrieve(key)
    
    check retrieved.isOk
    check retrieved.get == data
EOF

log_success "Created test structure"

# Create niuv wrapper script
log_info "Creating niuv wrapper script..."

cat > scripts/niuv-run.sh << 'EOF'
#!/bin/bash
# Wrapper script for niuv commands

NIUV="./nimdeps/dev/niuv/niuv"

case "$1" in
    test)
        echo "🧪 Running tests with niuv + testkit..."
        $NIUV use test
        $NIUV exec -- ./nimdeps/dev/nim-testkit/testkit run --all --coverage
        ;;
    build)
        echo "🔨 Building with niuv..."
        $NIUV use dev
        $NIUV exec -- nimble build
        ;;
    release)
        echo "📦 Creating release with niuv..."
        $NIUV use release
        shift
        ./scripts/make-release.sh "$@"
        ;;
    clean)
        echo "🧹 Cleaning build artifacts..."
        rm -rf nimcache/ build/ coverage/ test-results.xml
        ;;
    env)
        echo "📋 Current niuv environments:"
        $NIUV list
        ;;
    *)
        echo "Usage: $0 {test|build|release|clean|env}"
        exit 1
        ;;
esac
EOF

chmod +x scripts/niuv-run.sh
log_success "Created niuv wrapper script"

# Create GitHub Actions workflow for niuv
log_info "Creating CI workflow with niuv..."

mkdir -p .github/workflows
cat > .github/workflows/niuv-ci.yml << 'EOF'
name: niuv CI/CD Pipeline

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]
  release:
    types: [ created ]

jobs:
  test:
    name: Test with niuv
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest]
        nim-version: ['2.0.0', 'stable']
    
    steps:
    - uses: actions/checkout@v3
      with:
        submodules: recursive
    
    - name: Setup Nim
      uses: jiro4989/setup-nim-action@v1
      with:
        nim-version: ${{ matrix.nim-version }}
    
    - name: Setup niuv
      run: |
        cd nimdeps/dev/niuv
        nimble build -d:release -y
        cd ../../..
        chmod +x nimdeps/dev/niuv/niuv
    
    - name: Setup testkit
      run: |
        cd nimdeps/dev/nim-testkit
        nimble build -d:release -y
        cd ../../..
    
    - name: Create environments
      run: |
        ./nimdeps/dev/niuv/niuv create test
        ./nimdeps/dev/niuv/niuv create release
    
    - name: Run tests
      run: |
        ./scripts/niuv-run.sh test
    
    - name: Upload coverage
      uses: codecov/codecov-action@v3
      with:
        file: ./coverage.lcov
        flags: unittests
        name: codecov-umbrella
    
    - name: Upload test results
      uses: actions/upload-artifact@v3
      with:
        name: test-results-${{ matrix.os }}-${{ matrix.nim-version }}
        path: |
          test-results.xml
          coverage.html

  release:
    name: Create Release with niuv
    needs: test
    runs-on: ubuntu-latest
    if: github.event_name == 'release'
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Setup environment
      run: |
        ./scripts/setup-niuv-release.sh
    
    - name: Build release
      run: |
        VERSION=${{ github.event.release.tag_name }}
        VERSION=${VERSION#v}  # Remove 'v' prefix
        ./scripts/niuv-run.sh release $VERSION
    
    - name: Upload release artifacts
      uses: softprops/action-gh-release@v1
      with:
        files: |
          releases/*.tar.gz
          releases/*.sha256
          releases/RELEASE_NOTES_*.md
EOF

log_success "Created CI workflow"

# Create command history documentation
log_info "Creating command history documentation..."

cat > RELEASE_SETUP_COMMANDS.md << 'EOF'
# Release Setup Command History

This document contains the complete command history for setting up the niuv + testkit release environment.

## Initial Setup

```bash
# 1. Run the setup script
./scripts/setup-niuv-release.sh

# 2. Source shell configuration (or restart terminal)
source ~/.bashrc  # or ~/.zshrc

# 3. Verify niuv installation
niuv --version
```

## Environment Management

```bash
# List available environments
niuv list

# Create environments
niuv create dev
niuv create test
niuv create release

# Switch between environments
niuv use dev
niuv use test
niuv use release

# Execute commands in specific environment
niuv exec --env test -- nim-testkit run
```

## Testing Workflow

```bash
# Run all tests with coverage
./scripts/niuv-run.sh test

# Run specific test suite
niuv use test
niuv exec -- nim-testkit run tests/unit/test_protocol.nim

# Run integration tests only
niuv exec -- nim-testkit run --tags integration

# Generate coverage report
niuv exec -- nim-testkit coverage --format html
```

## Build Workflow

```bash
# Development build
./scripts/niuv-run.sh build

# Release build
niuv use release
niuv exec -- nimble build -d:release -d:danger --opt:speed
```

## Release Workflow

```bash
# Create a release (runs tests, builds, packages)
./scripts/niuv-run.sh release 0.0.1

# Manual release steps
niuv use test
niuv exec -- nim-testkit run --all --coverage
niuv use release
niuv exec -- nimble build -d:release
```

## Troubleshooting

```bash
# Clean all build artifacts
./scripts/niuv-run.sh clean

# Rebuild niuv
cd nimdeps/dev/niuv
nimble build -d:release -y
cd ../../..

# Reset environments
rm -rf ~/.niuv/envs/hourai-*
niuv create dev
niuv create test
niuv create release
```

## CI/CD Integration

```bash
# Test GitHub Actions locally (requires act)
act -j test

# Trigger release
git tag v0.0.1
git push origin v0.0.1
```

## Useful Aliases

Add to your shell configuration:

```bash
# ~/.bashrc or ~/.zshrc
alias nt='./scripts/niuv-run.sh test'
alias nb='./scripts/niuv-run.sh build'
alias nr='./scripts/niuv-run.sh release'
alias nc='./scripts/niuv-run.sh clean'
```
EOF

log_success "Created command history documentation"

# Final summary
echo ""
echo "================================"
echo "✅ niuv Release Environment Setup Complete!"
echo "================================"
echo ""
echo "📁 Created files:"
echo "  - niuv.toml                    : niuv configuration"
echo "  - .testkit/config.toml         : nim-testkit configuration"
echo "  - scripts/make-release.sh      : Automated release script"
echo "  - scripts/niuv-run.sh          : niuv wrapper commands"
echo "  - .github/workflows/niuv-ci.yml: CI/CD pipeline"
echo "  - RELEASE_SETUP_COMMANDS.md    : Command reference"
echo "  - setup-history.log            : Complete command history"
echo ""
echo "🚀 Quick Start:"
echo "  1. Test: ./scripts/niuv-run.sh test"
echo "  2. Build: ./scripts/niuv-run.sh build"
echo "  3. Release: ./scripts/niuv-run.sh release 0.0.1"
echo ""
echo "📚 Documentation:"
echo "  See RELEASE_SETUP_COMMANDS.md for detailed usage"
echo ""

# Save final timestamp
echo "=== Setup completed at $(date) ===" >> "$HISTORY_LOG"