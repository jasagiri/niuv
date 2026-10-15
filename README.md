# Niuv - Nim Virtual Environment Manager (Unified Enhanced Version)

## Overview
Niuv is a powerful virtual environment manager for the Nim programming language, providing isolated development environments with enhanced package management, global configuration support, and comprehensive testing capabilities. This is the **unified enhanced version** that combines all features into a single, coherent implementation.

## Features
- Fast parallel package installation
- Isolated virtual environments
- Dependency management with lockfiles
- Shell integration for easy activation
- Cross-platform compatibility (Linux, macOS, Windows)
- Developer-friendly configuration via TOML and INI files
- **Global TestKit configuration system** (~/.config/niuv/config.ini)
- **Enhanced testing framework** with comprehensive test suites
- **Tool delegation system** for seamless integration with nim-testkit and nimble
- Task dependency management for ordered execution
- Real-time progress reporting for long-running tasks
- Task cancellation and graceful shutdown capabilities
- BDD-style testing with Cucumber/Gherkin

## Quick Start

### Installation

#### From Source (Recommended)

```bash
# Clone and build
git clone https://github.com/jasagiri/niuv.git
cd niuv
nimble build

# Install locally (creates symlink in ~/.local/bin)
nimble installLocal
# or use the interactive installer
./install.sh

# Verify installation (shows enhanced version)
niuv version

# Set up global configuration (recommended)
niuv setup-config
```

#### Quick Install Options

After building niuv, choose one of these methods:

1. **User-local installation** (recommended)
   ```bash
   ./install.sh  # Interactive installer
   ```

2. **Manual symlink**
   ```bash
   # User directory
   ln -s $(pwd)/niuv ~/.local/bin/niuv
   # or system-wide (requires sudo)
   sudo ln -s $(pwd)/niuv /usr/local/bin/niuv
   ```

3. **Add to PATH**
   ```bash
   # Add to your shell config (.bashrc, .zshrc, etc.)
   export PATH="/path/to/niuv:$PATH"
   ```

#### From Nimble (Coming Soon)

```bash
nimble install niuv
```

### Creating a New Environment
```bash
# Create a new virtual environment in the current directory
niuv init

# Create with a specific Nim version
niuv init --nim-version=2.0.0
```

### Package Management
```bash
# Install all packages listed in the .nimble file
niuv install

# Install packages in parallel (4 jobs)
niuv install --parallel=4

# Add a package to dependencies
niuv add packagename

# Add a package with version constraint
niuv add packagename >=1.0.0

# Add a development dependency
niuv add packagename --dev

# Remove a package
niuv remove packagename
```

### Environment Usage
```bash
# Activate the environment
niuv activate

# Run a command within the environment
niuv run nim c myfile.nim

# Start a new shell with the environment activated
niuv shell

# Display environment information
niuv info

# Set up shell integration for easier activation
niuv setup
```

### Advanced Features
```bash
# Synchronize packages with lockfile
niuv sync

# Install packages including development dependencies
niuv install --dev

# Enable verbose output
niuv install --verbose

# Run commands in parallel with robust error handling
niuv run --parallel=4 "command1" "command2" "command3"

# Run tasks with priorities
niuv run --priority=high "critical-task" --priority=low "background-task"

# Run tasks with dependencies (ensure execution order)
niuv run --id=prep "preparation-task" --id=main "main-task" --depends-on=prep

# Create complex dependency graphs for build processes
niuv run --id=lib "nim c lib.nim" --id=main "nim c main.nim" --depends-on=lib --id=test "nim c -r test.nim" --depends-on=main

# Track progress of long-running tasks
niuv run --id=build --expected-duration=60 --progress-interval=1 "nim c -d:release large_project.nim"

# Track progress across multiple dependent tasks
niuv run --parallel=4 --id=task1 --expected-duration=10 --progress-interval=0.5 "command1" --id=task2 --depends-on=task1 --expected-duration=20 --progress-interval=1 "command2"

# Enable detailed logging for parallel execution
NIUV_VERBOSE=1 niuv run --parallel=4 "command1" "command2" "command3"

# Cancel a specific task by ID
niuv run --cancel=task-id "command1" "command2"

# Gracefully shut down all running tasks
niuv run --cancel-all "command1" "command2"
```

### Testing

Niuv provides an integrated testing framework with enhanced features:

