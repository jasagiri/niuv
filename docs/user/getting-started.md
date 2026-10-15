# Getting Started with Niuv (Unified Enhanced Version)

This guide will walk you through the process of installing and using Niuv, the Nim Virtual Environment Manager. This documentation covers the **unified enhanced version** that includes global configuration support, enhanced testing capabilities, and tool delegation features.

## Installation

### Prerequisites

- Nim compiler (version 2.0.0 or higher)
- Git (for installation from source)

### Installation Methods

#### 1. From Source

```bash
# Clone the repository
git clone https://github.com/yourusername/niuv.git
cd niuv

# Build the unified enhanced version
nim c -d:release -o:build/bin/niuv src/niuv.nim

# Optional: Install globally
# Linux/macOS
sudo cp build/bin/niuv /usr/local/bin/
# Windows
copy build\bin\niuv.exe C:\Windows\
```

#### 2. Via Nimble (Once Published)

```bash
nimble install niuv
```

## Creating Your First Environment

### Initializing a New Environment

1. Create a project directory
```bash
mkdir my_project
cd my_project
```

2. Initialize the environment
```bash
niuv init
```

3. Set up global configuration (recommended for enhanced features)
```bash
niuv setup-config
```

This will create the necessary files and directories for a Nim virtual environment:
- `nimbledeps/` - Directory for dependencies
- `nim.cfg` - Nim configuration file
- `activate` - Activation script
- `.niuv.json` - Niuv configuration file

### Specifying a Nim Version

You can specify a Nim version when initializing:

```bash
niuv init --nim-version=2.0.0
```

## Managing Packages

### Creating a Nimble File

First, create a basic `.nimble` file:

```bash
echo '# Package
version       = "0.1.0"
author        = "Your Name"
description   = "Your project description"
license       = "MIT"

# Dependencies
requires "nim >= 2.0.0"
' > my_project.nimble
```

### Adding Packages

Add packages to your dependencies:

```bash
# Basic usage
niuv add packagename

# With version constraint
niuv add packagename >=1.0.0

# Add as development dependency
niuv add packagename --dev
```

### Installing Packages

Install all packages defined in your `.nimble` file:

```bash
# Basic installation
niuv install

# Install with parallel jobs
niuv install --parallel=4

# Include development dependencies
niuv install --dev
```

### Removing Packages

Remove packages from your dependencies:

```bash
niuv remove packagename
```

## Using the Environment

### Activating the Environment

```bash
# Unix-like systems
source ./activate

# Windows
.\activate.bat

# If shell integration is enabled
niuv activate
```

### Running Commands in the Environment

Run commands directly in the environment without activation:

```bash
niuv run nim c myfile.nim
```

### Shell Integration

For easier activation, set up shell integration:

```bash
niuv setup
```

This will add a function to your shell configuration that allows you to simply type `niuv activate` to activate the environment.

### Environment Information

View information about the current environment:

```bash
niuv info
```

## Advanced Usage

### Lockfiles

Niuv generates lockfiles to ensure reproducible builds. You can synchronize your packages with the lockfile:

```bash
niuv sync
```

### Configuration

The unified version supports both project and global configuration:

#### Project Configuration (niuv.toml)
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
backend = "niuv"  # or "testkit"

[tool.niuv.delegation]
test = "testkit"  # Delegate testing to nim-testkit
```

#### Global Configuration (~/.config/niuv/config.ini)
```bash
# Create default global configuration
niuv setup-config

# View current configuration
niuv show-config

# Validate configuration
niuv validate-config
```

Default global configuration includes:
```ini
[coverage]
enabled=true
threshold=80.0
format=html

[performance]
parallel=true
max_jobs=4
```

## Troubleshooting

### Common Issues

1. **Environment not activating properly**

   Check that the activation script was created correctly and has executable permissions:
   ```bash
   chmod +x activate  # On Unix-like systems
   ```

2. **Package installation failures**

   Use verbose mode to see more details:
   ```bash
   niuv install --verbose
   ```

3. **Path issues**

   Ensure that the environment directories are properly set in your PATH:
   ```bash
   echo $PATH  # Check your PATH
   ```

### Getting Help

For more information on available commands:

```bash
niuv help
```

## Development and Testing

### Running Tests

```bash
# Run comprehensive test suite (recommended)
niuv test-all  # Runs Hourai W9P2025 test suite

# Note: 'niuv test' has a known infinite loop issue
# Always use test-all instead

# Run tests with nimble (alternative)
nimble test

# Run a specific test
nimble testOne tests/test_env.nim

# Test binaries will be placed in build/tests/ directory
```

### Building Without Running

```bash
# Build all tests
nimble buildAllTests

# Build a specific test
nimble buildTest tests/test_config.nim
```

### Cleaning Up

```bash
# Clean all build artifacts
nimble clean

# Remove unnecessary files
nimble cleanup
```

## Enhanced Features

The unified version includes several enhanced capabilities:

### Additional Commands
```bash
# Check for updates
niuv check-updates

# Generate project scaffolding
niuv generate my-project

# Show enhanced version info
niuv version
```

### Known Issues

1. **Test command**: Use `niuv test-all` instead of `niuv test` (infinite loop issue)
2. **Coverage reports**: HTML output will be empty due to Nim compilation limitations

## Next Steps

- Read the [Unified Implementation Guide](/docs/UNIFIED_IMPLEMENTATION.md) for details on the enhanced version
- Explore the [Testing Guide](/docs/user/testing-guide.md) for comprehensive testing features
- Check the [API Reference](/docs/api_reference.md) for detailed function documentation
- Review the [Architecture Overview](/docs/architecture.md) to understand how Niuv works
- Visit the project repository for the latest updates and to report issues