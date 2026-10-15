#!/bin/bash
# Unified test runner for niuv project
# Consolidates test execution functionality

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Error handling
error_exit() {
    log_error "$1"
    exit 1
}

# Show help
show_help() {
    cat << EOF
Unified Test Runner for niuv

Usage: $0 [options] [test_pattern]

Options:
  --verbose     - Show detailed test output
  --coverage    - Generate coverage report
  --specific    - Run specific test pattern
  --cleanup     - Clean test environments before running
  --no-build    - Skip building tests (use existing)
  --help        - Show this help

Test Pattern:
  test_*.nim    - Run all tests (default)
  test_config   - Run config tests only
  test_deps     - Run dependency tests only
  etc.

Examples:
  $0                        # Run all tests
  $0 --verbose              # Run tests with verbose output
  $0 --specific test_config # Run config tests only
  $0 --coverage             # Run tests with coverage
  $0 --cleanup              # Clean and run all tests
EOF
}

# Set defaults
VERBOSE=false
COVERAGE=false
CLEANUP=false
NO_BUILD=false
TEST_PATTERN="test_*.nim"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --verbose)
            VERBOSE=true
            shift
            ;;
        --coverage)
            COVERAGE=true
            shift
            ;;
        --specific)
            if [[ $# -gt 1 ]]; then
                TEST_PATTERN="$2.nim"
                shift 2
            else
                error_exit "--specific requires a test name"
            fi
            ;;
        --cleanup)
            CLEANUP=true
            shift
            ;;
        --no-build)
            NO_BUILD=true
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        test_*)
            TEST_PATTERN="$1.nim"
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Ensure we're in the project root
if [[ ! -f "niuv.nimble" ]]; then
    error_exit "Must be run from project root (niuv.nimble not found)"
fi

# Setup test environment
setup_test_env() {
    log_info "Setting up test environment..."
    
    # Export test mode variables
    export NIUV_TEST_MODE=1
    export NIUV_TEST_HOME="$(pwd)/testenv"
    
    # Create test directories
    mkdir -p build/{debug,release}/{bin,tests} build/nimcache testenv
    
    # Create test environment if needed
    if [[ ! -d "$NIUV_TEST_HOME" ]] || [[ "$CLEANUP" == true ]]; then
        log_info "Creating test environment..."
        if nim c -r --nimcache:build/nimcache src/testenv.nim; then
            log_success "Test environment created"
        else
            log_warning "Test environment creation failed, continuing..."
        fi
    fi
}

# Cleanup old test environments
cleanup_test_env() {
    if [[ "$CLEANUP" == true ]]; then
        log_info "Cleaning up old test environments..."
        
        # Build cleanup tool if it exists
        if [[ -f "src/cleanup.nim" ]]; then
            if nim c -d:release -o:build/debug/bin/cleanup src/cleanup.nim; then
                ./build/debug/bin/cleanup --hours=1 || log_warning "Cleanup tool failed"
            else
                log_warning "Failed to build cleanup tool"
            fi
        fi
        
        # Manual cleanup
        rm -rf testenv/* build/tests/* || true
    fi
}

# Build tests
build_tests() {
    if [[ "$NO_BUILD" == true ]]; then
        log_info "Skipping test build (--no-build specified)"
        return
    fi
    
    log_info "Building tests..."
    
    local nim_flags="--nimcache:build/nimcache"
    if [[ "$COVERAGE" == true ]]; then
        nim_flags="$nim_flags --passC:-fprofile-arcs --passC:-ftest-coverage"
    fi
    
    local success_count=0
    local total_count=0
    
    while IFS= read -r -d '' test_file; do
        test_name=$(basename "$test_file" .nim)
        total_count=$((total_count + 1))
        
        if [[ "$VERBOSE" == true ]]; then
            log_info "Building $test_name"
        fi
        
        if [[ "$VERBOSE" == true ]]; then
            if nim c $nim_flags --out:build/debug/tests/$test_name "$test_file"; then
                success_count=$((success_count + 1))
                log_success "Built $test_name"
            else
                log_error "Failed to build $test_name"
            fi
        else
            if nim c $nim_flags --out:build/debug/tests/$test_name "$test_file" 2>&1 >/dev/null; then
                success_count=$((success_count + 1))
            else
                log_error "Failed to build $test_name"
            fi
        fi
    done < <(find tests -name "$TEST_PATTERN" -type f | tr '\n' '\0')
    
    log_info "Tests built: $success_count/$total_count"
    if [[ $success_count -eq 0 ]]; then
        error_exit "No tests were built successfully"
    fi
}

# Run tests
run_tests() {
    log_info "Running tests matching: $TEST_PATTERN"
    
    local success_count=0
    local total_count=0
    local failed_tests=()
    
    while IFS= read -r -d '' test_executable; do
        test_name=$(basename "$test_executable")
        total_count=$((total_count + 1))
        
        log_info "Running $test_name..."
        
        local output
        if [[ "$VERBOSE" == true ]]; then
            if "$test_executable"; then
                log_success "$test_name PASSED"
                success_count=$((success_count + 1))
            else
                log_error "$test_name FAILED"
                failed_tests+=("$test_name")
            fi
        else
            if output=$("$test_executable" 2>&1); then
                log_success "$test_name PASSED"
                success_count=$((success_count + 1))
            else
                log_error "$test_name FAILED"
                echo "$output" | head -5
                failed_tests+=("$test_name")
            fi
        fi
    done < <(find build/debug/tests -name "test_*" -type f -perm +111 2>/dev/null | tr '\n' '\0' || find build/debug/tests -name "test_*" -type f | tr '\n' '\0')
    
    # Report results
    echo
    log_info "Test Results: $success_count/$total_count passed"
    
    if [[ ${#failed_tests[@]} -gt 0 ]]; then
        log_error "Failed tests: ${failed_tests[*]}"
        return 1
    else
        log_success "All tests passed!"
        return 0
    fi
}

# Generate coverage report
generate_coverage() {
    if [[ "$COVERAGE" == true ]]; then
        log_info "Generating coverage report..."
        
        # Generate .gcov files
        if gcov -o build/nimcache src/*.nim 2>/dev/null; then
            log_success "Coverage data generated"
        else
            log_warning "Failed to generate coverage data"
        fi
        
        # Generate HTML report if lcov is available
        if command -v lcov >/dev/null 2>&1 && command -v genhtml >/dev/null 2>&1; then
            if lcov --capture --directory build/nimcache --output-file coverage.info 2>/dev/null; then
                genhtml coverage.info --output-directory coverage 2>/dev/null
                log_success "Coverage report generated: coverage/index.html"
            else
                log_warning "Failed to generate HTML coverage report"
            fi
        else
            log_info "Install lcov and genhtml for HTML coverage reports"
        fi
    fi
}

# Main execution
main() {
    log_info "Starting test runner..."
    log_info "Test pattern: $TEST_PATTERN"
    [[ "$VERBOSE" == true ]] && log_info "Verbose mode enabled"
    [[ "$COVERAGE" == true ]] && log_info "Coverage reporting enabled"
    [[ "$CLEANUP" == true ]] && log_info "Cleanup mode enabled"
    
    setup_test_env
    cleanup_test_env
    build_tests
    
    if run_tests; then
        generate_coverage
        log_success "Test runner completed successfully"
        exit 0
    else
        log_error "Some tests failed"
        exit 1
    fi
}

# Run main function
main