```bash
# Run comprehensive test suite (recommended)
niuv test-all  # Runs Hourai W9P2025 test suite

# Note: 'niuv test' has a known infinite loop issue - use test-all instead

# Analyze test structure using MECE principles
niuv test analyze

# Generate test files
niuv test generate unit api          # Generate unit test
niuv test generate integration db    # Generate integration test
niuv test generate system e2e        # Generate system test

# Configure global test coverage
niuv setup-config    # Creates ~/.config/niuv/config.ini
niuv show-config     # Display current configuration
niuv validate-config # Validate configuration
```

Test configuration can be minimal in `niuv.toml`:
```toml
[tool.niuv.testing]
backend = "niuv"  # or "testkit" for nim-testkit integration
# All other settings use sensible defaults
```

### Delegation System

Niuv features a powerful delegation system that allows it to work as a coordinator for other tools, including nimble and nim-testkit:

```bash
# Delegate commands to appropriate tools
niuv build              # Delegates to nimble or custom build
niuv test               # Delegates to nim-testkit when configured
niuv release            # Delegates to release management tools

# Configure delegation in niuv.toml
[tool.niuv.delegation]
build = "nimble"        # or "custom", "testkit"
test = "testkit"        # or "builtin", "nimble"
doc = "nimble"          # or "testkit", "custom"
release = "testkit"     # or "nimble", "custom"

# Advanced delegation with conditions
[tool.niuv.delegation.advanced]
build = { tool = "testkit", when = "exists:nimtestkit.toml" }
test = { tool = "testkit", priority = 1 }
```

The delegation system provides:
- **Smart Tool Selection**: Automatically chooses the best tool for each task
- **Fallback Support**: Falls back to alternative tools when primary is unavailable
- **Conditional Delegation**: Delegates based on project configuration
- **Unified Interface**: Single command interface for multiple tools
- **Performance Optimization**: Uses nim-testkit's caching when available

## Configuration

### Project Configuration (niuv.toml)
Niuv uses a TOML configuration file for project-specific settings:

```toml
[tool.niuv]
nim_version = "2.0.0"
nimble_dir = ".niuv/deps"
lockfile = "nimble.lock"
auto_lock = true
parallel_jobs = 4
verbose_output = false
shell_integration = true

[tool.niuv.testing]
backend = "niuv"  # or "testkit" for nim-testkit integration

[tool.niuv.delegation]
build = "nimble"  # or "custom", "testkit"
test = "testkit"  # or "builtin", "nimble"
```

### Global Configuration (~/.config/niuv/config.ini)
The unified version includes a global configuration system:

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

Manage global configuration with:
```bash
niuv setup-config    # Create default configuration
niuv show-config     # Display current settings
niuv validate-config # Validate configuration
```

## Project Structure

The project has been reorganized for better maintainability with a more standardized build structure. All build artifacts now go to the `build/` directory, and utility functions have been migrated from nim_boilerplate for improved code reuse.

