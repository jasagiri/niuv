# Contributing to Niuv

Thank you for your interest in contributing to Niuv! This document provides guidelines and instructions for contributing to this project.

## Code of Conduct

Please be respectful and considerate when participating in this project. We aim to foster an inclusive and welcoming community.

## How to Contribute

### Reporting Bugs

If you find a bug, please create an issue on GitHub with the following information:

1. A clear, descriptive title
2. Steps to reproduce the issue
3. Expected behavior
4. Actual behavior
5. Environment information (OS, Nim version, etc.)
6. Any relevant screenshots or error messages

### Suggesting Features

We welcome feature suggestions! When suggesting a feature, please:

1. Check if the feature has already been suggested or implemented
2. Provide a clear description of the feature
3. Explain the use case and benefits
4. Include any relevant examples or mockups

### Pull Requests

We welcome pull requests! To submit a PR:

1. Fork the repository
2. Create a new branch for your feature/fix
3. Write your code following our style guide
4. Add tests for your changes
5. Run the test suite to ensure all tests pass
6. Submit a pull request with a clear description of your changes

## Development Environment Setup

### Prerequisites

- Nim 2.0.0 or higher
- Git

### Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/example/niuv.git
   cd niuv
   ```

2. Install dependencies:
   ```bash
   nimble install
   ```

3. Run tests:
   ```bash
   nimble test
   ```

4. Build the application:
   ```bash
   nimble buildMain
   ```

## Development Workflow

### Building and Compiling

We now use a more structured build system with standardized output directories:

1. **Debug Build (Development)**:
   ```bash
   nimble build
   ```

2. **Release Build**:
   ```bash
   nimble buildMain
   ```

3. **Build Everything** (tests, examples, main executable):
   ```bash
   nimble buildAll
   ```

All build artifacts are placed in the `build/` directory:
- Binaries go to `build/bin/`
- Test binaries go to `build/tests/`
- Nim compiler cache is in `build/nimcache/`

### Testing

We have enhanced the testing infrastructure with several options:

1. **Run All Tests**:
   ```bash
   nimble test
   ```

2. **Run a Specific Test**:
   ```bash
   nimble testOne tests/test_config.nim
   ```

3. **Run a Test with Detailed Output**:
   ```bash
   nimble runTest test_config.nim
   ```

4. **Generate Test Reports**:
   ```bash
   nimble testWithReport
   ```

5. **Full Test Suite with Coverage**:
   ```bash
   nimble fullTest
   ```

### Cleaning

To clean build artifacts:

```bash
nimble clean      # Clean build artifacts (preserves nimbledeps)
nimble cleanall   # Clean ALL artifacts including nimbledeps
```

## Coding Guidelines

### Style Guide

- Follow the [Nim style guide](https://nim-lang.org/docs/nep1.html)
- Use 2 spaces for indentation
- Use camelCase for variables and snake_case for filenames
- Use meaningful variable and function names
- Keep functions focused on a single responsibility
- Add documentation comments for all public functions

### Testing

- Write tests for all new features and bug fixes
- Ensure all tests pass before submitting a PR
- Use the test mode with `NIUV_TEST_MODE=1` for testing
- Prefer using the BDD-style tests for new features when appropriate
- Add test reports when submitting PRs

### Documentation

- Update relevant documentation for all changes
- Document all public functions with clear descriptions
- Include examples for complex functionality
- Keep the API reference up to date

## Project Structure

The project has been reorganized for better maintainability and now includes tools migrated from nim_boilerplate. Please follow this structure for all new contributions.

### Directory Structure

```
├── build/                # Build artifacts (created during build)
│   ├── bin/              # Compiled binaries
│   ├── tests/            # Compiled test binaries
│   ├── nimcache/         # Nim compiler cache files
│   ├── docs/             # Generated documentation
│   ├── reports/          # Generated test reports
│   └── test_output/      # Test execution output
├── nimbledeps/           # Nim package dependencies
├── docs/                 # Documentation
├── examples/             # Example configurations and projects
├── scripts/              # Utility scripts
│   ├── ci/               # CI/CD scripts
│   ├── cleanup/          # Cleanup scripts
│   ├── demo/             # Demo scripts
│   └── tests/            # Test scripts
├── src/                  # Source code
│   ├── tools/            # Tool implementations
│   │   ├── build/        # Build tools
│   │   ├── clean/        # Cleanup tools
│   │   ├── report/       # Reporting tools
│   │   └── test/         # Testing tools
│   ├── utils/            # Utility modules
│   │   ├── fs.nim        # File system utilities
│   │   └── shell.nim     # Shell command utilities
│   └── [core modules]    # Core application modules
├── templates/            # Code templates
├── tests/                # Tests
│   ├── fixtures/         # Test fixtures
│   ├── specs/            # BDD feature specifications
│   ├── steps/            # BDD step implementations
│   └── [test modules]    # Test modules
└── vendor/               # Vendored dependencies
```

### Key Modules and Tools

The project now includes migrated utility tools that you should use in your development:

1. **File System Utilities** (`src/utils/fs.nim`)
   - Use for file and directory operations
   - Provides safe file management functions
   - Always prefer these utilities over direct OS module calls

2. **Shell Utilities** (`src/utils/shell.nim`)
   - Use for executing shell commands
   - Provides cross-platform compatibility
   - Safer command execution with proper error handling

3. **Test Reporting** (`src/tools/report/test_report.nim`)
   - Generates HTML and JSON test reports
   - Use for creating test documentation
   - Integrated with the test runners

4. **Integrated Testing** (`src/niuv_testing.nim`)
   - Centralized test execution framework
   - Support for multiple test modes
   - Integration with test reporting tools

### Build Output Locations

To maintain a clean project structure, always place outputs in the appropriate directories:

- **Binaries**: `build/bin/`
- **Tests**: `build/tests/`
- **Documentation**: `build/docs/`
- **Test output**: `build/test_output/`
- **Test reports**: `build/reports/`

Never commit build artifacts to the repository. Use `.gitignore` to exclude build directories.

## Using the Migrated Tools

### File System Operations

Prefer using the file system utilities from `src/utils/fs.nim` instead of direct OS module calls:

```nim
import utils/fs

