#!/bin/zsh
# Zsh completion for niuv-enhanced

_niuv_enhanced() {
    local context state line
    typeset -A opt_args
    
    _arguments -C \
        '1: :_niuv_enhanced_commands' \
        '*: :_niuv_enhanced_args' \
        && return 0
}

_niuv_enhanced_commands() {
    local commands; commands=(
        # Enhanced commands
        'setup-config:Create/update global configuration'
        'validate-config:Validate current configuration settings'
        'show-config:Display current configuration file'
        'test-all:Run comprehensive Hourai W9P2025 test suite'
        
        # Standard niuv commands
        'test:Run tests with nim-testkit integration'
        'init:Initialize a new virtual environment'
        'build:Build a Nim project'
        'install:Install packages from .nimble file'
        'add:Add a package to dependencies'
        'remove:Remove a package from dependencies'
        'sync:Synchronize installed packages'
        'activate:Activate the virtual environment'
        'shell:Start shell with activated environment'
        'run:Run a command in the virtual environment'
        'info:Show environment information'
        'setup:Setup shell integration'
        'generate:Generate a project using scaffold template'
        'clean:Clean build artifacts'
        'cleanall:Clean all artifacts including nimbledeps'
        'workspace:Workspace commands'
        'search:Search for packages'
        'publish:Publish package to registry'
        'develop:Link package for development'
        'path:Show package paths'
        'dump:Dump package metadata'
        'refresh:Refresh package list'
        'check:Validate package structure'
        'uninstall:Uninstall a package'
        'help:Show help message'
        'version:Show version information'
    )
    _describe 'commands' commands
}

_niuv_enhanced_args() {
    case $words[2] in
        test)
            _arguments \
                '--no-coverage[Skip coverage even if enabled globally]' \
                '*:test files:_files -g "tests/test_*.nim"'
            ;;
        workspace)
            _arguments '1: :(init install build test publish)'
            ;;
        add|remove|uninstall)
            _arguments '1: :_command_names'
            ;;
        *)
            _arguments \
                '--help[Show help message]' \
                '-h[Show help message]' \
                '--no-coverage[Skip coverage]' \
                '--dev[Include development dependencies]' \
                '--verbose[Show verbose output]' \
                '--parallel[Enable parallel execution]' \
                '--force[Force operation]' \
                '--nim-version[Use specific Nim version]:version:' \
                '--cache-dir[Custom cache directory]:directory:_directories' \
                '--lockfile[Specify lockfile path]:file:_files' \
                '--nimble-dir[Specify Nimble directory]:directory:_directories'
            ;;
    esac
}

# Test file completion helper
_test_files() {
    local -a test_files
    if [[ -d tests ]]; then
        test_files=(tests/test_*.nim(N:t))
        _describe 'test files' test_files
    fi
}

# Register the completion
compdef _niuv_enhanced niuv-enhanced