```
├── build/                # Build artifacts (created during build)
│   ├── bin/              # Compiled binaries
│   ├── tests/            # Compiled test binaries
│   ├── nimcache/         # Nim compiler cache files
│   ├── docs/             # Generated documentation
│   ├── reports/          # Generated test reports
│   └── test_output/      # Test execution output
├── nimbledeps/           # Nim package dependencies
│   ├── pkgs/             # Installed Nim packages
│   └── pkgcache/         # Package cache
├── docs/                 # Documentation
│   ├── api_reference.md  # API reference documentation
│   ├── architecture.md   # Architecture overview
│   ├── getting_started.md# Getting started guide
│   ├── project_structure.md # Project organization details
│   └── vendor_packages.md# Documentation for vendored packages
├── examples/             # Example configurations and projects
│   ├── niuv.toml         # Example configuration file
│   ├── ci_script.sh      # Example CI script for Unix
│   ├── ci_script.bat     # Example CI script for Windows
│   ├── parallel_tasks.nim# Example of parallel task execution
│   ├── priority_tasks.nim# Example of task prioritization
│   ├── dependency_tasks.nim # Example of task dependencies
│   ├── circular_dependencies.nim # Example of dependency error handling
│   ├── progress_reporting.nim # Example of progress reporting
│   └── cancellation_demo.nim # Example of task cancellation features
├── scripts/              # Utility scripts
│   ├── ci/               # CI/CD scripts
│   ├── cleanup/          # Cleanup and organization scripts
│   ├── demo/             # Demo scripts
│   ├── features/         # BDD feature test scripts
│   │   ├── run_features.sh   # Run feature tests on Unix
│   │   └── run_features.bat  # Run feature tests on Windows
│   ├── reports/          # Test report scripts
│   │   ├── feature_report.sh # Generate feature test reports on Unix
│   │   └── feature_report.bat # Generate feature test reports on Windows
│   ├── tests/            # Test scripts
│   ├── compile_examples.sh   # Compile examples on Unix
│   ├── compile_examples.bat  # Compile examples on Windows
│   ├── compile_tests.sh      # Compile tests on Unix
│   ├── compile_tests.bat     # Compile tests on Windows
│   ├── run_tests.sh          # Run tests on Unix
│   └── run_tests.bat         # Run tests on Windows
├── src/                  # Source code
│   ├── cli.nim           # Command-line interface
│   ├── config.nim        # Configuration management
│   ├── deps.nim          # Dependency management
│   ├── env.nim           # Environment management
│   ├── install.nim       # Package installation
│   ├── macros.nim        # Nim macros
│   ├── niuv.nim          # Main entry point
│   ├── niuv_testing.nim  # Testing framework integration
│   ├── parallel.nim      # Parallel execution
│   ├── regex_patterns.nim# Regex patterns for parsing
│   ├── testenv.nim       # Test environment setup
│   ├── testrunner.nim    # Test runner framework
│   ├── tools/            # Tool implementations
│   │   ├── build/        # Build tools
│   │   ├── clean/        # Cleanup tools
│   │   │   ├── clean.nim # Main cleaning implementation
│   │   │   └── clean_wrapper.nim # CLI wrapper
│   │   ├── report/       # Reporting tools
│   │   │   ├── test_report.nim # Test report generator
│   │   │   └── test_report_wrapper.nim # CLI wrapper
│   │   └── test/         # Testing tools
│   │       ├── feature_runner.nim # BDD feature runner
│   │       ├── run_specific_test.nim # Specific test runner
│   │       ├── run_specific_test_wrapper.nim # CLI wrapper
│   │       ├── test.nim # Test framework
│   │       └── test_wrapper.nim # CLI wrapper
│   ├── utils/            # Utility modules
│   │   ├── fs.nim        # File system utilities
│   │   └── shell.nim     # Shell command utilities
│   ├── utils.nim         # General utilities
│   └── venv.nim          # Virtual environment
├── templates/            # Code templates
│   └── scaffold.nim      # Project scaffolding
├── tests/                # Tests
│   ├── fixtures/         # Test fixtures
│   ├── specs/            # Gherkin feature specifications
│   ├── steps/            # Step definitions for BDD tests
│   ├── test_all.nim      # Run all unit tests
│   ├── test_config.nim   # Configuration tests
│   ├── test_deps.nim     # Dependency tests
│   ├── test_env.nim      # Environment tests
│   ├── test_install.nim  # Installation tests
│   ├── test_niuv_testing.nim # Niuv testing framework tests
│   ├── test_parallel.nim # Parallel execution tests
│   ├── test_power_assert.nim # Power assert tests
│   ├── test_progress.nim # Progress reporting tests
│   ├── test_report_generator.nim # Report generator tests
│   ├── test_retry.nim    # Retry behavior tests
│   ├── test_run_specific_test.nim # Specific test runner tests
│   ├── test_shell_utils.nim # Shell utilities tests
│   ├── test_venv.nim     # Virtual environment tests
│   ├── run_features.nim  # Legacy feature test runner (redirects to scripts)
│   └── testutils.nim     # Test utilities
├── vendor/               # Vendored dependencies
│   ├── power_assert_nim/  # Power Assert for Nim testing
│   └── cucumber_nim/      # Cucumber for Nim BDD testing
├── CLAUDE.md             # Guide for Claude Code
├── CONTRIBUTING.md       # Contributing guidelines
├── CHANGELOG.md          # Version history
├── LICENSE               # MIT License
├── nimbletools.nimble    # Additional nimble tasks
├── README.md             # This file
└── niuv.nimble           # Nimble package file
```

## Vendor Packages

Niuv includes two specialized vendor packages that are designed to improve the testing experience:

### power_assert_nim

An enhanced assertion library that provides detailed and visual error messages when assertions fail. Unlike standard assertions that only show that a condition failed, Power Assert shows the values of all expressions involved, making it much easier to diagnose test failures.

```nim
import power_assert_nim

test "calculations":
  let x = 10
  let y = 5
  let z = 7
  
  # When this fails, it shows the value of each variable and subexpression
  powerAssert (x + y) * 2 == z + 30
```