# Create a directory safely
discard ensureDirExists("path/to/dir")

# Delete files safely
discard removeIfExists("path/to/file")

# Find files by pattern
let files = findFiles("src", "*.nim")
```

### Shell Commands

Use the shell utilities from `src/utils/shell.nim` for running commands:

```nim
import utils/shell

# Run a command
let (exitCode, output) = runCommand("nim c file.nim", verbose=true)

# Run a command with environment variables
let env = setEnvVars({"NIM_VERBOSE": "1"})
let result = runCommandWithEnv("nim c file.nim", env=env)
```

### Test Running and Reporting

Use the integrated testing module for running tests and generating reports:

```nim
import niuv_testing

# Create a test configuration
var config = newTestRunnerConfig()
config.mode = trmPattern
config.pattern = "test_*.nim"
config.generateReport = true

# Run tests and generate reports
discard runAndReport(config)
```

## Additional Nimble Tasks

The project includes extra Nimble tasks in `nimbletools.nimble` that provide access to the migrated tools:

- `nimble runTest <test_file>`: Run a specific test with detailed output
- `nimble testReport <output_file>`: Generate HTML and JSON reports from test output
- `nimble testWithReport`: Run tests and automatically generate reports
- `nimble fullTest`: Run full test suite with reports and coverage
- `nimble buildTest <test_file>`: Build a specific test without running it
- `nimble buildAllTests`: Build all tests without running them
- `nimble featureReport <format> <output_file>`: Generate BDD feature test reports

## Review Process

1. All PRs require at least one review from a maintainer
2. Automated tests must pass
3. Documentation must be updated for any API changes
4. Style guide must be followed
5. New features should include test reports

## Questions?

If you have any questions about contributing, please open an issue or reach out to the maintainers.

Thank you for contributing to Niuv!