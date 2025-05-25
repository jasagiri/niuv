# Niuv Testing Refactor Documentation

## Overview

The niuv testing functionality has been refactored to provide a simpler command-line interface while moving configuration complexity to the nim-testkit adapter layer. This design follows the principle of keeping niuv's top-level commands minimal while providing rich functionality through subcommands.

## Command Structure

### Before (Complex Top-Level Commands)
```bash
niuv test [options]
niuv test-analyze
niuv test-generate <type>
niuv coverage [options]
```

### After (Simplified Subcommands)
```bash
niuv test [subcommand] [args]
  - run      Run tests (default if no subcommand)
  - analyze  Analyze test structure
  - generate Generate test files
  - coverage Run with coverage analysis
```

## Usage Examples

### Running Tests

```bash
# Run all tests (default)
niuv test

# Run specific test file
niuv test test_config.nim

# Run tests matching pattern
niuv test "test_*.nim"

# Explicitly use run subcommand
niuv test run test_config.nim
```

### Analyzing Test Structure

```bash
# Analyze test structure using MECE principles
niuv test analyze
```

### Generating Tests

```bash
# Generate unit test
niuv test generate unit api

# Generate integration test
niuv test generate integration user_service

# Generate system test
niuv test generate system e2e_flow
```

### Coverage Analysis

```bash
# Run tests with coverage
niuv test coverage

# Pass arguments directly to coverage tool
niuv test coverage --threshold=90 --format=html,lcov
```

## Configuration Changes

### Minimal niuv.toml

The niuv.toml configuration has been simplified to contain only essential settings:

```toml
[tool.niuv]
nim_version = "2.0.0"
nimble_dir = ".niuv/deps"
lockfile = "nimble.lock"
auto_lock = true

[tool.niuv.testing]
# Only specify what differs from defaults
backend = "niuv"  # or "testkit"
```

### Default Configuration

All test configuration defaults are now managed by the testkit_adapter module:

- **Test Execution**
  - `pattern`: "test_*.nim"
  - `fail_fast`: false
  - `output_dir`: "build/test_output"
  - `generate_report`: true
  - `timeout`: 300.0 (5 minutes)

- **Coverage**
  - `threshold`: 80.0
  - `formats`: ["html", "json"]
  - `output_dir`: "coverage"
  - `include`: ["src/**/*.nim"]
  - `exclude`: ["tests/**/*.nim", "vendor/**/*.nim"]

- **Test Organization**
  - `test_dir`: "tests"
  - `unit_dir`: "tests/unit"
  - `integration_dir`: "tests/integration"
  - `system_dir`: "tests/system"
  - `performance_dir`: "tests/performance"

- **MECE Analysis**
  - `enabled`: true
  - `strict`: false

## Implementation Details

### niuv.nim Changes

The main niuv.nim file now has minimal test handling:

```nim
proc handleTestRun(args: seq[string], options: CliOptions): bool =
  var testConfig = newTestRunnerConfig()
  testConfig.verbose = options.verbose
  
  for arg in args:
    if arg.endsWith(".nim"):
      testConfig.testFiles.add(arg)
      testConfig.mode = trmSingle
    else:
      testConfig.pattern = arg
      testConfig.mode = trmPattern
  
  runAndReport(testConfig)
```

### testkit_adapter.nim

The adapter module contains:

1. **TestKitConfig** - Comprehensive configuration object with all defaults
2. **Configuration Loading** - From niuv.toml and command line
3. **Test Runner Integration** - Bridge between niuv and nim-testkit
4. **MECE Analysis** - Test structure analysis
5. **Test Generation** - Template-based test file generation

### Benefits

1. **Simpler CLI** - Users only need to remember `niuv test` with intuitive subcommands
2. **Flexible Configuration** - Defaults work for most cases, override only what's needed
3. **Extensibility** - New test features can be added to testkit without changing niuv
4. **Consistency** - All test-related functionality under single command
5. **Discoverability** - Subcommands make features more discoverable

## Migration Guide

For existing users:

1. Replace `niuv test-analyze` with `niuv test analyze`
2. Replace `niuv test-generate` with `niuv test generate`
3. Replace `niuv coverage` with `niuv test coverage`
4. Remove most test configuration from niuv.toml (defaults are sensible)
5. Complex test options are now handled by the testkit adapter

## Future Enhancements

The refactored structure allows for easy addition of new subcommands:

- `niuv test watch` - Watch mode for continuous testing
- `niuv test benchmark` - Performance testing
- `niuv test mutate` - Mutation testing
- `niuv test profile` - Test profiling