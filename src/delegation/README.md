# Delegation Architecture for niuv

## Overview

niuv uses a delegation pattern to leverage existing tools while providing a unified interface that can replace nimble.

## Core Principles

1. **Delegate when possible**: Use nim-testkit for testing, nimble for package registry operations
2. **Override when necessary**: Provide better implementations for installation, dependency resolution
3. **Extend functionality**: Add features like workspaces, parallel execution, virtual environments

## Delegation Map

### Testing (→ nim-testkit)
- Test discovery
- Test execution
- Coverage analysis
- Report generation
- MECE analysis

### Package Registry (→ nimble)
- Package search
- Package publishing
- Registry refresh
- Package metadata

### Build System (native)
- Task execution
- Dependency resolution
- Parallel builds
- Workspace builds

### Environment (native)
- Virtual environments
- Isolation
- Activation/deactivation

## Implementation Strategy

Each delegated component has:
1. An adapter interface in `src/delegation/`
2. Fallback implementation if delegate unavailable
3. Configuration to control delegation behavior