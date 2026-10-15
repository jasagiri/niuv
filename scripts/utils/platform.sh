#!/bin/bash
#
# Script Name: platform.sh
# Description: Platform detection and cross-platform utilities
# Usage: source scripts/utils/platform.sh
# 
# Provides:
#   - OS detection (Linux, macOS, Windows/WSL)
#   - Architecture detection
#   - Cross-platform command wrappers
#

# Detect operating system
detect_os() {
    case "$(uname -s)" in
        Linux*)     echo "linux";;
        Darwin*)    echo "macos";;
        MINGW*|MSYS*|CYGWIN*)  echo "windows";;
        *)          echo "unknown";;
    esac
}

# Detect architecture
detect_arch() {
    case "$(uname -m)" in
        x86_64)     echo "amd64";;
        arm64|aarch64) echo "arm64";;
        i686)       echo "i386";;
        *)          echo "unknown";;
    esac
}

# Check if running in WSL
is_wsl() {
    if grep -qi microsoft /proc/version 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Cross-platform open command
open_file() {
    local file="$1"
    case "$(detect_os)" in
        linux)
            if is_wsl; then
                explorer.exe "$file"
            else
                xdg-open "$file"
            fi
            ;;
        macos)
            open "$file"
            ;;
        windows)
            start "$file"
            ;;
        *)
            echo "Unsupported platform for opening files"
            return 1
            ;;
    esac
}

# Cross-platform copy to clipboard
copy_to_clipboard() {
    case "$(detect_os)" in
        linux)
            if is_wsl; then
                clip.exe
            elif command -v xclip &> /dev/null; then
                xclip -selection clipboard
            elif command -v xsel &> /dev/null; then
                xsel --clipboard --input
            else
                echo "No clipboard tool found. Install xclip or xsel."
                return 1
            fi
            ;;
        macos)
            pbcopy
            ;;
        windows)
            clip
            ;;
        *)
            echo "Unsupported platform for clipboard"
            return 1
            ;;
    esac
}

# Get number of CPU cores
get_cpu_cores() {
    case "$(detect_os)" in
        linux|windows)
            nproc 2>/dev/null || echo 1
            ;;
        macos)
            sysctl -n hw.ncpu 2>/dev/null || echo 1
            ;;
        *)
            echo 1
            ;;
    esac
}

# Export functions for use in other scripts
export -f detect_os
export -f detect_arch
export -f is_wsl
export -f open_file
export -f copy_to_clipboard
export -f get_cpu_cores

# Export variables
export PLATFORM_OS=$(detect_os)
export PLATFORM_ARCH=$(detect_arch)
export CPU_CORES=$(get_cpu_cores)