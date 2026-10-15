# Niuv API Reference

This document provides a detailed reference for the Niuv API. It covers the commands and options available through the command-line interface.

## Command-Line Interface

### Global Options

These options can be used with any command:

| Option | Description | Example |
|--------|-------------|---------|
| `--verbose` | Display verbose output | `niuv install --verbose` |
| `--force` | Force operations (ignore warnings) | `niuv install --force` |
| `--help` | Display help information | `niuv --help` |

### Commands

#### `init`

Initializes a new virtual environment in the current directory.

```bash
niuv init [options]
```

Options:
- `--nim-version=<version>` - Specify the Nim version to use
- `--nimble-dir=<dir>` - Specify the directory for Nimble packages (default: `.niuv/deps`)

Examples:
```bash
# Basic initialization
niuv init

# Initialize with specific Nim version
niuv init --nim-version=2.0.0

# Initialize with custom Nimble directory
niuv init --nimble-dir=custom_deps
```

#### `install`

Installs packages from the `.nimble` file.

```bash
niuv install [options]
```

Options:
- `--dev` - Include development dependencies
- `--parallel=<n>` - Number of parallel jobs (default: number of CPU cores)
- `--no-lock` - Disable automatic lockfile generation
- `--lockfile=<file>` - Specify alternative lockfile path
- `--cache-dir=<dir>` - Custom cache directory

Examples:
```bash
# Install all packages
niuv install

# Install including development dependencies
niuv install --dev

# Install with 4 parallel jobs
niuv install --parallel=4

# Install without generating a lockfile
niuv install --no-lock
```

#### `add`

Adds a package to the dependencies and installs it.

```bash
niuv add <package> [version] [options]
```

Options:
- `--dev` - Add as a development dependency

Examples:
```bash
# Add a package
niuv add packagename

# Add a package with version constraint
niuv add packagename >=1.0.0

# Add a package as a development dependency
niuv add packagename --dev
```

#### `remove`

Removes a package from the dependencies.

```bash
niuv remove <package>
```

Examples:
```bash
# Remove a package
niuv remove packagename
```

#### `sync`

Synchronizes installed packages with dependencies.

```bash
niuv sync [options]
```

Options:
- `--lockfile=<file>` - Specify alternative lockfile path
- `--force` - Force operations (ignore version mismatches)

Examples:
```bash
# Synchronize packages with lockfile
niuv sync

# Synchronize with custom lockfile
niuv sync --lockfile=custom.lock

# Force synchronization
niuv sync --force
```

#### `activate`

Activates the virtual environment.

```bash
niuv activate
```

Note: This requires shell integration to be set up. Otherwise, you need to use `source ./activate` (Unix) or `.\activate.bat` (Windows).

#### `shell`

Starts a new shell with the virtual environment activated.

```bash
niuv shell
```

#### `run`

Runs a command in the virtual environment.

```bash
niuv run [options] <command> [<command2> <command3> ...]
```

Options:
- `--parallel=<n>` - Run commands in parallel with n jobs
- `--working-dir=<dir>` - Set the working directory for commands
- `--env=<n>=<value>` - Set environment variables (can be used multiple times)
- `--id=<taskID>` - Assign a unique ID to the task (required for dependencies)
- `--priority=<priority>` - Set task priority (high|normal|low)
- `--depends-on=<taskID>` - Specify a task dependency (can be used multiple times)
- `--expected-duration=<seconds>` - Expected duration of task in seconds (for progress reporting)
- `--progress-interval=<seconds>` - Interval for progress updates in seconds (0 disables progress)
- `--allow-cancel` - Allow the task to be cancelled safely during execution
- `--max-retries=<count>` - Maximum number of retry attempts for failed tasks (0 disables retry)
- `--retry-delay=<seconds>` - Delay in seconds between retry attempts

Examples:
```bash
# Run a single command
niuv run nim c myfile.nim

# Run a script
niuv run ./myscript.sh

# Run multiple commands in parallel
niuv run --parallel=4 "nim c file1.nim" "nim c file2.nim" "nim c file3.nim"

# Run commands with specific environment variables
niuv run --env=DEBUG=1 "nim c -d:debug myfile.nim"

# Run commands in a specific directory
niuv run --working-dir=./src "nim c myfile.nim"

# Run commands with priorities
niuv run --priority=high "nim c critical.nim" --priority=low "nim c lessimportant.nim"

# Run commands with dependencies
niuv run --id=lib "nim c lib.nim" --id=main "nim c -r main.nim" --depends-on=lib

# Run commands with progress reporting
niuv run --id=long_task --expected-duration=30 --progress-interval=1 "nim c -d:release large_project.nim"

# Run commands with cancellation support
niuv run --id=task1 --allow-cancel "nim c large_file.nim"

# Run commands with automatic retry for flaky operations
niuv run --id=flaky_test --max-retries=3 --retry-delay=2 "nim c -r flaky_test.nim"
```

