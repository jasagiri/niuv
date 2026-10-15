#!/usr/bin/env fish
# Fish completion for niuv-enhanced

# Enhanced commands
complete -c niuv-enhanced -n "__fish_use_subcommand" -a "setup-config" -d "Create/update global configuration"
complete -c niuv-enhanced -n "__fish_use_subcommand" -a "validate-config" -d "Validate current configuration settings"
complete -c niuv-enhanced -n "__fish_use_subcommand" -a "show-config" -d "Display current configuration file"
complete -c niuv-enhanced -n "__fish_use_subcommand" -a "test-all" -d "Run comprehensive Hourai W9P2025 test suite"

# Standard niuv commands
complete -c niuv-enhanced -n "__fish_use_subcommand" -a "test" -d "Run tests with nim-testkit integration"
complete -c niuv-enhanced -n "__fish_use_subcommand" -a "init" -d "Initialize a new virtual environment"
complete -c niuv-enhanced -n "__fish_use_subcommand" -a "build" -d "Build a Nim project"
complete -c niuv-enhanced -n "__fish_use_subcommand" -a "install" -d "Install packages from .nimble file"
complete -c niuv-enhanced -n "__fish_use_subcommand" -a "add" -d "Add a package to dependencies"
complete -c niuv-enhanced -n "__fish_use_subcommand" -a "remove" -d "Remove a package from dependencies"
complete -c niuv-enhanced -n "__fish_use_subcommand" -a "sync" -d "Synchronize installed packages"
complete -c niuv-enhanced -n "__fish_use_subcommand" -a "activate" -d "Activate the virtual environment"
complete -c niuv-enhanced -n "__fish_use_subcommand" -a "shell" -d "Start shell with activated environment"
complete -c niuv-enhanced -n "__fish_use_subcommand" -a "run" -d "Run a command in the virtual environment"
complete -c niuv-enhanced -n "__fish_use_subcommand" -a "info" -d "Show environment information"
complete -c niuv-enhanced -n "__fish_use_subcommand" -a "setup" -d "Setup shell integration"
complete -c niuv-enhanced -n "__fish_use_subcommand" -a "generate" -d "Generate a project using scaffold template"
complete -c niuv-enhanced -n "__fish_use_subcommand" -a "clean" -d "Clean build artifacts"
complete -c niuv-enhanced -n "__fish_use_subcommand" -a "cleanall" -d "Clean all artifacts including nimbledeps"
complete -c niuv-enhanced -n "__fish_use_subcommand" -a "workspace" -d "Workspace commands"
complete -c niuv-enhanced -n "__fish_use_subcommand" -a "search" -d "Search for packages"
complete -c niuv-enhanced -n "__fish_use_subcommand" -a "publish" -d "Publish package to registry"
complete -c niuv-enhanced -n "__fish_use_subcommand" -a "develop" -d "Link package for development"
complete -c niuv-enhanced -n "__fish_use_subcommand" -a "path" -d "Show package paths"
complete -c niuv-enhanced -n "__fish_use_subcommand" -a "dump" -d "Dump package metadata"
complete -c niuv-enhanced -n "__fish_use_subcommand" -a "refresh" -d "Refresh package list"
complete -c niuv-enhanced -n "__fish_use_subcommand" -a "check" -d "Validate package structure"
complete -c niuv-enhanced -n "__fish_use_subcommand" -a "uninstall" -d "Uninstall a package"
complete -c niuv-enhanced -n "__fish_use_subcommand" -a "help" -d "Show help message"
complete -c niuv-enhanced -n "__fish_use_subcommand" -a "version" -d "Show version information"

# Global flags
complete -c niuv-enhanced -l help -d "Show help message"
complete -c niuv-enhanced -s h -d "Show help message"
complete -c niuv-enhanced -l no-coverage -d "Skip coverage even if enabled globally"
complete -c niuv-enhanced -l dev -d "Include development dependencies"
complete -c niuv-enhanced -l verbose -d "Show verbose output"
complete -c niuv-enhanced -l parallel -d "Enable parallel execution"
complete -c niuv-enhanced -l force -d "Force operation"
complete -c niuv-enhanced -l nim-version -d "Use specific Nim version" -r
complete -c niuv-enhanced -l cache-dir -d "Custom cache directory" -r -a "(__fish_complete_directories)"
complete -c niuv-enhanced -l lockfile -d "Specify lockfile path" -r -a "(__fish_complete_suffix .lock)"
complete -c niuv-enhanced -l nimble-dir -d "Specify Nimble directory" -r -a "(__fish_complete_directories)"

# Test subcommand completions
complete -c niuv-enhanced -n "__fish_seen_subcommand_from test" -l no-coverage -d "Skip coverage"
complete -c niuv-enhanced -n "__fish_seen_subcommand_from test" -a "(find tests -name 'test_*.nim' -o -name '*_test.nim' 2>/dev/null | sed 's|^tests/||')" -d "Test file"

# Workspace subcommand completions
complete -c niuv-enhanced -n "__fish_seen_subcommand_from workspace" -a "init" -d "Initialize workspace"
complete -c niuv-enhanced -n "__fish_seen_subcommand_from workspace" -a "install" -d "Install workspace dependencies"
complete -c niuv-enhanced -n "__fish_seen_subcommand_from workspace" -a "build" -d "Build workspace packages"
complete -c niuv-enhanced -n "__fish_seen_subcommand_from workspace" -a "test" -d "Test workspace packages"
complete -c niuv-enhanced -n "__fish_seen_subcommand_from workspace" -a "publish" -d "Publish workspace packages"