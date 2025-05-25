# Niuv Architecture Overview

This document provides an overview of the architectural design of Niuv, the Nim Virtual Environment Manager.

## Core Components

Niuv is organized into several modules, each with a specific responsibility:

### 1. Main Module (`niuv.nim`)

This is the entry point of the application. It:
- Parses command-line arguments
- Routes to the appropriate module based on the command
- Handles high-level error management
- Provides help and version information

### 2. Configuration Management (`config.nim`)

This module handles all configuration-related tasks:
- Loads configuration from multiple sources (TOML files, environment variables)
- Merges configurations with proper precedence
- Provides default values for missing settings
- Saves configuration changes

Configuration is loaded from these sources in order of precedence:
1. Command-line arguments
2. Project-specific `niuv.toml` file
3. User-specific configuration
4. Environment variables
5. Default values

### 3. Environment Management (`env.nim` and `venv.nim`)

These modules handle the creation and management of virtual environments:
- `env.nim` focuses on the current local environment (directory-based)
- `venv.nim` provides named environments that can be created and switched between

Key responsibilities:
- Creating isolated Nim environments
- Generating activation scripts for different shells
- Managing environment-specific settings
- Handling environment activation and deactivation

### 4. Package Management (`deps.nim` and `install.nim`)

These modules handle package dependencies and installation:
- `deps.nim` focuses on dependency specification and `.nimble` file management
- `install.nim` handles the actual installation process

Key responsibilities:
- Parsing and modifying `.nimble` files
- Installing packages with proper version constraints
- Maintaining lockfiles for reproducible builds
- Handling parallel installation for better performance

### 5. Utilities (`utils.nim` and `cli.nim`)

These modules provide common functionality used across the codebase:
- `utils.nim` contains general utility functions
- `cli.nim` handles user interaction through the command line

Key responsibilities:
- Logging and error reporting
- File system operations
- String processing
- Command-line formatting and styled output
- User prompts and confirmations

### 6. Coverage System (`coverage.nim` and `test_coverage.nim`)

These modules provide code coverage functionality:
- `coverage.nim` handles coverage data collection and report generation
- `test_coverage.nim` integrates coverage with the test framework

Key responsibilities:
- Compiling tests with coverage instrumentation
- Collecting coverage data using gcov
- Parsing gcov output files
- Generating coverage reports in multiple formats (HTML, JSON, LCOV)
- Filtering coverage data to show only project files
- Checking coverage thresholds
- Exporting coverage data for CI/CD integration (Cobertura, SonarQube)

### 7. Parallel Execution (`parallel.nim`)

This module provides a robust framework for executing tasks in parallel:
- Running multiple commands concurrently with thread pool management
- Sophisticated error handling and resource cleanup
- Execution environment isolation to prevent interference
- Performance monitoring and statistics collection
- Detailed logging for debugging and troubleshooting
- Task dependency management for ordered execution

The parallel execution system is designed with these key features:
- **Task Tracking**: Each task has a unique ID, command, working directory, and environment variables
- **Resource Management**: Working directories and environment variables are restored after execution
- **Error Handling**: Comprehensive exception handling with detailed error reporting
- **Performance Metrics**: Detailed execution time tracking and parallel efficiency calculation
- **Debugging Support**: Verbose mode for detailed logging during execution
- **Output Formatting**: Smart truncation of large outputs for better readability
- **Cleanup Guarantees**: Try-finally blocks ensure resources are always properly cleaned up
- **Task Prioritization**: Tasks can be assigned priorities (High, Normal, Low) to control execution order
- **Dependency Graph**: Tasks can depend on other tasks to ensure correct execution order
- **Cycle Detection**: The system automatically detects circular dependencies and reports errors
- **Topological Sorting**: Tasks are automatically arranged in the correct execution order based on dependencies
- **Progress Reporting**: Real-time progress bars and ETAs for long-running tasks
- **Thread-Safe Updates**: Thread-synchronized progress updates for concurrent tasks
- **Visual Feedback**: Terminal-based visual progress indicators with completion percentages
- **Task Cancellation**: Individual tasks can be safely cancelled during execution
- **Graceful Shutdown**: Signal handling (Ctrl+C) for graceful termination of running tasks
- **Resource Cleanup**: Proper cleanup of resources for cancelled and interrupted tasks
- **Task Retry**: Automatic retry capability for failed tasks with configurable retry count and delay
- **Retry History**: Comprehensive tracking of retry attempts and their outputs for debugging

