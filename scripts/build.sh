#!/bin/bash
# Unified build script for niuv project
# Consolidates functionality from compile_examples.sh and compile_tests.sh

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
Unified Build Script for niuv

Usage: $0 [target] [options]

Targets:
  all       - Build everything (default)
  tests     - Build test files only
  examples  - Build example files only  
  main      - Build main niuv executable
  clean     - Clean build artifacts
  help      - Show this help

Options:
  --debug   - Build in debug mode (default)
  --release - Build in release mode

Examples:
  $0                    # Build everything in debug mode
  $0 examples --release # Build examples in release mode
  $0 clean             # Clean build artifacts
EOF
}

# Set defaults
TARGET="all"
MODE="debug"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        all|tests|examples|main|clean)
            TARGET="$1"
            shift
            ;;
        --debug)
            MODE="debug"
            shift
            ;;
        --release)
            MODE="release"
            shift
            ;;
        help|--help|-h)
            show_help
            exit 0
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

# Setup build directories
setup_dirs() {
    log_info "Setting up build directories..."
    mkdir -p build/{debug,release}/{bin,tests,examples} build/nimcache
}

# Build main executable
build_main() {
    log_info "Building main niuv executable in $MODE mode..."
    local nim_flags="--nimcache:build/nimcache"
    
    if [[ "$MODE" == "release" ]]; then
        nim_flags="$nim_flags -d:release"
    fi
    
    nim c $nim_flags --out:build/$MODE/bin/niuv src/niuv.nim
    
    if [[ $? -eq 0 ]]; then
        log_success "Built niuv executable: build/$MODE/bin/niuv"
    else
        error_exit "Failed to build main executable"
    fi
}

# Build examples
build_examples() {
    log_info "Building example files in $MODE mode..."
    local success_count=0
    local total_count=0
    local nim_flags="--nimcache:build/nimcache"
    
    if [[ "$MODE" == "release" ]]; then
        nim_flags="$nim_flags -d:release"
    fi
    
    while IFS= read -r -d '' example_file; do
        example_name=$(basename "$example_file" .nim)
        total_count=$((total_count + 1))
        
        log_info "Compiling $example_name from $example_file"
        
        if nim c $nim_flags --out:build/$MODE/examples/$example_name "$example_file"; then
            log_success "Compiled $example_name"
            success_count=$((success_count + 1))
        else
            log_error "Failed to compile $example_name"
        fi
    done < <(find examples -name "*.nim" -type f -print0)
    
    log_info "Examples: $success_count/$total_count compiled successfully"
    if [[ $success_count -lt $total_count ]]; then
        error_exit "Some examples failed to compile"
    fi
}

# Build tests
build_tests() {
    log_info "Building test files in $MODE mode..."
    local success_count=0
    local total_count=0
    local nim_flags="--nimcache:build/nimcache"
    
    if [[ "$MODE" == "release" ]]; then
        nim_flags="$nim_flags -d:release"
    fi
    
    while IFS= read -r -d '' test_file; do
        test_name=$(basename "$test_file" .nim)
        total_count=$((total_count + 1))
        
        log_info "Compiling $test_name from $test_file"
        
        if nim c $nim_flags --out:build/$MODE/tests/$test_name "$test_file"; then
            log_success "Compiled $test_name"
            success_count=$((success_count + 1))
        else
            log_error "Failed to compile $test_name"
        fi
    done < <(find tests -name "test_*.nim" -type f -print0)
    
    log_info "Tests: $success_count/$total_count compiled successfully"
    if [[ $success_count -lt $total_count ]]; then
        error_exit "Some tests failed to compile"
    fi
}

# Clean build artifacts
clean_build() {
    log_info "Cleaning build artifacts..."
    rm -rf build/ nimcache/
    log_success "Build artifacts cleaned"
}

# Main execution
main() {
    log_info "Starting build process: target=$TARGET, mode=$MODE"
    
    case $TARGET in
        clean)
            clean_build
            ;;
        main)
            setup_dirs
            build_main
            ;;
        examples)
            setup_dirs
            build_examples
            ;;
        tests)
            setup_dirs
            build_tests
            ;;
        all)
            setup_dirs
            build_main
            build_examples
            build_tests
            ;;
        *)
            error_exit "Unknown target: $TARGET"
            ;;
    esac
    
    log_success "Build process completed successfully"
}

# Run main function
main