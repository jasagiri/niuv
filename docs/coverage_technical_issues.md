# Coverage Technical Issues and Solutions

## Overview

This document describes the technical challenges with implementing code coverage for Nim projects and the solutions implemented in niuv.

## Technical Problems

### 1. Nim's Compilation Model
- **Problem**: Nim compiles to C/C++, making source-level coverage difficult
- **Impact**: Coverage tools (gcov, lcov) report coverage for generated C code, not original Nim source
- **Solution**: Use Nim's `--lineDir:on` and `--sourcemap` options to maintain source mapping

### 2. Source Mapping Limitations
- **Problem**: Generated C code doesn't have 1:1 mapping with Nim source
- **Impact**: 
  - Macros and templates expand to multiple C lines
  - Inlined functions may not appear in coverage
  - Generic instantiations create duplicate coverage entries
- **Partial Solution**: Parse gcov output and map back to Nim files using line directives

### 3. Coverage Data Collection
- **Problem**: gcov generates coverage data in various locations
- **Impact**: Difficult to aggregate coverage across multiple test runs
- **Solution**: 
  - Set `GCOV_PREFIX` environment variable to control output location
  - Walk nimcache directory to find all .gcno/.gcda files
  - Filter to only include project source files

### 4. File Filtering Issues
- **Problem**: Coverage analysis includes system libraries and generated files
- **Current Issue**: Reports show 1349 files analyzed instead of just project files
- **Attempted Solution**: Filter by file path to only include src/ and tests/ directories
- **Status**: Filtering logic implemented but needs refinement

### 5. Report Generation
- **Problem**: Coverage reports not being generated in expected location
- **Expected**: Reports should be in `coverage/` directory
- **Current Status**: Coverage data is collected but reports may not be written
- **Solution Needed**: Ensure directory creation and proper file writing

## Current Implementation

### Coverage Collection Flow
1. Compile tests with coverage flags: `--passC:"-fprofile-arcs -ftest-coverage"`
2. Run tests to generate .gcda files
3. Process with gcov to create .gcov files
4. Parse .gcov files to extract coverage data
5. Generate HTML/JSON/LCOV reports

### Usage
```bash
# Run all tests with coverage
niuv test coverage

# Run specific test with coverage
niuv test coverage tests/test_config.nim

# Export to specific format
niuv test coverage --export cobertura
```

## Known Limitations

1. **Incomplete Source Mapping**: Some Nim constructs may not map correctly to coverage data
2. **Performance Impact**: Coverage instrumentation slows down test execution
3. **Memory Usage**: Coverage data collection increases memory usage
4. **Platform Differences**: Coverage behavior may vary between OS platforms

## Future Improvements

1. **Better Filtering**: Improve file filtering to only show relevant project files
2. **Source Maps**: Implement proper source map support when available in Nim
3. **Incremental Coverage**: Support incremental coverage collection across multiple runs
4. **Coverage Targets**: Allow configuration of coverage targets per module
5. **Branch Coverage**: Add support for branch coverage analysis

## Configuration

Coverage can be configured in `niuv.toml`:

```toml
[tool.niuv.coverage]
enabled = true
outputDir = "coverage"
threshold = 80.0
formats = ["html", "json", "lcov"]
includePatterns = ["src/**/*.nim", "tests/**/*.nim"]
excludePatterns = ["**/vendor/**", "**/nimcache/**"]
```

## Troubleshooting

### Coverage shows 0%
- Ensure tests are compiled with coverage flags
- Check that .gcda files are being generated
- Verify gcov is installed and accessible

### Too many files in coverage
- Check file filtering configuration
- Ensure excludePatterns are correctly specified
- Verify project root detection is working

### Reports not generated
- Check write permissions for coverage directory
- Verify output directory exists or can be created
- Check for errors in report generation

## References

- [Nim Compiler User Guide - Debugging](https://nim-lang.org/docs/nimc.html#debugging)
- [GCC gcov Documentation](https://gcc.gnu.org/onlinedocs/gcc/Gcov.html)
- [LCOV Documentation](http://ltp.sourceforge.net/coverage/lcov.php)