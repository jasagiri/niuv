# Vendor Packages

Niuv includes several vendor packages that are maintained as part of the project. These packages are included in the `vendor/` directory and are designed to be used by Niuv's test suite and can also be utilized in your projects.

## Overview

The vendor packages are structured as standalone Nim packages but are included directly in the Niuv repository for ease of maintenance and to ensure compatibility. Each package has its own directory structure, nimble file, and can be used either directly from the vendor directory or installed as a separate package.

Current vendor packages:
- **power_assert_nim**: Enhanced assertion library for testing
- **cucumber_nim**: BDD testing framework for Nim

## power_assert_nim

### Overview

Power Assert is a powerful assertion library that generates detailed and visual error messages when assertions fail. Unlike standard assertions that only show that a condition failed, Power Assert shows the values of all expressions involved in the condition, making it much easier to diagnose test failures.

### Structure

```
vendor/power_assert_nim/
├── power_assert_nim.nimble  # Package definition
├── README.md                # Package documentation
├── src/
│   ├── power_assert.nim     # Core implementation
│   └── power_assert_nim.nim # Package module (re-exports)
└── tests/                   # Tests for the package
```

### Key Features

- **Detailed Assertion Messages**: Shows the exact values that caused an assertion to fail
- **Expression Visualization**: Provides a visual representation of the expression evaluation
- **Type Support**: Works with various Nim types including primitives, sequences, and custom types
- **unittest Integration**: Seamlessly integrates with Nim's standard unittest module

### Usage

In your test files, import the power_assert_nim module and use the powerAssert macro:

```nim
import power_assert_nim

test "example test":
  let x = 10
  let y = 20
  let z = x + 5
  
  # This will show a detailed error message with all values
  powerAssert x + y == z * 2
```

When this assertion fails, instead of a simple "assertion failed" message, you'll get detailed output like:

```
Assertion failed:
  x + y == z * 2
  | | | |  | |
  | | | |  | 30
  | | | |  15
  | | | false
  | | 20
  | 30
  10
```

This makes it much easier to identify what went wrong and why.

### Configuration

Power Assert can be configured with compiler flags:

- `-d:powerAssertMaxDepth=N`: Set the maximum depth for capturing nested expressions (default: 10)
- `-d:powerAssertIndent="string"`: Customize the indentation (default: "  ")

### Integration with Niuv

Power Assert is used in Niuv's test suite for improved test diagnostics. It's already integrated and available for all tests in the project.

## cucumber_nim

### Overview

Cucumber_nim is a Behavior-Driven Development (BDD) framework for Nim that allows writing tests in natural language using Gherkin syntax. It follows the Cucumber pattern, where features are described in plain text and implemented with step definitions in Nim code.

### Structure

```
vendor/cucumber_nim/
├── cucumber_nim.nimble   # Package definition
├── README.md             # Package documentation
├── src/
│   ├── cucumber_nim.nim  # Package module
│   ├── gherkin/          # Gherkin parser implementation
│   ├── runner/           # Test runner implementation
│   └── formatter/        # Output formatters
└── tests/                # Tests for the package
```

### Key Features

- **Gherkin Syntax**: Supports Gherkin's Given/When/Then syntax for describing tests
- **Step Definition**: Connect Gherkin steps to Nim code with regex pattern matching
- **Scenario Outlines**: Support for parameterized tests
- **Tags**: Filter tests with tags to run specific subsets
- **Hooks**: Before/After hooks for setup and teardown
- **Parallel Execution**: Run scenarios in parallel for faster execution
- **Test Retries**: Automatically retry failed tests
- **Rich Reporting**: Multiple output formats including progress, HTML, and JSON

### Usage

1. Create a feature file with Gherkin syntax:

```gherkin
# features/calculator.feature
Feature: Calculator
  In order to perform basic arithmetic
  As a calculator user
  I want to be able to perform operations

  Scenario: Addition
    Given I have entered 5 into the calculator
    And I have entered 7 into the calculator
    When I press add
    Then the result should be 12
```

2. Implement step definitions:

```nim
# steps/calculator_steps.nim
import cucumber_nim

var calculator = new(Calculator)

Given "I have entered {int} into the calculator":
  let number = parseInt(matches[0])
  calculator.enter(number)

When "I press add":
  calculator.add()

Then "the result should be {int}":
  let expected = parseInt(matches[0])
  check calculator.result == expected
```

3. Create a runner:

```nim
# run_features.nim
import cucumber_nim
import steps/calculator_steps

when isMainModule:
  let exitCode = cucumber_runner.run()
  quit(exitCode)
```

### Command-Line Options

When running feature tests, you can use various command-line options:

- `-v` or `--verbosity`: Set verbosity level (0-5)
- `-t` or `--tags`: Run only scenarios with matching tags
- `-p` or `--parallel`: Run scenarios in parallel
- `-f` or `--format`: Set output format (progress, html, json)
- `-o` or `--output`: Set output file for reports

### Integration with Niuv

Cucumber_nim is used for all of Niuv's BDD-style feature tests. The integration is set up as follows:

1. Feature files are in `tests/specs/`
2. Step definitions are in `tests/steps/`
3. The main runner is in `src/tools/test/feature_runner.nim`
4. Convenience scripts are in `scripts/features/`

To run feature tests in Niuv:

```bash
nimble features         # Run all feature tests
nimble featureOne env   # Run just the env.feature test
```

## Using Vendor Packages in Your Project

While these packages are primarily intended for use within Niuv, you can also use them in your own projects:

### Method 1: Direct Usage

1. Clone the Niuv repository
2. Add the vendor directory to your Nimble path or directly import from the path:

```nim
import "/path/to/niuv/vendor/power_assert_nim/src/power_assert_nim"
import "/path/to/niuv/vendor/cucumber_nim/src/cucumber_nim"
```

### Method 2: Local Package

1. Copy the vendor package to your project's vendor directory
2. Include the nimble file in your project's nimble file:

```nim
# yourproject.nimble
include "vendor/power_assert_nim/power_assert_nim.nimble"
include "vendor/cucumber_nim/cucumber_nim.nimble"
```

3. Import the package in your code:

```nim
import vendor/power_assert_nim/src/power_assert_nim
import vendor/cucumber_nim/src/cucumber_nim
```

### Method 3: As a Dependency

In the future, these packages may be published to the Nimble package repository, at which point you could install them directly:

```bash
nimble install power_assert_nim
nimble install cucumber_nim
```

## Maintaining Vendor Packages

If you need to update or modify the vendor packages:

1. Make changes in the appropriate vendor directory
2. Add tests to verify your changes
3. Run the package-specific tests
4. Update the package version in the nimble file
5. Document your changes

Remember that these packages are part of the Niuv project, so changes should be compatible with Niuv's requirements and coding standards.