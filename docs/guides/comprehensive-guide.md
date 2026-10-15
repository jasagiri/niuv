# Niuv - Comprehensive Development Tool Guide

## Overview

Niuv is a next-generation virtual environment manager and development tool for Nim projects, designed to provide a unified, MECE (Mutually Exclusive, Collectively Exhaustive) development experience.

## Philosophy

### Design Principles

1. **Minimal Project Configuration**: Projects should work out-of-the-box with minimal setup
2. **Intelligent Defaults**: Smart behavior that adapts to project structure
3. **Backward Compatibility**: Full compatibility with existing nimble projects
4. **Progressive Enhancement**: Enhanced features for projects that need them

### MECE Development Experience

- **Mutually Exclusive**: Each tool has a clear, non-overlapping responsibility
- **Collectively Exhaustive**: All development needs are covered
- **Unified Interface**: Single command interface for all development tasks

## Core Features

### 1. Smart Test Discovery and Execution

#### Default Behavior

```bash
# Intelligent test execution - tries these in order:
niuv test
```

**Execution Priority:**
1. **Project-specific**: Uses `nimble test` task if defined
2. **Comprehensive suite**: Runs `tests/test_all.nim` if available
3. **Property tests**: Runs `tests/test_all_properties.nim` if available  
4. **Auto-discovery**: Finds and runs all `tests/test_*.nim` files
5. **Subdirectory scan**: Searches subdirectories for additional tests

#### Flexible Test Selection

```bash
# Run specific tests
niuv test test_config.nim              # Run specific file
niuv test tests/test_tamayura.nim       # Full path
niuv test tamayura                      # Short name (searches tests/test_tamayura.nim)

# Pattern matching
niuv test "test_*.nim"                  # All test files in current dir
niuv test "tests/core/**/test_*.nim"    # Subdirectory patterns

# Verbose output
niuv test --verbose                     # Show detailed execution
```

### 2. Build System Integration

#### Intelligent Build

```bash
# Smart build - tries nim compiler first, falls back to nimble
niuv build

# Build options
niuv build --release                    # Release build
niuv build --debug                     # Debug build  
niuv build --verbose                   # Show build details
niuv build --output=custom_name        # Custom output name
```

#### Build Strategy

1. **Nim Compiler**: Direct compilation with smart source file discovery
2. **Nimble Fallback**: Uses nimble build if nim compilation fails
3. **Auto-configuration**: Automatically finds main source files

### 3. Task Execution System

#### Task Discovery

```bash
# List available tasks
niuv task -l
niuv task --list

# Execute tasks
niuv task build                         # Run build task
niuv task test                         # Run test task
niuv task docs                         # Generate documentation
```

#### Task Features

- **Nimble Integration**: Parses and executes .nimble file tasks
- **Dependency Resolution**: Handles task dependencies automatically
- **Delegation Support**: Can delegate to external tools (nimble, etc.)

### 4. Package Management

#### Search and Discovery

```bash
# Package operations
niuv search json                        # Search packages
niuv search web --tag http             # Search with tags

# Package info
niuv path json                         # Show package path
niuv dump json                         # Show package metadata
niuv check                             # Validate current package
```

#### Development Workflow

```bash
# Package development
niuv develop ../mypackage              # Link package for development
niuv publish                           # Publish package
niuv publish --dry-run                 # Validate before publishing
```

### 5. Environment Management

#### Virtual Environments

```bash
# Environment operations
niuv init                              # Initialize virtual environment
niuv init --nim-version=2.2.4         # Specify Nim version
niuv activate                          # Activate environment
niuv shell                             # Start shell with activated environment

# Environment info
niuv info                              # Show environment status
```

#### Shell Integration

```bash
# Setup shell integration (optional)
niuv setup

# After setup, environments auto-activate when entering project directories
```

## Configuration

### Minimal Configuration Philosophy

Niuv is designed to work with **zero configuration** for most projects. Configuration is only needed for:

