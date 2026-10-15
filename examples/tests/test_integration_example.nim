import std/unittest

## test_integration_example.nim
## ============================
##
## Example of using niuv with nim-testkit integration
##

import std/[os, strformat]

# This example demonstrates how to use niuv's integrated testing features

echo "=== Niuv Test Integration Example ==="
echo ""

# 1. Run tests with the default niuv backend
echo "1. Running tests with niuv backend:"
echo "   $ niuv test"
echo "   This uses the traditional niuv test runner"
echo ""

# 2. Run tests with nim-testkit backend
echo "2. Running tests with nim-testkit backend:"
echo "   $ nim c -d:niuvTestKit niuv"
echo "   $ niuv test --backend=testkit"
echo "   This uses nim-testkit's advanced features"
echo ""

# 3. Analyze test structure
echo "3. Analyzing test structure with MECE principles:"
echo "   $ niuv test-analyze"
echo "   This checks if your tests are:"
echo "   - Mutually Exclusive (no overlaps)"
echo "   - Collectively Exhaustive (no gaps)"
echo ""

# 4. Generate test files
echo "4. Generating test files:"
echo "   $ niuv test-generate unit --name=test_my_module"
echo "   $ niuv test-generate integration --name=test_api_integration"
echo "   $ niuv test-generate system --name=test_full_system"
echo ""

# 5. Advanced test running options
echo "5. Advanced test running options:"
echo "   $ niuv test --pattern=\"test_*.nim\" --fail-fast"
echo "   $ niuv test --backend=testkit --output-dir=reports"
echo "   $ niuv test test_specific.nim --no-report"
echo ""

# Example configuration in niuv.toml
let exampleConfig = """
[tool.niuv.testing]
backend = "testkit"  # or "niuv"
output_dir = "build/test_reports"
generate_report = true

[tool.niuv.testing.categories]
enabled = ["unit", "integration", "system"]
custom = ["performance", "security"]

[tool.niuv.testing.mece]
enabled = true
strict = false
"""

echo "6. Example niuv.toml configuration:"
echo exampleConfig
echo ""

# Demonstration of test structure
echo "7. Recommended test structure:"
echo "   tests/"
echo "   ├── unit/"
echo "   │   ├── test_config.nim"
echo "   │   └── test_utils.nim"
echo "   ├── integration/"
echo "   │   ├── test_api.nim"
echo "   │   └── test_database.nim"
echo "   └── system/"
echo "       ├── test_full_workflow.nim"
echo "       └── test_performance.nim"
echo ""

# Show current test backend availability
when defined(niuvTestKit):
  echo "✓ nim-testkit integration is available"
  echo "  You can use all advanced features!"
else:
  echo "✗ nim-testkit integration is not available"
  echo "  Compile with -d:niuvTestKit to enable"

echo ""
echo "=== End of Example ===
suite "integration_example Tests":
  test "Basic test":
    check true