When the above assertion fails, instead of a simple "assertion failed" message, you'll get detailed output showing the value of each variable and subexpression:

```
Assertion failed:
  (x + y) * 2 == z + 30
  |   |  | |  | | |
  |   |  | |  | | 37
  |   |  | |  | 7
  |   |  | |  false
  |   |  | 30
  |   |  15
  |   5
  10
```

### cucumber_nim

A Behavior-Driven Development (BDD) framework that allows writing tests in natural language using Gherkin syntax. It follows the Cucumber pattern, where features are described in plain text and implemented with step definitions in Nim code.

```gherkin
# In a .feature file
Feature: Virtual Environment
  Scenario: Creating a new environment
    Given I have Niuv installed
    When I run "niuv init" in a new project directory
    Then a new virtual environment should be created
    And the environment should have the correct structure
```

```nim
# In a step definition file
import cucumber_nim

Given "I have Niuv installed":
  check niuvIsInstalled()

When re"I run \"(.+)\" in a new project directory":
  let command = matches[0]
  createTestDirectory()
  runCommand(command)

Then "a new virtual environment should be created":
  check directoryExists(".niuv")

And "the environment should have the correct structure":
  check fileExists(".niuv/bin/nim")
  check directoryExists(".niuv/nimbledeps")
  # ...
```

Both packages are fully integrated with Niuv's build system and can be used in your tests directly. For more information, see the [Vendor Packages Documentation](/docs/vendor_packages.md).

## Development

### Project Organization

```bash
# Move scripts to standard locations (if updating from old version)
nimble moveScripts
```

### Building

```bash
# Debug build
nimble build

# Release build
nimble buildMain

# Build everything (tests, examples, main executable)
nimble buildAll
```

### Running Tests

```bash
# Run all unit tests
nimble test

# Run a specific unit test
nimble testOne tests/test_env.nim

# Run a specific test with detailed output
nimble runTest test_config.nim

# Run all BDD feature tests
nimble features

# Run a specific feature test
nimble featureOne env.feature

# Generate HTML report for feature tests
nimble featureReport html build/test_output/features.html

# Generate test report from test output
nimble testReport build/test_output/latest.log

# Run tests and generate reports
nimble testWithReport

# Run full test suite with coverage
nimble fullTest

# Generate coverage report (see limitations below)
nimble coverage

# Build all tests without running
nimble buildAllTests

# Build a specific test without running
nimble buildTest tests/test_env.nim

# Build all examples
nimble buildExamples
```

### Cleaning

```bash
# Using niuv commands (recommended)
niuv clean     # Clean build artifacts (preserves nimbledeps)
niuv cleanall  # Clean ALL artifacts including nimbledeps (full clean)

# Using nimble (alternative)
nimble clean    # Clean build artifacts (preserves nimbledeps)
nimble cleanall # Clean ALL artifacts including nimbledeps (full clean)

# Remove unnecessary files
nimble cleanup

# Use the provided cleanup scripts
scripts/cleanup/cleanup_project.sh         # Organize project structure and create build/delete_list.txt
scripts/cleanup/delete_unnecessary_files.sh # Remove files listed in build/delete_list.txt
scripts/cleanup/cleanup_files.sh          # Clean up temporary and backup files (Unix)
scripts/cleanup/cleanup_files.bat         # Clean up temporary and backup files (Windows)
```

### Migrated Tools

The project now includes utility tools migrated from nim_boilerplate:

1. **File System Utilities** (`src/utils/fs.nim`)
   - Directory and file management
   - File pattern matching
   - Safe copying and removal operations

2. **Shell Utilities** (`src/utils/shell.nim`)
   - Cross-platform command execution
   - Environment variable handling
   - Platform detection
   - Path utilities

3. **Test Report Generation** (`src/tools/report/test_report.nim`)
   - Parse test output
   - Generate HTML and JSON reports
   - Test execution summaries

4. **Specific Test Runner** (`src/tools/test/run_specific_test.nim`)
   - Run individual test files
   - Configurable output and reporting
   - Integration with test reporting

5. **Integrated Testing Module** (`src/niuv_testing.nim`)
   - Combined test execution and reporting
   - Support for different test modes (single, pattern, all)
   - Flexible configuration

### BDD Testing

Niuv uses Behavior-Driven Development (BDD) with Gherkin syntax for feature testing. The tests are structured as follows:

