# ShellSpec Tests for niuv Shell Scripts

This directory contains ShellSpec tests for the niuv project's shell scripts.

## Directory Structure

```
spec/
├── README.md           # This file
├── spec_helper.sh      # Common test helpers and setup
├── scripts/            # Tests for main scripts
│   ├── build_spec.sh   # Tests for scripts/build.sh
│   └── test_spec.sh    # Tests for scripts/test.sh
├── integration/        # Integration tests
│   └── workflow_spec.sh # Tests for complete workflows
├── fixtures/           # Test fixtures
│   └── sample_project/ # Sample project structure
└── support/            # Additional test support files
    └── matchers.sh     # Custom ShellSpec matchers
```

## Running Tests

### Prerequisites

Install ShellSpec:
```bash
# Using Homebrew (macOS)
brew install shellspec

# Using curl (any platform)
curl -fsSL https://git.io/shellspec | sh

# Or see https://github.com/shellspec/shellspec for more options
```

### Running All Tests

From the project root:
```bash
# Using the helper script (recommended)
./scripts/run_shellspec.sh

# Or directly with shellspec
shellspec
```

### Running Specific Tests

```bash
# Run only build.sh tests
./scripts/run_shellspec.sh -p "build_spec.sh"

# Run only test.sh tests
./scripts/run_shellspec.sh -p "test_spec.sh"

# Run integration tests
./scripts/run_shellspec.sh -p "workflow_spec.sh"
```

### Running with Different Options

```bash
# Verbose output
./scripts/run_shellspec.sh -v

# Stop on first failure
./scripts/run_shellspec.sh -x

# Different reporter format
./scripts/run_shellspec.sh -r tap      # TAP format
./scripts/run_shellspec.sh -r junit    # JUnit XML format

# With coverage (requires kcov)
./scripts/run_shellspec.sh --coverage
```

## Writing Tests

### Basic Test Structure

```bash
Describe 'script name'
  Include spec_helper.sh
  
  BeforeEach 'setup'
  AfterEach 'cleanup'
  
  It 'does something'
    When run script "./scripts/build.sh" help
    The status should be success
    The output should include "Usage:"
  End
End
```

### Available Helpers

From `spec_helper.sh`:
- `create_test_project()` - Creates a minimal test project structure
- `capture_output()` - Captures stdout, stderr, and exit code
- `mock_nim()` - Creates a mock nim compiler for testing
- `count_files()` - Counts files matching a pattern

### Custom Matchers

From `support/matchers.sh`:
- `include_nim_flags` - Check for specific nim compiler flags
- `have_build_structure` - Verify build directory structure exists
- `show_test_results` - Check test result format

## Test Coverage

The tests cover:

### build.sh
- Help command functionality
- Argument parsing (targets, modes)
- All build targets (all, main, examples, tests, clean)
- Error handling (missing project file, compilation failures)
- Build modes (debug, release)
- Directory creation
- Build statistics reporting

### test.sh
- Help command functionality
- Option parsing (verbose, coverage, specific, cleanup, no-build)
- Test environment setup
- Test building with various options
- Test execution and reporting
- Coverage generation
- Error handling
- Test pattern matching

### Integration Tests
- Full build and test workflows
- Clean, build, test sequences
- Release vs debug workflows
- Error recovery scenarios
- Coverage workflows

## Continuous Integration

The `.github/workflows/shellspec.yml` workflow runs these tests automatically on:
- Push to main or develop branches
- Pull requests to main
- When shell scripts or tests are modified

Tests run on both Ubuntu and macOS with bash and sh shells.