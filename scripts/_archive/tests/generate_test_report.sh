#!/bin/sh
# Generate test reports from test output

# Default values
TEST_OUTPUT_FILE="build/test_output.log"
JSON_REPORT_FILE="build/reports/test_report.json"
HTML_REPORT_FILE="build/reports/test_report.html"
VERBOSE=""

# Handle options
while [ $# -gt 0 ]; do
  case "$1" in
    --output=*) 
      TEST_OUTPUT_FILE="${1#*=}"
      ;;
    --json=*) 
      JSON_REPORT_FILE="${1#*=}"
      ;;
    --html=*) 
      HTML_REPORT_FILE="${1#*=}"
      ;;
    --verbose)
      VERBOSE="--verbose"
      ;;
    --help)
      echo "Usage: generate_test_report.sh [options]"
      echo "Options:"
      echo "  --output=<file>       Test output file (default: build/test_output.log)"
      echo "  --json=<file>         JSON report output file (default: build/reports/test_report.json)"
      echo "  --html=<file>         HTML report output file (default: build/reports/test_report.html)"
      echo "  --verbose             Enable verbose output"
      echo "  --help                Show this help message"
      exit 0
      ;;
    *)
      # Positional arguments handling
      if [ -z "$TEST_OUTPUT_FILE" ]; then
        TEST_OUTPUT_FILE="$1"
      elif [ -z "$JSON_REPORT_FILE" ]; then
        JSON_REPORT_FILE="$1"
      elif [ -z "$HTML_REPORT_FILE" ]; then
        HTML_REPORT_FILE="$1"
      fi
      ;;
  esac
  shift
done

# Ensure reports directory exists
mkdir -p "$(dirname "$JSON_REPORT_FILE")"
mkdir -p "$(dirname "$HTML_REPORT_FILE")"

# Run test report generator
echo "Generating test reports from $TEST_OUTPUT_FILE"
nim c -r src/tools/report/test_report.nim "$TEST_OUTPUT_FILE" --json="$JSON_REPORT_FILE" --html="$HTML_REPORT_FILE" $VERBOSE

# Exit with the exit code of the test report generator
exit $?