#### `info`

Shows information about the current environment.

```bash
niuv info
```

#### `setup`

Sets up shell integration for easier activation.

```bash
niuv setup
```

#### `test`

Runs tests with various options and subcommands.

```bash
niuv test [subcommand] [options] [files...]
```

Subcommands:
- `run` - Run tests (default if no subcommand given)
- `coverage` - Run tests with code coverage analysis
- `analyze` - Analyze test patterns with nim-testkit (requires -d:niuvTestKit)
- `generate` - Generate test files with nim-testkit (requires -d:niuvTestKit)

##### `test run`

Run tests with the test framework.

```bash
niuv test run [options] [pattern]
```

Options:
- `--pattern=<pattern>` - Test file pattern (default: tests/test_*.nim)
- `--verbose` - Show detailed output

Examples:
```bash
# Run all tests
niuv test

# Run specific test file
niuv test tests/test_config.nim

# Run tests matching pattern
niuv test run --pattern="tests/**/test_*.nim"
```

##### `test coverage`

Run tests with code coverage analysis.

```bash
niuv test coverage [options] [test_files...]
```

Options:
- `--pattern, -p <pattern>` - Test file pattern (default: tests/test_*.nim)
- `--export, -e <format>` - Export format (cobertura, sonarqube)
- `--help, -h` - Show help for coverage command

Examples:
```bash
# Run all tests with coverage
niuv test coverage

# Run specific test with coverage
niuv test coverage tests/test_config.nim

# Export coverage in Cobertura format
niuv test coverage --export cobertura

# Export coverage in SonarQube format
niuv test coverage --export sonarqube
```

Coverage reports are generated in the `coverage/` directory:
- `index.html` - HTML coverage report
- `coverage.json` - JSON coverage data
- `coverage.info` - LCOV format (if configured)
- `coverage.txt` - Text summary (if configured)

##### `test analyze`

Analyze test patterns using nim-testkit (requires compilation with -d:niuvTestKit).

```bash
niuv test analyze [pattern]
```

##### `test generate`

Generate test files using nim-testkit (requires compilation with -d:niuvTestKit).

```bash
niuv test generate <type> [name]
```

Examples:
```bash
# Generate a basic test
niuv test generate basic test_new_feature

# Generate a benchmark test
niuv test generate benchmark test_performance
```

#### `help`

Shows help information.

```bash
niuv help
```

#### `version`

Shows version information.

```bash
niuv version
```

## Configuration File

Niuv uses a TOML configuration file (`niuv.toml`) for project-specific settings:

```toml
[tool.niuv]
nim_version = "2.0.0"
nimble_dir = ".niuv/deps"
lockfile = "nimble.lock"
auto_lock = true
parallel_jobs = 4
verbose_output = false
shell_integration = true

[tool.niuv.coverage]
enabled = true
outputDir = "coverage"
threshold = 80.0
formats = ["html", "json"]
includePatterns = ["src/**/*.nim", "tests/**/*.nim"]
excludePatterns = ["**/vendor/**", "**/nimcache/**"]
```

### Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `nim_version` | string | "" | Nim version to use |
| `nimble_dir` | string | ".niuv/deps" | Directory for Nimble packages |
| `lockfile` | string | "nimble.lock" | Path to the lockfile |
| `auto_lock` | boolean | true | Enable automatic lockfile generation |
| `parallel_jobs` | integer | 4 | Number of parallel jobs for installation |
| `verbose_output` | boolean | false | Enable verbose output |
| `shell_integration` | boolean | false | Enable shell integration |

### Coverage Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `coverage.enabled` | boolean | true | Enable coverage collection |
| `coverage.outputDir` | string | "coverage" | Directory for coverage reports |
| `coverage.threshold` | float | 80.0 | Minimum coverage percentage required |
| `coverage.formats` | array | ["html", "json"] | Report formats to generate |
| `coverage.includePatterns` | array | ["src/**/*.nim", "tests/**/*.nim"] | File patterns to include |
| `coverage.excludePatterns` | array | ["**/vendor/**", "**/nimcache/**"] | File patterns to exclude |

## Environment Variables

Niuv respects the following environment variables:

| Variable | Description |
|----------|-------------|
| `NIUV_ACTIVE_VENV` | Name of the currently active virtual environment |
| `NIUV_VERBOSE` | Set to `1` to enable detailed logging of operations |
| `NIUV_TEST_MODE` | Set to `1` to enable test mode |
| `NIUV_TEST_HOME` | Custom home directory for tests |
| `NIUV_TEST_RESPONSE` | Automatic response for prompts in test mode |
| `WEAVE_NUM_THREADS` | Control the number of threads in the parallel execution thread pool |