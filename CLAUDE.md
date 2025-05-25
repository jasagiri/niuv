# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

### Building and Development

```bash
# Install dependencies
nimble install

# Compile Niuv
nim c -d:release -o:niuv src/niuv.nim

# Run all tests
testament pattern 'tests/*.nim' --passC:-d:niuvTest

# Run a specific test
nim c -r tests/test_config.nim
nim c -r tests/test_deps.nim
nim c -r tests/test_env.nim
nim c -r tests/test_install.nim
nim c -r tests/test_parallel.nim

# Initialize a test environment
nim c -r src/testenv.nim

# Generate documentation
nim doc --project --outdir:docs src/niuv.nim

# Generate code coverage report
nim c -r --passC:-fprofile-arcs --passC:-ftest-coverage tests/test_config.nim
nim c -r --passC:-fprofile-arcs --passC:-ftest-coverage tests/test_deps.nim
nim c -r --passC:-fprofile-arcs --passC:-ftest-coverage tests/test_env.nim
nim c -r --passC:-fprofile-arcs --passC:-ftest-coverage tests/test_install.nim
nim c -r --passC:-fprofile-arcs --passC:-ftest-coverage tests/test_parallel.nim
gcov -o:nimcache src/*.nim
lcov --capture --directory nimcache --output-file coverage.info
genhtml coverage.info --output-directory coverage
```

## Architecture

Niuv is a Nim Virtual Environment Manager (similar to Python's venv) with a focus on parallelization and configuration management.

### Core Components

1. **Main Module (`niuv.nim`)**: Entry point and command processing
   - Parses command-line arguments
   - Routes to appropriate functionality
   - Provides help text and error handling

2. **Configuration (`config.nim`)**: Manages settings and configuration
   - Loads configuration from TOML files and environment variables
   - Provides defaults when no configuration exists
   - Implements configuration file generation and updating

3. **Environment Management (`env.nim`)**: Virtual environment handling
   - Creates and manages isolated Nim environments
   - Handles activation scripts and shell integration
   - Provides environment information and system shell support

4. **Package Installation (`install.nim`)**: Package management
   - Installs packages from .nimble file
   - Implements lock file generation and synchronization
   - Manages package dependencies

5. **Parallelization (`parallel.nim`)**: Concurrent execution
   - Runs multiple tasks concurrently
   - Configurable job count based on CPU cores
   - Provides isolation between parallel tasks

6. **CLI Interface (`cli.nim`)**: User interaction
   - Provides styled output and progress information
   - Parses command-line options
   - Implements user prompts and confirmation

7. **Dependency Management (`deps.nim`)**: Package dependency handling
   - Parses and modifies .nimble files
   - Adds and removes package dependencies
   - Provides package information retrieval

8. **Utilities (`utils.nim`)**: Common functionality
   - Logging functions
   - File system operations
   - String processing and formatting

### Data Flow

1. User invokes niuv command with options
2. Command is parsed and routed in niuv.nim
3. Command-specific module handles the functionality
4. Configuration is loaded and merged from multiple sources (CLI, files, env vars)
5. Operations are performed, potentially in parallel using thread pools
6. Results are displayed to the user with proper formatting

### Testing

The codebase uses Nim's unittest module with a custom test helper framework. Each module has its own test file in the tests/ directory, with support for running individual tests or the entire test suite.

## Configuration

Configuration is loaded from multiple sources in order of precedence:
1. Command-line arguments
2. Project-specific niuv.toml file
3. User-specific ~/.niuv/config.toml
4. Environment variables
5. Default values

### Example Configuration

```toml
[tool.niuv]
nimbleLocalPath = "nimbledeps/pkgs"
nimVersion = "2.2.0"
parallelJobs = 4
verboseOutput = false
shellIntegration = true
autoLock = true
lockfile = "nimble.lock"
nimbleDir = ".niuv/deps"
```

## Error Handling

The codebase uses Result[T, E] pattern for error handling and dedicated error types for specific error categories. Error messages are displayed with colored formatting through the CLI module.