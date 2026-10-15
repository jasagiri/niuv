#!/bin/bash
#
# Script Name: run_shellspec.sh
# Description: Run ShellSpec tests for niuv shell scripts
# Usage: ./scripts/run_shellspec.sh [options]
# Dependencies: shellspec
# 
# Options:
#   --help        Show help message
#   --verbose     Run tests with verbose output
#   --coverage    Generate coverage report
#   --pattern     Run only tests matching pattern
#   --reporter    Set reporter format (documentation|tap|json)
#   --shell       Specify shell to test with (bash|sh|zsh)
#
# Examples:
#   ./scripts/run_shellspec.sh                    # Run all tests
#   ./scripts/run_shellspec.sh --verbose          # Verbose output
#   ./scripts/run_shellspec.sh -p "build_spec"    # Run build tests only
#   ./scripts/run_shellspec.sh --coverage         # With coverage
#

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

# Show help
show_help() {
    grep '^#' "$0" | grep -v '#!/bin/bash' | sed 's/^# //' | sed 's/^#//'
}

# Check if shellspec is installed
check_shellspec() {
    if ! command -v shellspec &> /dev/null; then
        log_error "ShellSpec is not installed!"
        echo ""
        echo "To install ShellSpec, run one of:"
        echo "  brew install shellspec        # macOS with Homebrew"
        echo "  curl -fsSL https://git.io/shellspec | sh"
        echo ""
        echo "For more info: https://github.com/shellspec/shellspec"
        exit 1
    fi
}

# Set defaults
VERBOSE=false
COVERAGE=false
PATTERN=""
REPORTER="documentation"
SHELL_TO_USE=""
SHELLSPEC_OPTS=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --help|-h)
            show_help
            exit 0
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --coverage)
            COVERAGE=true
            shift
            ;;
        --pattern|-p)
            if [[ $# -gt 1 ]]; then
                PATTERN="$2"
                shift 2
            else
                log_error "--pattern requires a value"
                exit 1
            fi
            ;;
        --reporter|-r)
            if [[ $# -gt 1 ]]; then
                REPORTER="$2"
                shift 2
            else
                log_error "--reporter requires a value"
                exit 1
            fi
            ;;
        --shell|-s)
            if [[ $# -gt 1 ]]; then
                SHELL_TO_USE="$2"
                shift 2
            else
                log_error "--shell requires a value"
                exit 1
            fi
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
    log_error "Must be run from project root (niuv.nimble not found)"
    exit 1
fi

# Check for shellspec
check_shellspec

# Build shellspec options
if [[ "$VERBOSE" == true ]]; then
    SHELLSPEC_OPTS="$SHELLSPEC_OPTS --format documentation"
else
    SHELLSPEC_OPTS="$SHELLSPEC_OPTS --format progress"
fi

if [[ "$COVERAGE" == true ]]; then
    SHELLSPEC_OPTS="$SHELLSPEC_OPTS --kcov"
fi

if [[ -n "$PATTERN" ]]; then
    SHELLSPEC_OPTS="$SHELLSPEC_OPTS --pattern '$PATTERN'"
fi

if [[ -n "$REPORTER" ]]; then
    SHELLSPEC_OPTS="$SHELLSPEC_OPTS --format $REPORTER"
fi

if [[ -n "$SHELL_TO_USE" ]]; then
    SHELLSPEC_OPTS="$SHELLSPEC_OPTS --shell $SHELL_TO_USE"
fi

# Run shellspec
log_info "Running ShellSpec tests..."
log_info "Options: $SHELLSPEC_OPTS"

if eval "shellspec $SHELLSPEC_OPTS"; then
    log_success "All tests passed!"
    
    if [[ "$COVERAGE" == true ]]; then
        log_info "Coverage report generated in coverage/"
    fi
else
    log_error "Some tests failed!"
    exit 1
fi