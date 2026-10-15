#!/bin/bash
# Installation script for Enhanced niuv with Global TestKit Coverage Support

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
NIUV_ENHANCED_NAME="niuv-enhanced"
INSTALL_DIR="$HOME/.local/bin"
COMPLETION_DIR="$HOME/.local/share/bash-completion/completions"
ZSH_COMPLETION_DIR="$HOME/.local/share/zsh/site-functions"
FISH_COMPLETION_DIR="$HOME/.config/fish/completions"

# Functions
print_header() {
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}🚀 Enhanced niuv with Global TestKit Coverage Support${NC}"
    echo -e "${CYAN}   Installation Script${NC}"
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

print_section() {
    echo -e "${BLUE}▶ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

check_dependencies() {
    print_section "Checking dependencies..."
    
    if ! command -v nim &> /dev/null; then
        print_error "Nim compiler not found. Please install Nim first."
        echo "Visit: https://nim-lang.org/install.html"
        exit 1
    fi
    
    print_success "Nim compiler found: $(nim --version | head -n1)"
}

build_enhanced_niuv() {
    print_section "Building enhanced niuv..."
    
    if [[ ! -f "niuv_enhanced.nim" ]]; then
        print_error "niuv_enhanced.nim not found in current directory"
        exit 1
    fi
    
    nim c -o:.build/niuv-enhanced niuv_enhanced.nim
    
    if [[ ! -f ".build/niuv-enhanced" ]]; then
        print_error "Build failed"
        exit 1
    fi
    
    print_success "Enhanced niuv built successfully"
}

install_binary() {
    print_section "Installing binary..."
    
    # Create install directory if it doesn't exist
    mkdir -p "$INSTALL_DIR"
    
    # Copy binary
    cp ".build/niuv-enhanced" "$INSTALL_DIR/$NIUV_ENHANCED_NAME"
    chmod +x "$INSTALL_DIR/$NIUV_ENHANCED_NAME"
    
    print_success "Installed to $INSTALL_DIR/$NIUV_ENHANCED_NAME"
    
    # Check if install directory is in PATH
    if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
        print_warning "Install directory is not in PATH"
        echo "Add this to your shell config file:"
        echo "  export PATH=\"$INSTALL_DIR:\$PATH\""
    fi
}

install_completions() {
    print_section "Installing shell completions..."
    
    # Detect available shells and install completions
    local shells_installed=0
    
    # Bash completion
    if command -v bash &> /dev/null && [[ -f "niuv-enhanced-completion.bash" ]]; then
        mkdir -p "$COMPLETION_DIR"
        cp "niuv-enhanced-completion.bash" "$COMPLETION_DIR/$NIUV_ENHANCED_NAME"
        print_success "Bash completion installed"
        ((shells_installed++))
    fi
    
    # Zsh completion
    if command -v zsh &> /dev/null && [[ -f "niuv-enhanced-completion.zsh" ]]; then
        mkdir -p "$ZSH_COMPLETION_DIR"
        cp "niuv-enhanced-completion.zsh" "$ZSH_COMPLETION_DIR/_$NIUV_ENHANCED_NAME"
        print_success "Zsh completion installed"
        ((shells_installed++))
    fi
    
    # Fish completion
    if command -v fish &> /dev/null && [[ -f "niuv-enhanced-completion.fish" ]]; then
        mkdir -p "$FISH_COMPLETION_DIR"
        cp "niuv-enhanced-completion.fish" "$FISH_COMPLETION_DIR/$NIUV_ENHANCED_NAME.fish"
        print_success "Fish completion installed"
        ((shells_installed++))
    fi
    
    if [[ $shells_installed -eq 0 ]]; then
        print_warning "No shell completions could be installed"
    else
        print_success "$shells_installed shell completion(s) installed"
    fi
}

setup_global_config() {
    print_section "Setting up global configuration..."
    
    # Run setup-config command
    "$INSTALL_DIR/$NIUV_ENHANCED_NAME" setup-config
    
    print_success "Global configuration created"
}

validate_installation() {
    print_section "Validating installation..."
    
    # Test that the binary works
    if ! "$INSTALL_DIR/$NIUV_ENHANCED_NAME" --help &> /dev/null; then
        print_error "Installation validation failed"
        exit 1
    fi
    
    # Validate configuration
    "$INSTALL_DIR/$NIUV_ENHANCED_NAME" validate-config
    
    print_success "Installation validated successfully"
}

print_usage_info() {
    print_section "Usage Information"
    echo ""
    echo -e "${CYAN}Basic Commands:${NC}"
    echo "  $NIUV_ENHANCED_NAME --help                    # Show help"
    echo "  $NIUV_ENHANCED_NAME setup-config             # Setup global config"
    echo "  $NIUV_ENHANCED_NAME validate-config          # Validate config"
    echo "  $NIUV_ENHANCED_NAME show-config              # Show current config"
    echo "  $NIUV_ENHANCED_NAME test-all                 # Run comprehensive tests"
    echo ""
    echo -e "${CYAN}Test Commands:${NC}"
    echo "  $NIUV_ENHANCED_NAME test                     # Run tests with coverage"
    echo "  $NIUV_ENHANCED_NAME test --no-coverage       # Run tests without coverage"
    echo "  $NIUV_ENHANCED_NAME test tests/test_*.nim    # Run specific tests"
    echo ""
    echo -e "${CYAN}Configuration:${NC}"
    echo "  Config file: ~/.config/niuv/config.ini"
    echo "  Override coverage: NIUV_TESTKIT_COVERAGE=false"
    echo ""
    echo -e "${CYAN}Features:${NC}"
    echo "  ✅ Global TestKit coverage configuration"
    echo "  ✅ Automatic coverage enablement by default"
    echo "  ✅ Performance optimizations (parallel execution)"
    echo "  ✅ Enhanced configuration validation"
    echo "  ✅ Shell completion support"
    echo "  ✅ Comprehensive Hourai W9P2025 test integration"
    echo ""
}

# Main installation flow
main() {
    print_header
    
    check_dependencies
    build_enhanced_niuv
    install_binary
    install_completions
    setup_global_config
    validate_installation
    
    echo ""
    echo -e "${GREEN}🎉 Installation completed successfully!${NC}"
    echo ""
    
    print_usage_info
    
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}Ready to use: $NIUV_ENHANCED_NAME${NC}"
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Handle command line arguments
case "${1:-}" in
    --help|-h)
        echo "Enhanced niuv Installation Script"
        echo ""
        echo "Usage: $0 [options]"
        echo ""
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo "  --binary-only  Install binary only, skip completions and config"
        echo "  --uninstall    Remove installed files"
        echo ""
        exit 0
        ;;
    --uninstall)
        print_section "Uninstalling enhanced niuv..."
        rm -f "$INSTALL_DIR/$NIUV_ENHANCED_NAME"
        rm -f "$COMPLETION_DIR/$NIUV_ENHANCED_NAME"
        rm -f "$ZSH_COMPLETION_DIR/_$NIUV_ENHANCED_NAME"
        rm -f "$FISH_COMPLETION_DIR/$NIUV_ENHANCED_NAME.fish"
        print_success "Uninstallation completed"
        echo "Note: Global configuration at ~/.config/niuv/config.ini was preserved"
        exit 0
        ;;
    --binary-only)
        print_header
        check_dependencies
        build_enhanced_niuv
        install_binary
        print_success "Binary-only installation completed"
        exit 0
        ;;
    *)
        main
        ;;
esac