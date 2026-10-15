# Enhanced niuv with Global TestKit Coverage Support

## Overview

The enhanced niuv wrapper provides global configuration support for automatically enabling TestKit coverage by default, addressing the requirement: **niuvには現在、グローバル設定でtestkitカバレッジをデフォルト有効にする機能を追加してください**.

## Features

### ✅ Global Configuration Management
- INI-based configuration at `~/.config/niuv/config.ini`
- Automatic creation of configuration directory structure
- Support for coverage threshold, format, and output directory settings
- Performance settings (parallel execution, max jobs)
- Advanced configuration validation with error correction

### ✅ TestKit Coverage Default Enablement
- Automatically enables TestKit coverage based on global configuration
- Sets required environment variables (`TESTKIT_COVERAGE_ENABLED`, etc.)
- Visual confirmation when coverage is enabled
- Integration with Hourai project test structure

### ✅ Performance Optimizations
- Parallel test execution with configurable job limits
- Batched test running for large test suites
- Optimized test discovery for Hourai's 9-domain architecture
- Enhanced progress reporting and timing information

### ✅ Enhanced Commands
- `setup-config`: Create/update global configuration
- `validate-config`: Validate configuration with detailed error reporting
- `show-config`: Display current configuration file
- `test-all`: Run comprehensive Hourai W9P2025 test suite
- Enhanced help system with detailed examples

### ✅ Shell Integration
- Complete shell completion for Bash, Zsh, and Fish
- Auto-completion for test files, commands, and flags
- Installation script with automatic setup

### ✅ Override Mechanisms
- `--no-coverage` flag for per-command override
- `NIUV_TESTKIT_COVERAGE=false` environment variable override
- Graceful fallback when original niuv is not available
- Per-project configuration override support

## Installation

### Automated Installation (Recommended)
```bash
# Run the automated installation script
./install-niuv-enhanced.sh
```

The installation script will:
- ✅ Check dependencies (Nim compiler)
- ✅ Build the enhanced niuv binary
- ✅ Install to `~/.local/bin/niuv-enhanced`
- ✅ Install shell completions for Bash, Zsh, and Fish
- ✅ Setup global configuration with coverage enabled
- ✅ Validate the installation

### Manual Installation

#### 1. Build the Enhanced Wrapper
```bash
# Compile the enhanced niuv wrapper
nim c -o:.build/niuv-enhanced niuv_enhanced.nim
```

#### 2. Install Globally
```bash
# Option A: Copy to user bin directory (recommended)
mkdir -p ~/.local/bin
cp .build/niuv-enhanced ~/.local/bin/niuv-enhanced

# Option B: Create system-wide symlink
sudo ln -s $(pwd)/.build/niuv-enhanced /usr/local/bin/niuv-enhanced

# Option C: Add to PATH in shell config
echo 'export PATH="'$(pwd)'/.build:$PATH"' >> ~/.bashrc  # or ~/.zshrc
```

#### 3. Install Shell Completions
```bash
# Bash
mkdir -p ~/.local/share/bash-completion/completions
cp niuv-enhanced-completion.bash ~/.local/share/bash-completion/completions/niuv-enhanced

# Zsh
mkdir -p ~/.local/share/zsh/site-functions
cp niuv-enhanced-completion.zsh ~/.local/share/zsh/site-functions/_niuv-enhanced

# Fish
mkdir -p ~/.config/fish/completions
cp niuv-enhanced-completion.fish ~/.config/fish/completions/niuv-enhanced.fish
```

#### 4. Setup Global Configuration
```bash
# Create default configuration with coverage enabled
niuv-enhanced setup-config
```

## Usage

### Basic Commands
```bash
# Show enhanced help
niuv-enhanced --help

# Setup global configuration
niuv-enhanced setup-config

# Run tests with automatic TestKit coverage (reads global config)
niuv-enhanced test tests/test_*.nim

# Run specific test file
niuv-enhanced test tests/test_simple.nim
```