```
tests/
  ├── specs/               # Gherkin feature specifications
  │   ├── activate.feature # Environment activation features
  │   ├── build.feature    # Build features
  │   ├── clean.feature    # Cleanup features
  │   ├── config.feature   # Configuration features
  │   ├── env.feature      # Environment features
  │   ├── install.feature  # Package installation features
  │   ├── parallel.feature # Parallel execution features
  │   ├── scaffold.feature # Project scaffolding features
  │   └── test.feature     # Test execution features
  └── steps/                # Step implementations
      ├── env_steps.nim     # Environment step implementations
      ├── build_steps.nim   # Build step implementations
      ├── clean_steps.nim   # Cleanup step implementations
      ├── config_steps.nim  # Configuration step implementations
      ├── install_steps.nim # Installation step implementations
      ├── parallel_steps.nim# Parallel execution step implementations
      ├── scaffold_steps.nim# Scaffolding step implementations
      └── test_steps.nim    # Test execution step implementations
```

You can run the BDD tests with:

```bash
# Run all feature tests
nimble features

# Run a specific feature
nimble featureOne install.feature

# Generate a test report
nimble featureReport html build/test_output/features.html
```

### Testing Environment

For testing, you can use the `NIUV_TEST_MODE` environment variable:

```bash
NIUV_TEST_MODE=1 ./niuv init
```

### Additional Nimble Tasks

The project includes extra Nimble tasks in `nimbletools.nimble` to leverage the migrated tools:

```bash
# Run specific test with detailed output
nimble runTest test_config.nim

# Generate test reports from test output
nimble testReport build/test_output/latest.log

# Run tests and generate reports in one step
nimble testWithReport

# Run full test suite with reports and coverage
nimble fullTest
```

### Test Coverage

**Note**: Due to technical limitations with Nim's compilation model, traditional code coverage tools (gcov/lcov) cannot generate accurate coverage reports for Nim source code. The `nimble coverage` task will execute all tests successfully but the HTML report will be empty. For more details, see [Coverage Limitations Documentation](/docs/coverage_limitations.md).

We recommend focusing on comprehensive test suites and manual verification rather than relying on automated coverage metrics. All public APIs should have corresponding tests in the `tests/` directory.

## Documentation
For detailed documentation, see the following resources:
- [Getting Started Guide](/docs/getting_started.md)
- [API Reference](/docs/api_reference.md)
- [Architecture Overview](/docs/architecture.md)
- [Project Structure](/docs/project_structure.md)
- [Coverage Limitations](/docs/coverage_limitations.md)

## Contributing

Contributions are welcome! See [CONTRIBUTING.md](/CONTRIBUTING.md) for guidelines.

1. Fork the repository
2. Create a feature branch: `git checkout -b feature-name`
3. Commit your changes: `git commit -am 'Add new feature'`
4. Push to the branch: `git push origin feature-name`
5. Submit a pull request

## Enhanced Features

The unified version includes several enhanced capabilities:

### Global TestKit Coverage
- Automatic TestKit integration for all Nim projects
- Global configuration at `~/.config/niuv/config.ini`
- Environment variable overrides: `NIUV_TESTKIT_COVERAGE=false`

### Enhanced Commands
```bash
# Version with features list
niuv version

# Comprehensive test suite
niuv test-all

# Configuration management
niuv setup-config
niuv show-config
niuv validate-config

# Update checking
niuv check-updates

# Project scaffolding
niuv generate [project-name]
```

### Tool Delegation
Niuv can delegate to appropriate tools based on project configuration:
- **nim-testkit**: For advanced testing features
- **nimble**: For package management
- **Custom tools**: Via configuration

## Known Issues

1. **`niuv test` infinite loop**: The standard test command has a known infinite loop issue. Use `niuv test-all` for running tests.

2. **Test suite limitations**: Some tests are excluded from the main test runner due to compilation timeout issues with the parallel module. These tests run fine individually but cause hanging when compiled together.

3. **Coverage reporting**: Due to Nim's compilation model, traditional code coverage tools cannot generate accurate coverage reports. The coverage report will execute tests but the HTML output will be empty.

## Migration from Standard Niuv

If you're upgrading from the standard niuv to the unified enhanced version:

1. **Install the unified version**:
   ```bash
   nim c -d:release -o:~/.local/bin/niuv src/niuv.nim
   ```

2. **Set up global configuration**:
   ```bash
   niuv setup-config
   ```

3. **Use enhanced commands**:
   - Replace `niuv test` with `niuv test-all`
   - Use `niuv show-config` to verify settings

## License
MIT License