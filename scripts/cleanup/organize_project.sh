#!/bin/bash
set -e

echo "Organizing directory structure according to README.md..."

# Create all required directories
echo "Creating directory structure..."
mkdir -p build/bin build/tests build/nimcache build/docs build/test_output
mkdir -p docs
mkdir -p examples
mkdir -p scripts/ci scripts/demo scripts/tests scripts/cleanup
mkdir -p src
mkdir -p tests/specs tests/fixtures tests/results
mkdir -p nimbledeps

# Moving build artifacts to build directory
echo "Moving build artifacts..."
# Move compiled binaries to build/bin
for bin in niuv cleanup install testenv; do
  # Check if binary exists in src directory
  if [ -f "src/$bin" ]; then
    echo "Moving src/$bin to build/bin/"
    mv "src/$bin" build/bin/
  fi
  
  # Check if binary exists in root directory
  if [ -f "$bin" ]; then
    echo "Moving $bin to build/bin/"
    mv "$bin" build/bin/
  fi
done

# Move nimcache to build/nimcache if it exists
if [ -d "nimcache" ]; then
  echo "Moving nimcache to build/nimcache"
  mv nimcache/* build/nimcache/ 2>/dev/null || true
  rm -rf nimcache
fi

# Organize scripts
echo "Organizing scripts..."
# Move scripts from root to scripts directory
for script in *.sh *.bat; do
  if [ -f "$script" ] && [[ "$script" != "cleanup_project.sh" && "$script" != "delete_unnecessary_files.sh" && "$script" != "organize_project.sh" ]]; then
    if [[ "$script" == *"test"* ]]; then
      # Test scripts go to scripts/tests
      if [ ! -f "scripts/tests/$script" ]; then
        echo "Moving $script to scripts/tests/"
        cp "$script" "scripts/tests/"
      fi
    elif [[ "$script" == *"ci"* ]]; then
      # CI scripts go to scripts/ci
      if [ ! -f "scripts/ci/$script" ]; then
        echo "Moving $script to scripts/ci/"
        cp "$script" "scripts/ci/"
      fi
    elif [[ "$script" == *"demo"* || "$script" == *"run"* ]]; then
      # Demo scripts go to scripts/demo
      if [ ! -f "scripts/demo/$script" ]; then
        echo "Moving $script to scripts/demo/"
        cp "$script" "scripts/demo/"
      fi
    else
      # Other scripts go to scripts
      if [ ! -f "scripts/$script" ]; then
        echo "Moving $script to scripts/"
        cp "$script" "scripts/"
      fi
    fi
  fi
done

# Ensure all source code is properly located
echo "Checking source code location..."
# Create an example project structure markdown file if it doesn't exist
if [ ! -f "docs/project_structure.md" ]; then
  echo "Creating docs/project_structure.md..."
  cat > docs/project_structure.md << EOL
# Niuv Project Structure

This document describes the organization of the Niuv project codebase.

## Directory Structure

\`\`\`
├── build/                # Build artifacts (created during build)
│   ├── bin/              # Compiled binaries
│   ├── tests/            # Compiled test binaries
│   ├── nimcache/         # Nim compiler cache files
│   └── docs/             # Generated documentation
├── docs/                 # Documentation
│   ├── api_reference.md  # API reference documentation
│   ├── architecture.md   # Architecture overview
│   ├── getting_started.md# Getting started guide
│   └── project_structure.md # Project organization details
├── examples/             # Example configurations and projects
│   ├── niuv.toml         # Example configuration file
│   ├── ci_script.sh      # Example CI script for Unix
│   ├── ci_script.bat     # Example CI script for Windows
│   ├── parallel_tasks.nim# Example of parallel task execution
│   ├── priority_tasks.nim# Example of task prioritization
│   ├── dependency_tasks.nim # Example of task dependencies
│   ├── circular_dependencies.nim # Example of dependency error handling
│   ├── progress_reporting.nim # Example of progress reporting
│   └── cancellation_demo.nim # Example of task cancellation features
├── scripts/              # Utility scripts
│   ├── ci/               # CI/CD scripts
│   ├── demo/             # Demo scripts
│   ├── tests/            # Test scripts
│   ├── compile_tests.sh  # Compile tests on Unix
│   ├── compile_tests.bat # Compile tests on Windows
│   ├── run_tests.sh      # Run tests on Unix
│   └── run_tests.bat     # Run tests on Windows
├── src/                  # Source code
│   ├── cli.nim           # Command-line interface
│   ├── config.nim        # Configuration management
│   ├── deps.nim          # Dependency management
│   ├── env.nim           # Environment management
│   ├── install.nim       # Package installation
│   ├── macros.nim        # Nim macros
│   ├── niuv.nim          # Main entry point
│   ├── parallel.nim      # Parallel execution
│   ├── regex_patterns.nim# Regex patterns for parsing
│   ├── testenv.nim       # Test environment setup
│   ├── utils.nim         # Utility functions
│   └── venv.nim          # Virtual environment
├── tests/                # Tests
│   ├── fixtures/         # Test fixtures
│   ├── results/          # Test results
│   ├── specs/            # Test specifications
│   ├── test_all.nim      # Run all tests
│   ├── test_config.nim   # Configuration tests
│   ├── test_deps.nim     # Dependency tests
│   ├── test_env.nim      # Environment tests
│   ├── test_install.nim  # Installation tests
│   ├── test_parallel.nim # Parallel execution tests
│   ├── test_progress.nim # Progress reporting tests
│   ├── test_retry.nim    # Retry behavior tests
│   ├── test_venv.nim     # Virtual environment tests
│   └── testutils.nim     # Test utilities
├── CLAUDE.md             # Guide for Claude Code
├── LICENSE               # MIT License
├── README.md             # Project overview and documentation
├── niuv.nimble           # Nimble package file
├── cleanup_project.sh    # Project cleanup script
├── delete_unnecessary_files.sh # File deletion script
└── organize_project.sh   # Directory structure organization script
\`\`\`

## Main Components

- **src/**: Contains all source code for the Niuv project
- **tests/**: Contains all test code and test fixtures
- **examples/**: Contains example code showing how to use Niuv
- **docs/**: Contains documentation for the project
- **scripts/**: Contains utility scripts for building, testing, etc.
- **build/**: Contains build artifacts (created during the build process)

## File Organization Principles

1. **Separation of concerns**: Each file has a single responsibility
2. **Logical grouping**: Files are grouped by functionality
3. **Testability**: Each component has corresponding tests
4. **Documentation**: Each component has corresponding documentation
5. **Examples**: Each major feature has example code demonstrating usage
EOL
fi

echo "Directory structure reorganization completed."
echo "Next steps:"
echo "1. Review changes"
echo "2. Run ./delete_unnecessary_files.sh to remove unnecessary files"
echo "3. Verify all functionality still works"