### Override Coverage Settings
```bash
# Disable coverage for single command
niuv-enhanced test --no-coverage tests/test_*.nim

# Disable via environment variable
NIUV_TESTKIT_COVERAGE=false niuv-enhanced test tests/test_*.nim
```

### Configuration File Format
Location: `~/.config/niuv/config.ini`

```ini
[coverage]
enabled=true
threshold=80.0
format=html
output_dir=.coverage
auto_open=false

[performance]
parallel=true
max_jobs=4
```

### Configuration Options

#### Coverage Settings
- **enabled**: Enable/disable TestKit coverage by default (true/false)
- **threshold**: Coverage percentage threshold (0.0-100.0)
- **format**: Coverage report format (html/json/lcov/text)
- **output_dir**: Directory for coverage reports
- **auto_open**: Automatically open coverage reports (true/false)

#### Performance Settings
- **parallel**: Enable parallel test execution (true/false)
- **max_jobs**: Maximum number of parallel jobs (1-16, default: 4)

## Integration with Existing Workflow

### With Existing Test Commands
The enhanced wrapper seamlessly integrates with existing nimble test workflows:

```bash
# These commands now automatically include TestKit coverage:
niuv-enhanced test                    # Run all tests
niuv-enhanced test test_config.nim    # Run specific test
niuv-enhanced test "test_*.nim"       # Pattern matching
```

### With CI/CD Systems
```yaml
# Example GitHub Actions integration
- name: Run tests with coverage
  run: |
    ./build/niuv-enhanced setup-config
    ./build/niuv-enhanced test tests/test_all.nim
```

## Verification

### Test Coverage Enablement
When TestKit coverage is enabled, you'll see:
```
✓ TestKit coverage enabled via global config
```

### Test All Functionality
Run the comprehensive integration test:
```bash
nim c -r test_niuv_integration.nim
```

Expected output:
```
=== Enhanced niuv Wrapper Integration Tests ===
[1] Testing: Help command shows enhanced features
  ✓ PASSED
[2] Testing: Config setup works  
  ✓ PASSED
[3] Testing: Coverage enabled by default with test command
  ✓ PASSED
[4] Testing: Environment variable override works
  ✓ PASSED
[5] Testing: --no-coverage flag works
  ✓ PASSED

=== Test Results ===
Passed: 5/5
🎉 All tests passed!
```

## Technical Implementation

### Architecture
- **Configuration Layer**: INI-based config management with XDG Base Directory support
- **Environment Setup**: Automatic TestKit environment variable configuration
- **Command Passthrough**: Transparent execution of original niuv commands
- **Fallback Handling**: Direct test execution when niuv is unavailable

### Environment Variables Set
When coverage is enabled, the wrapper automatically sets:
- `TESTKIT_COVERAGE_ENABLED=1`
- `TESTKIT_COVERAGE_THRESHOLD=<threshold>`
- `TESTKIT_COVERAGE_FORMAT=<format>`
- `TESTKIT_COVERAGE_OUTPUT=<output_dir>`
- `TESTKIT_COVERAGE_AUTO_OPEN=1` (if auto_open=true)

### Compatibility
- ✅ Works with existing niuv installations
- ✅ Graceful fallback when niuv not available
- ✅ Compatible with all existing nimble test workflows
- ✅ Preserves original command-line interface

## Troubleshooting

### Common Issues

**Config file not created**
```bash
# Manually create config directory
mkdir -p ~/.config/niuv
niuv-enhanced setup-config
```

**Original niuv not found**
```bash
# The wrapper includes fallback functionality
# It will execute tests directly with nim when niuv is unavailable
```

**Coverage not working**
```bash
# Check global configuration
cat ~/.config/niuv/config.ini

# Verify environment variable is not overriding
echo $NIUV_TESTKIT_COVERAGE

# Test with verbose output
nim c -r -d:debug niuv_enhanced.nim test tests/test_simple.nim
```

## Future Enhancements

- [ ] Integration with nim-testkit report generation
- [ ] Support for multiple coverage formats simultaneously  
- [ ] Coverage history tracking and trending
- [ ] IDE integration support
- [ ] Automatic coverage badge generation