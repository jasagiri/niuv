#!/bin/bash
#
# Script Name: setup.sh
# Description: Development environment setup for niuv
# Usage: ./scripts/dev/setup.sh [options]
# Dependencies: nim, nimble
# 
# Options:
#   --minimal     Install only essential dependencies
#   --full        Install all optional dependencies
#   --check       Check environment without installing
#

set -euo pipefail

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/common.sh"
source "$SCRIPT_DIR/../utils/platform.sh"

# Colors from common.sh are already available

# Show help
show_help() {
    grep '^#' "$0" | grep -v '#!/bin/bash' | sed 's/^# //' | sed 's/^#//'
}

# Check Nim installation
check_nim() {
    if command -v nim &> /dev/null; then
        local version=$(nim --version | head -1)
        log_success "Nim installed: $version"
        return 0
    else
        log_error "Nim not found"
        return 1
    fi
}

# Check Nimble installation
check_nimble() {
    if command -v nimble &> /dev/null; then
        local version=$(nimble --version | head -1)
        log_success "Nimble installed: $version"
        return 0
    else
        log_error "Nimble not found"
        return 1
    fi
}

# Check optional tools
check_optional_tools() {
    local tools=("git" "shellspec" "lcov" "python3")
    
    for tool in "${tools[@]}"; do
        if command -v "$tool" &> /dev/null; then
            log_info "✓ $tool is installed"
        else
            log_warning "✗ $tool is not installed (optional)"
        fi
    done
}

# Install nim dependencies
install_dependencies() {
    log_info "Installing Nim dependencies..."
    
    if nimble install -y; then
        log_success "Dependencies installed successfully"
    else
        log_error "Failed to install dependencies"
        return 1
    fi
}

# Create development directories
setup_directories() {
    log_info "Setting up development directories..."
    
    mkdir -p build/{debug,release}/{bin,tests,examples}
    mkdir -p coverage
    mkdir -p docs/api
    
    log_success "Directories created"
}

# Setup git hooks
setup_git_hooks() {
    if [[ -d .git ]]; then
        log_info "Setting up git hooks..."
        
        # Create pre-commit hook
        cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash
# Run tests before committing
./scripts/test.sh --no-build
EOF
        chmod +x .git/hooks/pre-commit
        
        log_success "Git hooks installed"
    else
        log_warning "Not a git repository, skipping hooks"
    fi
}

# Main setup
main() {
    local mode="normal"
    local check_only=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --minimal)
                mode="minimal"
                shift
                ;;
            --full)
                mode="full"
                shift
                ;;
            --check)
                check_only=true
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
    
    log_info "niuv Development Environment Setup"
    log_info "Platform: $PLATFORM_OS ($PLATFORM_ARCH)"
    log_info "CPU cores: $CPU_CORES"
    echo
    
    # Check requirements
    log_info "Checking requirements..."
    local has_nim=false
    local has_nimble=false
    
    if check_nim; then has_nim=true; fi
    if check_nimble; then has_nimble=true; fi
    
    if [[ "$has_nim" != true ]] || [[ "$has_nimble" != true ]]; then
        log_error "Missing required tools. Please install Nim and Nimble."
        echo
        echo "Installation instructions:"
        echo "  https://nim-lang.org/install.html"
        echo "  or: curl https://nim-lang.org/choosenim/init.sh -sSf | sh"
        exit 1
    fi
    
    if [[ "$mode" == "full" ]]; then
        echo
        log_info "Checking optional tools..."
        check_optional_tools
    fi
    
    if [[ "$check_only" == true ]]; then
        log_info "Check complete (--check mode)"
        exit 0
    fi
    
    # Setup environment
    echo
    log_info "Setting up development environment..."
    
    install_dependencies
    setup_directories
    
    if [[ "$mode" != "minimal" ]]; then
        setup_git_hooks
    fi
    
    # Build main executable
    log_info "Building niuv executable..."
    if "$SCRIPT_DIR/../build.sh" main; then
        log_success "Build successful"
    else
        log_error "Build failed"
        exit 1
    fi
    
    echo
    log_success "Development environment setup complete!"
    echo
    echo "Next steps:"
    echo "  1. Run tests: ./scripts/test.sh"
    echo "  2. Build all: ./scripts/build.sh"
    echo "  3. Generate docs: ./scripts/core/docs.sh"
    echo
    echo "For more information, see scripts/README.md"
}

# Run main
main "$@"