#!/bin/bash
# Test coverage script for niuv

set -e

# Get the project root directory
PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TESTS_DIR="${PROJECT_ROOT}/tests"
BUILD_DIR="${PROJECT_ROOT}/build/tests"
COVERAGE_DIR="${PROJECT_ROOT}/coverage"

# Create directories if they don't exist
mkdir -p "${BUILD_DIR}"
mkdir -p "${COVERAGE_DIR}"

echo "Running niuv test coverage..."

# Clean old coverage data
find "${PROJECT_ROOT}" -name "*.gcda" -delete 2>/dev/null || true
find "${PROJECT_ROOT}" -name "*.gcno" -delete 2>/dev/null || true
rm -rf "${COVERAGE_DIR}"/*

# Define test files to run
TEST_FILES=(
  "test_config"
  "test_deps"
  "test_fs_utils"
  "test_parallel"
  "test_resolver"
  "test_workspace"
  "test_workspace_simple"
  "test_workspace_coverage"
  "test_workspace_extended"
)

# Run tests with coverage instrumentation
for test_file in "${TEST_FILES[@]}"; do
  echo "Running ${test_file}..."
  if [ -f "${TESTS_DIR}/${test_file}.nim" ]; then
    nim c --sourcemap \
          --lineDir:on \
          --passC:"-fprofile-arcs -ftest-coverage" \
          --passL:"-fprofile-arcs -ftest-coverage" \
          --nimcache:"${PROJECT_ROOT}/nimcache" \
          -o:"${BUILD_DIR}/${test_file}" \
          "${TESTS_DIR}/${test_file}.nim"
    
    # Run the test
    "${BUILD_DIR}/${test_file}" || echo "Test ${test_file} failed, continuing..."
  fi
done

# Generate coverage info
echo "Generating coverage report..."
if command -v lcov >/dev/null 2>&1; then
  lcov --capture --directory "${PROJECT_ROOT}" --output-file "${COVERAGE_DIR}/coverage.info" --ignore-errors gcov || true
  lcov --remove "${COVERAGE_DIR}/coverage.info" '/usr/*' --output-file "${COVERAGE_DIR}/coverage.info" --ignore-errors empty || true
  lcov --remove "${COVERAGE_DIR}/coverage.info" '*/nimcache/*' --output-file "${COVERAGE_DIR}/coverage.info" --ignore-errors empty || true
  lcov --remove "${COVERAGE_DIR}/coverage.info" '*.choosenim/*' --output-file "${COVERAGE_DIR}/coverage.info" --ignore-errors empty || true
  
  # Generate HTML report
  if command -v genhtml >/dev/null 2>&1; then
    genhtml "${COVERAGE_DIR}/coverage.info" --output-directory "${COVERAGE_DIR}" --ignore-errors empty || true
    echo "Coverage report generated at: ${COVERAGE_DIR}/index.html"
  else
    echo "genhtml not found. Install lcov to generate HTML reports."
  fi
else
  echo "lcov not found. Install lcov to generate coverage reports."
  echo "On Ubuntu/Debian: sudo apt-get install lcov"
  echo "On macOS: brew install lcov"
fi

echo "Coverage reporting completed."