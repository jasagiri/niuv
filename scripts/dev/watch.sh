#!/bin/bash
#
# Script Name: watch.sh
# Description: Watch files for changes and rebuild automatically
# Usage: ./scripts/dev/watch.sh [target]
# Dependencies: fswatch (macOS) or inotify-tools (Linux)
# 
# Targets:
#   main      - Watch and rebuild main executable (default)
#   tests     - Watch and rebuild/run tests
#   examples  - Watch and rebuild examples
#   all       - Watch and rebuild everything
#

set -euo pipefail

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/common.sh"
source "$SCRIPT_DIR/../utils/platform.sh"

# Show help
show_help() {
    grep '^#' "$0" | grep -v '#!/bin/bash' | sed 's/^# //' | sed 's/^#//'
}

# Check for file watcher tool
check_watcher() {
    case "$PLATFORM_OS" in
        macos)
            if ! command -v fswatch &> /dev/null; then
                log_error "fswatch not found. Install with: brew install fswatch"
                exit 1
            fi
            ;;
        linux)
            if ! command -v inotifywait &> /dev/null; then
                log_error "inotify-tools not found. Install with: apt-get install inotify-tools"
                exit 1
            fi
            ;;
        *)
            log_error "Unsupported platform for file watching: $PLATFORM_OS"
            exit 1
            ;;
    esac
}

# Build on change
build_on_change() {
    local target="$1"
    
    clear
    log_info "Building $target..."
    
    case "$target" in
        main)
            "$SCRIPT_DIR/../build.sh" main
            ;;
        tests)
            "$SCRIPT_DIR/../build.sh" tests
            "$SCRIPT_DIR/../test.sh" --no-build
            ;;
        examples)
            "$SCRIPT_DIR/../build.sh" examples
            ;;
        all)
            "$SCRIPT_DIR/../build.sh" all
            ;;
    esac
    
    echo
    log_info "Waiting for changes..."
}

# Watch files with fswatch (macOS)
watch_with_fswatch() {
    local target="$1"
    local paths=("src" "tests" "examples" "*.nimble" "*.nim")
    
    log_info "Watching with fswatch..."
    
    # Initial build
    build_on_change "$target"
    
    # Watch for changes
    fswatch -o "${paths[@]}" -e "build/" -e "nimcache/" | while read num; do
        build_on_change "$target"
    done
}

# Watch files with inotify (Linux)
watch_with_inotify() {
    local target="$1"
    local paths=("src" "tests" "examples")
    
    log_info "Watching with inotify..."
    
    # Initial build
    build_on_change "$target"
    
    # Watch for changes
    while true; do
        inotifywait -r -e modify,create,delete,move \
            --exclude '(build/|nimcache/|\.git/)' \
            "${paths[@]}" \
            *.nimble *.nim 2>/dev/null
        
        build_on_change "$target"
    done
}

# Main function
main() {
    local target="main"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            main|tests|examples|all)
                target="$1"
                shift
                ;;
            --help|-h)
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
    
    # Ensure we're in project root
    if [[ ! -f "niuv.nimble" ]]; then
        log_error "Must be run from project root"
        exit 1
    fi
    
    # Check for watcher tool
    check_watcher
    
    log_info "Starting file watcher for target: $target"
    log_info "Press Ctrl+C to stop"
    echo
    
    # Start watching based on platform
    case "$PLATFORM_OS" in
        macos)
            watch_with_fswatch "$target"
            ;;
        linux)
            watch_with_inotify "$target"
            ;;
    esac
}

# Handle Ctrl+C gracefully
trap 'echo; log_info "Stopping watcher..."; exit 0' INT

# Run main
main "$@"