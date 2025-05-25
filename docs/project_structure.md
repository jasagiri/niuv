# Project Structure

This document describes the organization of the Niuv project.

## Directory Structure

- **src/**: Source code for the Niuv application
  - Core implementation files
  - Module-specific code
  - Application logic
  - **tools/**: Specialized functionality implementations
    - **build/**: Build utilities
    - **clean/**: Cleanup utilities
    - **report/**: Report generation
    - **test/**: Test runners and utilities
  - **utils/**: Utility functions and helpers
    - **fs.nim**: File system utilities
    - **shell.nim**: Shell command utilities

- **tests/**: Test files
  - Unit tests for each module
  - Integration tests
  - Test utilities and helpers
  - **specs/**: Gherkin feature specifications for BDD tests
  - **steps/**: Step implementations for BDD features
  - **fixtures/**: Test fixtures and sample data

- **examples/**: Example projects and usage demonstrations
  - Sample configurations
  - Example scripts
  - Demo applications
  - Usage patterns and best practices

- **scripts/**: Utility scripts
  - **ci/**: Continuous integration scripts
  - **cleanup/**: Project cleanup and organization
  - **demo/**: Example demonstrations
  - **features/**: BDD feature test runners
  - **reports/**: Test report generators
  - **tests/**: Test execution scripts
  - Build, test, and development utilities

- **docs/**: Documentation
  - API reference
  - User guides
  - Architecture documentation
  - Implementation details

- **build/**: Build artifacts (created during build process)
  - **bin/**: Compiled binaries
  - **tests/**: Compiled test binaries
  - **nimcache/**: Cache for nim compiler
  - **docs/**: Generated documentation
  - **coverage/**: Test coverage reports
  - **test_output/**: Test execution output
  - **reports/**: Generated test and analysis reports

- **nimbledeps/**: Nim package dependencies
  - **pkgs/**: Installed Nim packages
  - **pkgcache/**: Package cache

- **vendor/**: Vendored dependencies (locally included packages)
  - **power_assert_nim/**: Enhanced assertion library for testing
    - **src/**: Power assert implementation
      - **power_assert.nim**: Core implementation
      - **power_assert_nim.nim**: Package module (re-exports)
    - **tests/**: Tests for the power assert library
    - **power_assert_nim.nimble**: Package definition
  - **cucumber_nim/**: BDD testing framework
    - **src/**: Cucumber implementation
      - **cucumber_nim.nim**: Package module
      - **gherkin/**: Gherkin parser
      - **runner/**: Test runner
      - **formatter/**: Output formatters
    - **tests/**: Tests for the cucumber library
    - **cucumber_nim.nimble**: Package definition

## Vendor Packages

Niuv includes several local vendor packages that are maintained as part of the project:

### power_assert_nim

A powerful assertion library that generates detailed and visual error messages to improve testing efficiency. It automatically captures expression details and visualizes evaluation processes.

Key features:
- Automatic value extraction from expressions
- Visual display of evaluation processes
- Support for various types
- Integration with Nim's unittest module

Usage in tests:
```nim
import power_assert_nim

test "some test":
  let x = 10
  let y = 20
  # This will show a detailed error message with values
  powerAssert x == y
```

### cucumber_nim

A Behavior-Driven Development (BDD) testing framework for Nim. It implements the Cucumber testing pattern, allowing developers to write tests in natural language using Gherkin syntax.

Key features:
- Gherkin syntax support (Given/When/Then)
- Step definition with regex matching
- Parallel test execution
- Detailed reporting
- Test retry mechanism

Usage:
```nim
# In a .feature file
Feature: Calculator
  Scenario: Addition
    Given I have entered 5 into the calculator
    And I have entered 7 into the calculator
    When I press add
    Then the result should be 12

# In a step definition file
import cucumber_nim

var calculator: Calculator

Given "I have entered {int} into the calculator":
  let number = parseInt(matches[0])
  calculator.enter(number)

When "I press add":
  calculator.add()

Then "the result should be {int}":
  let expected = parseInt(matches[0])
  check calculator.result == expected
```

Both packages are integrated with Niuv's build system and can be used directly in your tests.

## Build System

The project uses Nimble for building and package management. The following tasks are available:

- `nimble build`: Build the application
- `nimble test`: Run all tests
- `nimble testOne <testfile>`: Run a specific test file
- `nimble buildTest <testfile>`: Build a test without running it
- `nimble buildAllTests`: Build all tests without running them
- `nimble clean`: Clean all build artifacts
- `nimble cleanup`: Remove unnecessary files
- `nimble features`: Run all BDD feature tests
- `nimble featureOne <feature>`: Run a specific feature test
- `nimble featureReport <format> <output>`: Generate a feature test report

## Test Organization

Tests are organized in the `tests/` directory with the following convention:

- Unit tests follow the pattern `test_<module>.nim`
- Each module in the `src/` directory should have a corresponding test file
- BDD tests use a combination of `specs/*.feature` files and `steps/*_steps.nim` implementations
- `testutils.nim` contains common test utilities
- Test binaries are output to the `build/tests/` directory

## Feature Tests (BDD)

Niuv uses Behavior-Driven Development with Gherkin syntax for feature testing. The cucumber_nim framework supports this approach with:

- Feature files in `tests/specs/` describing behaviors in natural language
- Step implementations in `tests/steps/` connecting the descriptions to actual code
- Execution through the `feature_runner.nim` in `src/tools/test/`
- Shell scripts in `scripts/features/` for convenient execution
- Report generation in `scripts/reports/` for visual output

## Development Guidelines

1. Keep related functionality in appropriate modules
2. Place all build artifacts in the `build/` directory
3. Use the `scripts/` directory for development utilities
4. Document new features in the `docs/` directory
5. Add examples for new features to the `examples/` directory
6. Run tests before submitting changes
7. Use the vendored packages for testing rather than implementing custom solutions
8. When adding new dependencies, consider whether they should be vendored or installed

## Build Output Management

- All compiled binaries go to `build/bin/`
- All test binaries go to `build/tests/`
- All nimcache files go to `build/nimcache/`
- All test reports go to `build/reports/`
- All test outputs go to `build/test_output/`
- The `nimble clean` task will remove all build artifacts