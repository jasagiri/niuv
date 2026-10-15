#!/usr/bin/env bash
# Hourai Coverage Script - Wrapper for running tests with coverage tracking
# Note: niuv doesn't have built-in coverage support, so we run tests and
# would need to use external tools like nim-cov for actual coverage metrics

set -euo pipefail

# Default options
THRESHOLD=80
FORMAT="html"
OPEN_REPORT=false
VERBOSE=false
OUTPUT_DIR=".coverage"

# Help function
show_help() {
    cat << EOF
Usage: $0 [options]

Run tests for Hourai project. 
Note: Actual code coverage metrics require external tools like nim-cov.
This script runs the test suite and provides basic reporting.

Options:
    -t, --threshold=N    Set coverage threshold (default: 80)
    -f, --format=FORMAT  Report format: html, json, text (default: html)
    -o, --output=DIR     Output directory (default: .coverage)
    --open              Open HTML report in browser after generation
    -v, --verbose       Verbose output
    -h, --help          Show this help

Examples:
    $0                      # Run coverage with defaults
    $0 -t 90 -f json       # 90% threshold, JSON format
    $0 --open              # Generate HTML and open in browser
    $0 -v                  # Verbose output
EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--threshold)
            THRESHOLD="$2"
            shift 2
            ;;
        --threshold=*)
            THRESHOLD="${1#*=}"
            shift
            ;;
        -f|--format)
            FORMAT="$2"
            shift 2
            ;;
        --format=*)
            FORMAT="${1#*=}"
            shift
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --output=*)
            OUTPUT_DIR="${1#*=}"
            shift
            ;;
        --open)
            OPEN_REPORT=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Ensure output directory exists
mkdir -p "$OUTPUT_DIR"

# Set environment variables for coverage
export TESTKIT_COVERAGE_ENABLED=1
export TESTKIT_COVERAGE_THRESHOLD=$THRESHOLD
export TESTKIT_COVERAGE_FORMAT=$FORMAT
export TESTKIT_COVERAGE_OUTPUT=".coverage"

# Run coverage
echo "🔍 Running code coverage analysis..."
echo "   Threshold: $THRESHOLD%"
echo "   Format: $FORMAT"
echo "   Output: $OUTPUT_DIR"

# Run tests using niuv (it should pick up the nimble test task)
# If that fails, fallback to specifying test files directly
if [[ "$VERBOSE" == "true" ]]; then
    niuv task test --verbose || niuv test tests/test_all.nim --verbose
else
    niuv task test || niuv test tests/test_all.nim
fi

# Check if coverage passed threshold
COVERAGE_FILE="$OUTPUT_DIR/coverage.json"
if [[ -f "$COVERAGE_FILE" && "$FORMAT" == "json" ]]; then
    # Extract coverage percentage from JSON (basic implementation)
    ACTUAL_COVERAGE=$(grep -o '"coverage": *[0-9.]*' "$COVERAGE_FILE" | grep -o '[0-9.]*' || echo "0")
    echo "📊 Coverage: ${ACTUAL_COVERAGE}%"
    
    if (( $(echo "$ACTUAL_COVERAGE < $THRESHOLD" | bc -l) )); then
        echo "❌ Coverage below threshold ($THRESHOLD%)"
        exit 1
    else
        echo "✅ Coverage meets threshold ($THRESHOLD%)"
    fi
fi

# Open HTML report if requested
if [[ "$OPEN_REPORT" == "true" && "$FORMAT" == "html" ]]; then
    HTML_FILE="$OUTPUT_DIR/index.html"
    if [[ -f "$HTML_FILE" ]]; then
        echo "🌐 Opening coverage report..."
        if command -v open >/dev/null 2>&1; then
            open "$HTML_FILE"
        elif command -v xdg-open >/dev/null 2>&1; then
            xdg-open "$HTML_FILE"
        else
            echo "   Report available at: $HTML_FILE"
        fi
    fi
fi

echo "✅ Coverage analysis complete"