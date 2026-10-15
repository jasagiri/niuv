#!/bin/bash
# Enhanced PATH fix script - addresses all command not found issues

echo "🔧 Enhanced PATH Environment Fix"
echo "================================"

# Standard macOS paths
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin"

# Add Homebrew paths
if [ -d "/opt/homebrew/bin" ]; then
    export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"
fi

# Add Nim paths
if [ -d "$HOME/.choosenim/toolchains/nim-2.2.4/bin" ]; then
    export PATH="$HOME/.choosenim/toolchains/nim-2.2.4/bin:$PATH"
fi

if [ -d "$HOME/.nimble/bin" ]; then
    export PATH="$HOME/.nimble/bin:$PATH"
fi

# Add user local bin
if [ -d "$HOME/.local/bin" ]; then
    export PATH="$HOME/.local/bin:$PATH"
fi

# Verify critical commands
echo "Checking critical commands:"
echo -n "✓ ls: "; which ls || echo "❌ MISSING"
echo -n "✓ nim: "; which nim || echo "❌ MISSING"
echo -n "✓ niuv: "; which niuv || echo "❌ MISSING"

echo ""
echo "Current PATH:"
echo "$PATH"
echo ""
echo "Environment ready! You can now run:"
echo "  cd /Users/jasagiri/GodsGolemInc/sources/libs/development-testing/niuv"
echo "  nim c -d:release -o:~/.local/bin/niuv src/niuv.nim"

# Make this environment persistent for the current shell
if [ "$1" = "--save" ]; then
    echo ""
    echo "Saving to ~/.zshrc..."
    echo "export PATH=\"$PATH\"" >> ~/.zshrc
    echo "✓ PATH saved to ~/.zshrc"
fi