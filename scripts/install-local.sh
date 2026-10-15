#!/bin/bash
# Local installation script for niuv
# This script helps users install niuv locally without modifying system paths

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NIUV_ROOT="$(dirname "$SCRIPT_DIR")"
NIUV_BIN="$NIUV_ROOT/niuv"

echo "=== niuv Local Installation Helper ==="
echo ""
echo "This script will help you set up niuv for local use."
echo "niuv binary location: $NIUV_BIN"
echo ""

# Check if niuv binary exists
if [ ! -f "$NIUV_BIN" ]; then
    echo "Error: niuv binary not found at $NIUV_BIN"
    echo "Please build niuv first with: nimble build"
    exit 1
fi

# Offer installation options
echo "Choose installation method:"
echo ""
echo "1. Create symlink in ~/.local/bin (recommended)"
echo "2. Create symlink in /usr/local/bin (requires sudo)"
echo "3. Show manual installation instructions"
echo "4. Create shell alias (temporary)"
echo ""
read -p "Enter choice (1-4): " choice

case $choice in
    1)
        # User local bin
        LOCAL_BIN="$HOME/.local/bin"
        mkdir -p "$LOCAL_BIN"
        
        if [ -e "$LOCAL_BIN/niuv" ]; then
            echo "Warning: $LOCAL_BIN/niuv already exists"
            read -p "Overwrite? (y/N): " confirm
            if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
                echo "Installation cancelled"
                exit 0
            fi
            rm -f "$LOCAL_BIN/niuv"
        fi
        
        ln -s "$NIUV_BIN" "$LOCAL_BIN/niuv"
        echo "✓ Created symlink: $LOCAL_BIN/niuv -> $NIUV_BIN"
        echo ""
        
        # Check if ~/.local/bin is in PATH
        if ! echo "$PATH" | grep -q "$LOCAL_BIN"; then
            echo "Note: $LOCAL_BIN is not in your PATH"
            echo "Add this line to your shell configuration file:"
            echo ""
            echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
            echo ""
            echo "For bash: ~/.bashrc or ~/.bash_profile"
            echo "For zsh:  ~/.zshrc"
        else
            echo "✓ $LOCAL_BIN is already in PATH"
            echo "You can now use: niuv"
        fi
        ;;
        
    2)
        # System bin (requires sudo)
        SYSTEM_BIN="/usr/local/bin"
        
        if [ -e "$SYSTEM_BIN/niuv" ]; then
            echo "Warning: $SYSTEM_BIN/niuv already exists"
            read -p "Overwrite? (y/N): " confirm
            if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
                echo "Installation cancelled"
                exit 0
            fi
        fi
        
        echo "Creating symlink in $SYSTEM_BIN (requires sudo)..."
        sudo ln -sf "$NIUV_BIN" "$SYSTEM_BIN/niuv"
        echo "✓ Created symlink: $SYSTEM_BIN/niuv -> $NIUV_BIN"
        echo "You can now use: niuv"
        ;;
        
    3)
        # Manual instructions
        echo "Manual Installation Instructions:"
        echo "================================="
        echo ""
        echo "Option 1: Add to PATH"
        echo "  export PATH=\"$NIUV_ROOT:\$PATH\""
        echo ""
        echo "Option 2: Create alias"
        echo "  alias niuv=\"$NIUV_BIN\""
        echo ""
        echo "Option 3: Create symlink"
        echo "  ln -s \"$NIUV_BIN\" ~/bin/niuv"
        echo "  # or"
        echo "  ln -s \"$NIUV_BIN\" ~/.local/bin/niuv"
        echo ""
        echo "Add the chosen option to your shell configuration file."
        ;;
        
    4)
        # Temporary alias
        echo "Creating temporary alias for current shell session..."
        echo ""
        echo "Run this command:"
        echo "  alias niuv=\"$NIUV_BIN\""
        echo ""
        echo "Note: This alias will only last for the current session."
        echo "For permanent installation, choose option 1 or 2."
        ;;
        
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac

echo ""
echo "Installation helper complete!"