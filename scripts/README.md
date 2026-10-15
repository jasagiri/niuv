# niuv Scripts Directory Structure

This directory contains all scripts for the niuv project, organized by functionality.

## Directory Structure

```
scripts/
├── README.md           # This file
├── build.sh           # Main build script (all, tests, examples, main, clean)
├── test.sh            # Main test runner (with coverage, specific tests, etc.)
├── shellspec.sh       # ShellSpec test runner for script testing
│
├── core/              # Core functionality scripts
│   ├── clean.sh       # Project cleaning and maintenance
│   ├── coverage.sh    # Coverage report generation
│   └── docs.sh        # Documentation generation
│
├── dev/               # Development tools
│   ├── setup.sh       # Development environment setup
│   ├── watch.sh       # File watcher for development
│   └── lint.sh        # Code linting and formatting
│
├── ci/                # CI/CD scripts
│   ├── pipeline.sh    # Main CI pipeline script
│   ├── release.sh     # Release automation
│   └── deploy.sh      # Deployment scripts
│
├── utils/             # Utility scripts
│   ├── common.sh      # Common functions and utilities
│   ├── platform.sh    # Platform-specific helpers
│   └── install.sh     # Dependency installation
│
├── legacy/            # Deprecated scripts (for backward compatibility)
│   ├── compile_examples.sh
│   ├── compile_tests.sh
│   └── run_tests.sh
│
└── _archive/          # Old scripts to be removed
    └── *.sh           # Various outdated scripts
```

## Main Scripts

### build.sh
The unified build script for all compilation tasks:
```bash
./scripts/build.sh [target] [options]
# Targets: all, tests, examples, main, clean
# Options: --debug, --release
```

### test.sh
The unified test runner with comprehensive options:
```bash
./scripts/test.sh [options] [pattern]
# Options: --verbose, --coverage, --specific, --cleanup, --no-build
```

### shellspec.sh
Run ShellSpec tests for the scripts themselves:
```bash
./scripts/shellspec.sh [options]
# Options: --verbose, --coverage, --pattern
```

## Core Scripts

### core/clean.sh
Clean build artifacts and temporary files:
```bash
./scripts/core/clean.sh [options]
# Options: --all, --cache, --deps
```

### core/coverage.sh
Generate test coverage reports:
```bash
./scripts/core/coverage.sh [options]
# Options: --html, --lcov, --open
```

### core/docs.sh
Generate project documentation:
```bash
./scripts/core/docs.sh [options]
# Options: --api, --guides, --all
```

## Development Scripts

### dev/setup.sh
Set up development environment:
```bash
./scripts/dev/setup.sh
```

### dev/watch.sh
Watch files for changes and rebuild:
```bash
./scripts/dev/watch.sh [target]
```

### dev/lint.sh
Run code quality checks:
```bash
./scripts/dev/lint.sh [options]
```

## CI/CD Scripts

### ci/pipeline.sh
Run the complete CI pipeline:
```bash
./scripts/ci/pipeline.sh
```

### ci/release.sh
Create a new release:
```bash
./scripts/ci/release.sh [version]
```

## Conventions

1. **Naming**: Use lowercase with underscores for script names
2. **Extensions**: Use `.sh` for shell scripts, `.py` for Python scripts
3. **Shebang**: Always include appropriate shebang (`#!/bin/bash` or `#!/usr/bin/env python3`)
4. **Documentation**: Include header comments with usage information
5. **Error Handling**: Use `set -euo pipefail` for shell scripts
6. **Logging**: Use consistent logging functions (log_info, log_error, etc.)

## Cross-Platform Support

For scripts that need Windows support, create a `.bat` wrapper that calls the main `.sh` script through WSL or Git Bash, or implement the logic in Nim for true cross-platform support.

## Migration Notes

The following scripts have been deprecated in favor of unified scripts:
- `compile_examples.sh` → `build.sh examples`
- `compile_tests.sh` → `build.sh tests`
- `run_tests.sh` → `test.sh`

These deprecated scripts now redirect to their replacements for backward compatibility.