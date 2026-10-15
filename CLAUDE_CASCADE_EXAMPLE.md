---
inherit: ../../../CLAUDE.md
cascade: true
project: niuv
type: library
---

## [OVERRIDE] Repository Overview
This repository contains **niuv** - Nim Universal Virtualenv, a comprehensive virtual environment and task management system for Nim projects. It provides isolated development environments, dependency management, and standardized task execution across the GodsGolemInc ecosystem.

Key features:
- Virtual environment creation and management
- Dependency isolation and lock files
- Task standardization and execution
- Global configuration management
- Test discovery and parallel execution
- Tool delegation to nim-testkit and other tools

## [APPEND] Common Development Commands
### Niuv-Specific Commands
```bash
# Self-compilation
nim c -d:release -o:~/.local/bin/niuv src/niuv.nim
nim c -d:release --forceBuild -o:~/.local/bin/niuv src/niuv.nim  # Force rebuild

# Configuration management
niuv setup-config                # Create global configuration
niuv show-config                 # Display current settings
niuv validate-config             # Validate configuration

# Enhanced testing
niuv test-all                    # Run comprehensive test suite
niuv test tests/test_*.nim       # Run specific tests
niuv tests --coverage            # Run all tests with coverage

# Update management
niuv check-updates               # Check for available updates

# Project generation
niuv generate my-project         # Create new project from template
```

## [OVERRIDE] Architecture
Niuv consists of several interconnected modules:

### Core Components
1. **Main Module (`niuv.nim`)**: Entry point, command routing, and help system
2. **Configuration (`config.nim`)**: TOML-based settings, environment variables, defaults
3. **Environment Management (`env.nim`)**: Virtual environment creation, activation, isolation
4. **Package Installation (`install.nim`)**: Dependency resolution, lock files, parallel installation
5. **Task Runner (`tasks.nim`)**: Standardized task execution, command chaining
6. **Test Runner (`test_runner.nim`)**: Automatic test discovery, parallel execution, coverage

### Delegation System
- **Base Framework**: Core delegation interfaces and patterns
- **Command Delegates**: Specialized handlers for build, test, doc, release
- **Tool Integration**: Seamless integration with nim-testkit, nimble
- **MCP Integration**: AI-powered development assistance

### Data Flow
1. Command parsing and validation
2. Configuration loading (CLI → project → user → env → defaults)
3. Environment verification and setup
4. Task execution (potentially parallel)
5. Result formatting and display

## [MODIFY] Testing
<!-- INSERT AFTER: "niuv tests" -->
niuv test-all          # Comprehensive test suite (recommended)
niuv test --watch      # Run tests on file changes
niuv tests --list      # List discoverable tests
<!-- END INSERT -->

## [APPEND] Configuration
### Niuv Configuration Files

1. **Project Configuration** (`niuv.toml`):
```toml
[project]
name = "my-project"
version = "0.1.0"

[tasks]
build = { command = "nim c -d:release src/main.nim" }
test = { command = "niuv tests" }

[testing]
coverage = true
parallel = true
```

2. **Global Configuration** (`~/.config/niuv/config.ini`):
```ini
[coverage]
enabled=true
threshold=80.0
format=html

[performance]
parallel=true
max_jobs=4
```

3. **Environment Variables**:
- `NIUV_TESTKIT_COVERAGE`: Override coverage settings
- `NIUV_CONFIG_PATH`: Custom config location
- `NIUV_DEBUG`: Enable debug output

## [NEW] Advanced Features

### Automatic Test Discovery
Niuv eliminates the need for `test_all.nim` files:
```bash
# Discovers tests matching these patterns:
# - tests/test_*.nim
# - tests/*_test.nim
# - test/test_*.nim
# - Custom patterns in niuv.toml

niuv tests                      # Run all discovered tests
niuv tests --category=unit      # Run only unit tests
niuv tests --parallel           # Parallel execution
```

### Task Standardization
All projects inherit standard tasks:
- `build`, `dev`, `debug` - Compilation variants
- `test`, `tests`, `coverage` - Testing commands  
- `clean`, `docs`, `format` - Utility tasks
- `ci`, `pre-commit` - Workflow tasks

### Global TestKit Integration
Niuv provides ecosystem-wide test coverage:
```bash
niuv setup-config              # Configure global TestKit
niuv test-all                  # Run Hourai W9P2025 tests
```

## [NEW] Implementation Notes

### Known Limitations
- `niuv test` has an infinite loop issue - use `niuv test-all` instead
- Coverage HTML reports may be empty due to Nim's compilation model
- Some tests excluded from parallel execution due to module conflicts

### Performance Characteristics
- Startup time: < 50ms
- Test discovery: < 100ms for 1000 files
- Parallel speedup: 3-4x on 4+ cores
- Memory usage: < 20MB typical

## [PREPEND] Important Guidelines
### Critical Niuv Usage Notes
1. Always use `niuv test-all` instead of `niuv test` (known issue)
2. Run `niuv setup-config` after installation for global features
3. Check `~/.config/niuv/config.ini` for global settings
4. Use `--forceBuild` when updating niuv itself