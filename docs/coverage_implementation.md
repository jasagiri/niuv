# Coverage Implementation Guide

## Overview

The niuv coverage implementation provides comprehensive code coverage analysis for Nim projects, following MECE (Mutually Exclusive, Collectively Exhaustive) principles and integrating with nim-lang-core patterns.

## Architecture

### Core Components

1. **Coverage Module (`src/coverage.nim`)**
   - Main coverage functionality
   - Data collection and processing
   - Report generation in multiple formats
   - Threshold checking

2. **Test Coverage Module (`src/test_coverage.nim`)**
   - Integration with test framework
   - Test runner with coverage support
   - Export to external formats (Cobertura, SonarQube)

3. **Configuration (`src/config.nim`)**
   - Coverage-specific configuration options
   - Integration with niuv's existing config system

## Usage

### Basic Coverage Run

```bash
# Run all tests with coverage
niuv coverage

# Run specific test files
niuv coverage tests/test_config.nim tests/test_deps.nim

# Set coverage threshold
niuv coverage --threshold=90.0

# Generate specific formats
niuv coverage --format=lcov,html,json,text

# Export to external tools
niuv coverage --export=cobertura
niuv coverage --export=sonarqube
```

### Configuration

Add to your `niuv.toml`:

```toml
[tool.niuv]
coverageEnabled = true
coverageThreshold = 80.0
coverageFormats = "html,json"
coverageOutputDir = "coverage"
```

### Coverage Reports

Reports are generated in the `coverage/` directory:

- `index.html` - Interactive HTML report
- `coverage.json` - Machine-readable JSON data
- `coverage.info` - LCOV format for CI tools
- `coverage.txt` - Plain text summary

## Implementation Details

### Data Collection

1. **Compiler Instrumentation**
   - Uses GCC/Clang coverage flags: `-fprofile-arcs -ftest-coverage`
   - Generates `.gcno` (compile-time) and `.gcda` (runtime) files
   - Supports `--sourcemap` and `--lineDir:on` for source mapping

2. **Source Mapping**
   - Maps C-generated coverage back to Nim source
   - Uses `#line` directives in generated C code
   - Filters out non-project files

### Report Generation

1. **LCOV Format**
   - Industry-standard format
   - Compatible with genhtml, codecov.io, etc.
   - Line coverage data with hit counts

2. **HTML Format**
   - Modern, responsive design
   - Visual coverage indicators
   - File-by-file breakdown
   - Coverage trends

3. **JSON Format**
   - Complete coverage data
   - Suitable for custom tooling
   - Includes metadata and timestamps

4. **Text Format**
   - Simple summary output
   - Suitable for CI logs
   - Quick overview

### External Tool Integration

1. **Cobertura XML**
   - Compatible with Jenkins, GitLab CI
   - Package and class-level coverage
   - Line-by-line hit data

2. **SonarQube Generic Format**
   - JSON-based format
   - Path-relative coverage data
   - Boolean coverage per line

## MECE Analysis Application

The implementation follows MECE principles:

### Mutually Exclusive Categories

1. **Data Collection**
   - Source-level vs Binary-level
   - Compile-time vs Runtime

2. **Data Processing**
   - Raw data vs Aggregated data
   - Per-file vs Per-module vs Global

3. **Data Presentation**
   - Format types (LCOV, HTML, JSON, Text)
   - Visualization types (Summary, Details, Trends)

### Collectively Exhaustive Coverage

- All Nim source files in project
- All test execution paths
- All output format requirements
- All integration points (CI/CD, IDE, badges)

## Integration with nim-lang-core

The implementation aligns with nim-lang-core patterns:

1. **Error Handling**
   - Uses Result[T, E] pattern
   - Dedicated error types
   - Graceful degradation

2. **Configuration**
   - Follows niuv's config system
   - Environment variable support
   - Cascading precedence

3. **Logging**
   - Consistent with niuv's logging
   - Styled output via CLI module
   - Verbose mode support

## Future Enhancements

1. **Native Nim Coverage**
   - Direct AST instrumentation
   - No C-level mapping needed
   - Better accuracy

2. **Incremental Coverage**
   - Track coverage changes
   - PR-specific coverage
   - Performance optimization

3. **Advanced Metrics**
   - Branch coverage
   - Function coverage
   - Cyclomatic complexity

4. **IDE Integration**
   - VSCode extension support
   - IntelliJ plugin
   - Real-time coverage display