1. **Custom test discovery patterns** (if standard patterns don't work)
2. **Specific Nim version requirements** (if different from system default)
3. **Advanced build configurations** (if simple builds don't suffice)

### Project Configuration (Optional)

#### niuv.toml (Optional)

```toml
[project]
name = "my-project"
version = "1.0.0"

[environment] 
nim_version = "2.2.4"

[testing]
# Only needed if custom test patterns required
test_patterns = ["tests/test_*.nim", "spec/**/*_spec.nim"]
```

#### nimble File Integration

Niuv respects existing nimble configurations:

```nim
# In your .nimble file
task test, "Run comprehensive test suite":
  exec "nim c -r tests/test_all.nim"
  exec "nim c -r tests/test_all_properties.nim"

task build, "Build optimized binary":
  exec "nim c -d:release -o:bin/myapp src/main.nim"
```

## Advanced Features

### 1. Delegation Framework

Niuv can delegate operations to specialized tools:

```bash
# These may delegate to external tools when available
niuv test      # May use nim-testkit, unittest, or custom test runners
niuv build     # May use nimble, nim compiler, or custom build systems
niuv task      # May execute nimble tasks or custom task runners
```

### 2. Workspace Support

```bash
# Multi-package workspace management
niuv workspace init                     # Initialize workspace
niuv workspace install                  # Install all dependencies
niuv workspace build                   # Build all packages
niuv workspace test                    # Test all packages
```

### 3. Integration with Development Tools

#### VS Code Integration

```json
// .vscode/settings.json
{
  "terminal.integrated.shellArgs.osx": ["-c", "niuv activate && exec $SHELL"],
  "nim.project": ["project.nimble"],
  "terminal.integrated.env.osx": {
    "NIUV_AUTO_ACTIVATE": "1"
  }
}
```

#### CI/CD Integration

```yaml
# .github/workflows/test.yml
- name: Run Tests
  run: |
    niuv test
    
- name: Build Release
  run: |
    niuv build --release
```

## Command Reference

### Core Commands

| Command | Description | Example |
|---------|-------------|---------|
| `niuv test` | Run tests with auto-discovery | `niuv test` |
| `niuv build` | Build project with smart detection | `niuv build --release` |
| `niuv task` | Execute nimble tasks | `niuv task docs` |
| `niuv help` | Show help information | `niuv help` |
| `niuv version` | Show version information | `niuv version` |

### Environment Commands

| Command | Description | Example |
|---------|-------------|---------|
| `niuv init` | Initialize virtual environment | `niuv init` |
| `niuv activate` | Activate environment | `niuv activate` |
| `niuv shell` | Start activated shell | `niuv shell` |
| `niuv info` | Show environment info | `niuv info` |
| `niuv setup` | Setup shell integration | `niuv setup` |

### Package Commands

| Command | Description | Example |
|---------|-------------|---------|
| `niuv search` | Search for packages | `niuv search json` |
| `niuv publish` | Publish package | `niuv publish --dry-run` |
| `niuv develop` | Link package for development | `niuv develop ../mylib` |
| `niuv path` | Show package paths | `niuv path json` |
| `niuv dump` | Show package metadata | `niuv dump --json` |

### Workspace Commands

| Command | Description | Example |
|---------|-------------|---------|
| `niuv workspace init` | Initialize workspace | `niuv workspace init` |
| `niuv workspace install` | Install workspace deps | `niuv workspace install` |
| `niuv workspace build` | Build all packages | `niuv workspace build` |
| `niuv workspace test` | Test all packages | `niuv workspace test` |

## Best Practices

### 1. Project Structure

```
my-project/
├── src/
│   └── main.nim
├── tests/
│   ├── test_all.nim              # Comprehensive test suite (preferred)
│   ├── test_all_properties.nim   # Property-based tests
│   ├── test_module1.nim          # Individual module tests
│   └── core/
│       └── test_core_types.nim   # Organized by component
├── project.nimble                # Standard nimble file
└── README.md
```

### 2. Test Organization

#### Comprehensive Test Suite (Recommended)

```nim
# tests/test_all.nim
## Main test suite that imports all test modules

# Import all test modules
import test_module1
import test_module2
import core/test_core_types

# Property-based tests
import test_all_properties
```

#### Individual Test Files

```nim
# tests/test_module1.nim
import std/unittest
import ../src/module1

suite "Module1 Tests":
  test "basic functionality":
    check module1Function() == expectedResult
```

### 3. Nimble File Configuration

```nim
# project.nimble
version = "1.0.0"
author = "Your Name"
description = "Project description"
license = "MIT"

requires "nim >= 2.0.0"

# Optional: Custom test task (niuv will use this if available)
task test, "Run comprehensive tests":
  exec "nim c -r tests/test_all.nim"
  exec "nim c -r tests/test_all_properties.nim"

# Optional: Custom build task
task build, "Build optimized binary":
  exec "nim c -d:release -o:bin/myapp src/main.nim"
```

## Migration Guide

### From Pure Nimble

1. **No changes required** - niuv is fully compatible with existing nimble projects
2. **Optional**: Add `tests/test_all.nim` for better test discovery
3. **Optional**: Use `niuv test` instead of `nimble test` for enhanced features

### From Other Build Systems

1. **Organize tests** using standard `tests/test_*.nim` pattern
2. **Create nimble file** if one doesn't exist
3. **Use niuv commands** instead of custom scripts

## Troubleshooting

### Common Issues

#### Tests Not Found

```bash
# Check test discovery
niuv test --verbose

# Verify test file naming
ls tests/test_*.nim

# Check if nimble test task exists
niuv task --list
```

#### Build Failures

```bash
# Try verbose build
niuv build --verbose

# Check source file detection
ls src/*.nim

# Fall back to nimble
nimble build
```

#### Environment Issues

```bash
# Check environment status
niuv info

# Reinitialize if needed
niuv init --force
```

### Getting Help

```bash
# Command-specific help
niuv test --help
niuv build --help
niuv task --help

# General help
niuv help
```

## Future Features

### Planned Enhancements

1. **Watch Mode**: `niuv test --watch` for continuous testing
2. **Performance Profiling**: Integrated benchmarking and profiling
3. **Code Coverage**: Built-in coverage reporting
4. **Documentation Generation**: `niuv doc` command
5. **Dependency Analysis**: Advanced dependency resolution and analysis

### Extension Points

1. **Custom Test Runners**: Plugin system for specialized test frameworks
2. **Build Plugins**: Support for custom build systems
3. **IDE Integration**: Enhanced editor support
4. **Cloud Integration**: Remote build and test execution

## Conclusion

Niuv provides a unified, intelligent development experience for Nim projects by:

- **Minimizing configuration overhead** through smart defaults
- **Respecting existing project structures** and conventions
- **Providing enhanced functionality** when needed
- **Maintaining full compatibility** with the Nim ecosystem

The tool embodies the MECE principle by providing clear, non-overlapping functionality that collectively covers all development needs while requiring minimal project-specific configuration.