## Data Flow

1. **Command Input**:
   - User invokes `niuv` with a command and options
   - Arguments are parsed in `niuv.nim`
   - Command is routed to the appropriate handler

2. **Configuration Loading**:
   - Project and user configuration are loaded and merged
   - Command-line options override configuration values
   - Default values are used for missing settings

3. **Command Execution**:
   - The appropriate module handles the command
   - Resources are allocated and managed
   - Actions are performed based on the command

4. **Result Presentation**:
   - Results are formatted and displayed to the user
   - Errors are handled and reported appropriately
   - Status information is provided

## Key Design Patterns

### Result-Based Error Handling

Niuv uses a Result[T, E] pattern for error handling:
- Functions return a Result type that can contain either a success value or an error
- Errors are propagated up the call stack
- Centralized error handling in the main module

### Dependency Injection

For better testability, Niuv uses dependency injection:
- Functions accept interfaces rather than concrete implementations
- Mock implementations can be provided for testing
- External dependencies are injected rather than directly instantiated

### Configuration Hierarchy

Configuration is managed through a hierarchical approach:
- Global defaults
- User-specific configuration
- Project-specific configuration
- Command-line overrides

### Task Cancellation and Shutdown

The task cancellation system provides several key features:
- Individual task cancellation by ID
- Graceful shutdown via signal handling (Ctrl+C)
- Two-phase cancellation (first attempt graceful, second forces immediate exit)
- Thread-safe cancellation tracking
- Resource cleanup for cancelled processes
- Visual feedback in progress display
- Dependency respect (dependent tasks also cancelled when dependencies are cancelled)

## Directory Structure

```
├── nimbledeps/       # Installed packages
│   └── pkgs/         # Package directories
├── .niuv/            # Niuv-specific data
│   ├── cache/        # Package cache
│   └── venvs/        # Named virtual environments
├── niuv.toml         # Project configuration
├── nim.cfg           # Nim compiler configuration
├── activate          # Activation script (Unix)
├── activate.bat      # Activation script (Windows)
└── .niuv.json        # Environment metadata
```

## Extension Points

Niuv is designed to be extensible in several ways:

### Custom Commands

New commands can be added by:
1. Adding a command handler in `niuv.nim`
2. Implementing the command logic in an appropriate module
3. Updating the help documentation

### Alternative Package Sources

The package installation system is designed to support different sources:
- Nimble packages (default)
- Git repositories
- Local directories
- Custom sources through a plugin system

### Shell Integration

The shell integration system supports multiple shells:
- Bash
- Zsh
- PowerShell
- CMD
- Custom shells through shell-specific script generation

### Task Cancellation Extension

The task cancellation system can be extended through:
- Custom cancellation handlers
- Integration with external monitoring tools
- Implementation of additional signals beyond Ctrl+C
- Specialized cleanup procedures for different task types

### Task Retry Extension

The task retry system can be extended through:
- Custom retry strategies (exponential backoff, variable delays)
- Conditional retry policies based on error types
- Integration with external monitoring for failure analysis
- Custom logging and notification for retry events

## Testing Strategy

Niuv includes several types of tests:

1. **Unit Tests**: Test individual functions in isolation
2. **Integration Tests**: Test interactions between modules
3. **End-to-End Tests**: Test the complete flow from command input to execution
4. **Regression Tests**: Ensure fixed bugs don't reappear

A special test mode (`NIUV_TEST_MODE=1`) allows testing without affecting the real system.

New commands can be added by:
1. Adding a command handler in `niuv.nim`
2. Implementing the command logic in an appropriate module
3. Updating the help documentation

### Alternative Package Sources

The package installation system is designed to support different sources:
- Nimble packages (default)
- Git repositories
- Local directories
- Custom sources through a plugin system

### Shell Integration

The shell integration system supports multiple shells:
- Bash
- Zsh
- PowerShell
- CMD
- Custom shells through shell-specific script generation

## Testing Strategy

Niuv includes several types of tests:

1. **Unit Tests**: Test individual functions in isolation
2. **Integration Tests**: Test interactions between modules
3. **End-to-End Tests**: Test the complete flow from command input to execution
4. **Regression Tests**: Ensure fixed bugs don't reappear

A special test mode (`NIUV_TEST_MODE=1`) allows testing without affecting the real system.
EOF < /dev/null