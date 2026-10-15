#!/bin/bash
# Bash completion for niuv-enhanced

_niuv_enhanced_completions() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    
    # Enhanced niuv-specific commands
    local enhanced_commands="setup-config validate-config show-config test-all"
    
    # Standard niuv commands (pass-through)
    local niuv_commands="test init build install add remove sync activate shell run info setup generate clean cleanall workspace search publish develop path dump refresh check uninstall help version"
    
    # All available commands
    opts="$enhanced_commands $niuv_commands"
    
    # Handle subcommands
    case "${prev}" in
        "niuv-enhanced")
            COMPREPLY=( $(compgen -W "$opts" -- "$cur") )
            return 0
            ;;
        "test")
            # Test file completion
            if [[ -d "tests" ]]; then
                local test_files=$(find tests -name "test_*.nim" -o -name "*_test.nim" 2>/dev/null | sed 's|^tests/||')
                COMPREPLY=( $(compgen -W "$test_files --no-coverage" -- "$cur") )
            else
                COMPREPLY=( $(compgen -W "--no-coverage" -- "$cur") )
            fi
            return 0
            ;;
        "workspace")
            COMPREPLY=( $(compgen -W "init install build test publish" -- "$cur") )
            return 0
            ;;
        "add"|"remove"|"uninstall")
            # Package name completion (could be enhanced with actual package list)
            COMPREPLY=( $(compgen -W "" -- "$cur") )
            return 0
            ;;
        *)
            ;;
    esac
    
    # Flag completion
    if [[ "$cur" == -* ]]; then
        local flags="--help -h --no-coverage --dev --verbose --parallel --force --nim-version --cache-dir --lockfile --nimble-dir"
        COMPREPLY=( $(compgen -W "$flags" -- "$cur") )
        return 0
    fi
    
    # File completion for certain contexts
    if [[ "$prev" == "--nim-version" || "$prev" == "--cache-dir" || "$prev" == "--lockfile" || "$prev" == "--nimble-dir" ]]; then
        COMPREPLY=( $(compgen -f -- "$cur") )
        return 0
    fi
    
    # Default to command completion
    COMPREPLY=( $(compgen -W "$opts" -- "$cur") )
}

# Register the completion function
complete -F _niuv_enhanced_completions niuv-enhanced