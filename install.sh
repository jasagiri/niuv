#!/bin/bash
# Quick installation script for niuv
# Can be run with: curl -sSL https://example.com/install.sh | bash

set -e

echo "=== niuv Quick Installer ==="
echo ""

# Default installation directory
INSTALL_DIR="${NIUV_INSTALL_DIR:-$HOME/.niuv}"
BIN_DIR="$HOME/.local/bin"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running from niuv directory
if [ -f "niuv.nimble" ] && [ -f "niuv" ]; then
    echo -e "${GREEN}Running from niuv source directory${NC}"
    NIUV_BIN="$(pwd)/niuv"
    FROM_SOURCE=true
else
    echo -e "${RED}Error: This script should be run from the niuv directory${NC}"
    echo "Please cd to the niuv directory and run again"
    exit 1
fi

# Create bin directory
mkdir -p "$BIN_DIR"

# Install
echo "Installing niuv..."
if [ -e "$BIN_DIR/niuv" ]; then
    echo -e "${YELLOW}Warning: $BIN_DIR/niuv already exists${NC}"
    read -p "Overwrite? (y/N): " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo "Installation cancelled"
        exit 0
    fi
    rm -f "$BIN_DIR/niuv"
fi

ln -s "$NIUV_BIN" "$BIN_DIR/niuv"
echo -e "${GREEN}✓ Created symlink: $BIN_DIR/niuv${NC}"

# Check PATH
if ! echo "$PATH" | grep -q "$BIN_DIR"; then
    echo ""
    echo -e "${YELLOW}Important: Add $BIN_DIR to your PATH${NC}"
    echo ""
    
    # Detect shell
    if [ -n "$ZSH_VERSION" ]; then
        SHELL_NAME="zsh"
        RC_FILE="$HOME/.zshrc"
    elif [ -n "$BASH_VERSION" ]; then
        SHELL_NAME="bash"
        RC_FILE="$HOME/.bashrc"
    else
        SHELL_NAME="unknown"
        RC_FILE=""
    fi
    
    if [ -n "$RC_FILE" ]; then
        echo "Add this line to $RC_FILE:"
        echo ""
        echo '  export PATH="$HOME/.local/bin:$PATH"'
        echo ""
        read -p "Add automatically? (y/N): " add_path
        if [ "$add_path" = "y" ] || [ "$add_path" = "Y" ]; then
            echo '' >> "$RC_FILE"
            echo '# Added by niuv installer' >> "$RC_FILE"
            echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$RC_FILE"
            echo -e "${GREEN}✓ Added to $RC_FILE${NC}"
            echo "Please run: source $RC_FILE"
        fi
    fi
else
    echo -e "${GREEN}✓ $BIN_DIR is already in PATH${NC}"
fi

echo ""
echo -e "${GREEN}Installation complete!${NC}"
echo ""
echo "Next steps:"
echo "1. Reload your shell configuration or open a new terminal"
echo "2. Verify installation: niuv version"
echo "3. Get started: niuv help"