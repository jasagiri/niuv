# Niuv Testing Guide (Unified Enhanced Version)

## Overview

The unified enhanced version of Niuv provides comprehensive testing support through two backends:
1. **Niuv Backend** - The original test runner with Japanese language support and power assertions
2. **Nim-TestKit Backend** - Advanced features including MECE analysis and test generation

**Important**: The standard `niuv test` command has a known infinite loop issue. Always use `niuv test-all` for running tests.

## Quick Start

### Running Tests

```bash
# Run comprehensive test suite (RECOMMENDED)
niuv test-all  # Runs Hourai W9P2025 test suite

# WARNING: Do not use 'niuv test' - it has an infinite loop issue
# niuv test  # ❌ BROKEN - infinite loop

# Run specific test file with nimble
nimble test test_config.nim

# Use nim-testkit backend (requires compilation with -d:niuvTestKit)
# First compile with testkit support:
nim c -d:release -d:niuvTestKit -o:~/.local/bin/niuv src/niuv.nim
# Then use testkit features:
niuv test-all --backend=testkit
```

### Test Analysis

```bash
# Analyze test structure for MECE compliance
niuv test-analyze

# This will report:
# - Missing test categories
# - Overlapping test coverage
# - Suggestions for better organization
```

### Test Generation

```bash
# Generate unit test
niuv test-generate unit --name=test_my_module

# Generate integration test
niuv test-generate integration --name=test_api

# Generate system test
niuv test-generate system --name=test_workflow
```

## Configuration

Configure testing in your `niuv.toml`:

```toml
[tool.niuv.testing]
backend = "niuv"  # or "testkit"
output_dir = "build/test_output"
generate_report = true
pattern = "test_*.nim"
fail_fast = false

# For testkit backend
[tool.niuv.testing.categories]
enabled = ["unit", "integration", "system"]
custom = ["performance", "security"]

[tool.niuv.testing.mece]
enabled = true
strict = false
```

## Test Backends Comparison

### Niuv Backend

**Pros:**
- Japanese language support in output
- Power assertions for better error messages
- BDD/Cucumber support
- Lightweight and fast
- No additional dependencies

**Cons:**
- Limited output formats
- No test categorization
- No MECE analysis
- No test generation

**Use when:**
- You need Japanese output
- You want BDD-style tests
- You prefer simplicity
- You don't need advanced analysis

### Nim-TestKit Backend

**Pros:**
- Multiple output formats (JSON, XML, TAP, JUnit)
- Test categorization (unit, integration, system, etc.)
- MECE analysis for test structure
- Test file generation from templates
- VCS integration support
- Zero external dependencies

**Cons:**
- No Japanese language support
- No power assertions
- No BDD support
- Requires compilation with -d:niuvTestKit

**Use when:**
- You need CI/CD integration
- You want structured test organization
- You need test coverage analysis
- You want to generate test boilerplate

## MECE Test Organization

MECE (Mutually Exclusive, Collectively Exhaustive) principles help ensure comprehensive test coverage:

### Recommended Structure

```
tests/
├── unit/                 # Test individual functions/modules
│   ├── test_config.nim
│   ├── test_utils.nim
│   └── test_parser.nim
├── integration/          # Test component interactions
│   ├── test_api.nim
│   ├── test_database.nim
│   └── test_workflow.nim
├── system/              # Test complete system behavior
│   ├── test_installation.nim
│   ├── test_full_workflow.nim
│   └── test_error_recovery.nim
└── performance/         # Optional: Performance tests
    ├── test_throughput.nim
    └── test_memory_usage.nim
```

### MECE Analysis

Run `niuv test-analyze` to check:

1. **Mutually Exclusive**: No test overlaps between categories
2. **Collectively Exhaustive**: All code paths have tests

Example output:
```
=== MECE Test Structure Analysis ===
✓ Test structure is MECE compliant

Statistics:
  Total files: 12
  Categorized: 12
  Uncategorized: 0

Files per category:
  unit: 5
  integration: 4
  system: 3
```

## Writing Tests

### Niuv Backend Style

```nim
import ../src/test_framework

runTestsWithStatistics:
  suite "Configuration Tests":
    test "Load default config":
      check(config.nimVersion == "")
      check(config.parallelJobs == 4)
    
    test "Parse TOML config":
      let result = parseConfig("niuv.toml")
      require(result.isOk)
      check(result.get().nimVersion == "2.0.0")
```

### Nim-TestKit Style

```nim
import nimtestkit

suite "Configuration Tests":
  test "Load default config":
    check config.nimVersion == ""
    check config.parallelJobs == 4
  
  test "Parse TOML config":
    let result = parseConfig("niuv.toml")
    check result.isOk
    check result.get().nimVersion == "2.0.0"
```

## Command Line Options

### niuv test

```bash
niuv test [options] [files...]

Options:
  --backend=<backend>    Test backend (niuv, testkit)
  --pattern=<pattern>    File pattern to match
  --fail-fast           Stop on first failure
  --output-dir=<dir>    Output directory
  --no-report          Don't generate reports
  -v, --verbose        Verbose output
```

### niuv test-analyze

```bash
niuv test-analyze

# Analyzes test structure and reports:
# - MECE compliance
# - Missing categories
# - Overlapping tests
# - Improvement suggestions
```

### niuv test-generate

```bash
niuv test-generate <type> [options]

Types:
  unit          Generate unit test
  integration   Generate integration test
  system        Generate system test

Options:
  --name=<name>    Test file name
  --output=<dir>   Output directory
```

## Integration with CI/CD

### GitHub Actions

```yaml
- name: Run tests with JUnit output
  run: |
    nim c -d:niuvTestKit src/niuv.nim
    ./niuv test --backend=testkit --output-dir=test-results
    
- name: Upload test results
  uses: actions/upload-artifact@v2
  with:
    name: test-results
    path: test-results/
```

### GitLab CI

```yaml
test:
  script:
    - nim c -d:niuvTestKit src/niuv.nim
    - ./niuv test --backend=testkit
  artifacts:
    reports:
      junit: build/test_output/*.xml
```

## Migration Guide

### From Pure Niuv to TestKit

1. Keep existing tests as-is
2. Enable testkit: `nim c -d:niuvTestKit src/niuv.nim`
3. Run with testkit backend: `niuv test --backend=testkit`
4. Gradually adopt features:
   - Add test categories
   - Use MECE analysis
   - Generate new tests with templates

### From Other Test Frameworks

1. Use test generation for new tests
2. Gradually migrate existing tests
3. Use MECE analysis to find gaps
4. Keep both frameworks during transition

## Best Practices

1. **Choose the right backend** for your needs
2. **Organize tests by category** (unit/integration/system)
3. **Run MECE analysis** regularly
4. **Use test generation** for consistency
5. **Configure in niuv.toml** for team consistency
6. **Use appropriate output formats** for CI/CD
7. **Keep tests focused** and independent

## Troubleshooting

### TestKit backend not available

```
Error: TestKit backend is not available. Compile with -d:niuvTestKit
```

Solution:
```bash
nim c -d:niuvTestKit src/niuv.nim
```

### MECE violations

```
✗ Test structure has MECE violations
Violations:
  - Overlapping coverage in test_api.nim and test_integration.nim
```

Solution:
- Review overlapping tests
- Move to appropriate categories
- Ensure clear boundaries between test types

### Test generation fails

```
Error: Failed to generate test
```

Solution:
- Check output directory exists
- Ensure valid test type (unit/integration/system)
- Check file permissions