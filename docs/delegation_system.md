# Delegation System

The niuv delegation system provides a flexible way to integrate and coordinate multiple development tools under a unified interface.

## Overview

The delegation system allows niuv to act as a smart coordinator that:
- Automatically selects the best tool for each task
- Provides fallback options when tools are unavailable
- Supports conditional delegation based on project state
- Maintains a consistent interface across different tools

## Architecture

### Core Components

1. **Base Framework** (`src/delegation/base.nim`)
   - Defines delegation interfaces and capabilities
   - Provides delegation templates and utilities
   - Manages tool discovery and validation

2. **Command Implementations** (`src/delegation/commands/`)
   - **build.nim**: Build system delegation (nimble, testkit, custom)
   - **test.nim**: Test framework delegation (testkit, builtin, nimble)
   - **doc.nim**: Documentation generation delegation
   - **release.nim**: Release management delegation

3. **Integrations** (`src/delegation/`)
   - **vcs_integration.nim**: Multi-VCS support (Git, Jujutsu, Mercurial, SVN, Fossil)
   - **logging_integration.nim**: Structured logging with context
   - **advanced_config.nim**: Advanced configuration management
   - **mcp_integration.nim**: MCP protocol integration
   - **comprehensive_integration.nim**: Unified integration layer

## Configuration

### Basic Configuration

```toml
[tool.niuv.delegation]
build = "nimble"    # Default build tool
test = "testkit"    # Default test tool
doc = "nimble"      # Default documentation tool
release = "testkit" # Default release tool
```

### Advanced Configuration

```toml
[tool.niuv.delegation.advanced]
# Conditional delegation
build = { tool = "testkit", when = "exists:nimtestkit.toml" }

# Priority-based selection
test = [
  { tool = "testkit", priority = 1 },
  { tool = "nimble", priority = 2 },
  { tool = "builtin", priority = 3 }
]

# Custom command mapping
custom_commands = {
  benchmark = { tool = "testkit", command = "benchmark" },
  profile = { tool = "custom", script = "scripts/profile.sh" }
}
```

### VCS Configuration

```toml
[tool.niuv.vcs]
# Preferred VCS (auto-detected if not specified)
preferred = "jujutsu"  # or "git", "mercurial", "svn", "fossil"

# VCS-specific settings
[tool.niuv.vcs.jujutsu]
default_branch = "main"
release_branch = "release"

[tool.niuv.vcs.git]
default_branch = "main"
use_signed_commits = true
```

## Usage Examples

### Build Delegation

```bash
# Uses configured build tool
niuv build

# Force specific tool
niuv build --delegate=nimble

# Custom build with fallback
niuv build --delegate=custom --fallback=nimble
```

### Test Delegation

```bash
# Run tests with best available tool
niuv test

# Use nim-testkit specifically
niuv test --delegate=testkit

# Run with coverage (delegates to tool that supports it)
niuv test --coverage
```

### Release Management

```bash
# Create release with configured tool
niuv release

# Use nim-testkit's release manager
niuv release --delegate=testkit

# Specify VCS for release
niuv release --vcs=git
```

## Integration Patterns

### VCS Integration

The VCS integration provides:
- Auto-detection of repository type
- Unified interface for common operations
- Support for multiple VCS backends

```nim
import niuv/delegation/vcs_integration

# Auto-detect VCS
let vcs = autoDetectVCS()
echo "Detected VCS: ", vcs.vcsType

# Get current branch/change
let branch = vcs.getCurrentBranch()
echo "Current branch: ", branch

# Check for uncommitted changes
if vcs.hasUncommittedChanges():
  echo "Warning: Uncommitted changes detected"
```

### Logging Integration

Structured logging with operation context:

```nim
import niuv/delegation/logging_integration

# Create logging context
let ctx = NiuvLogContext(
  operation: "build",
  component: "delegation",
  delegate: some("nimble")
)

# Log with context
logInfo(ctx, "Starting delegated build")
logDebug(ctx, "Using nimble as build tool")
```

### MCP Integration

Support for AI-assisted development:

```nim
import niuv/delegation/mcp_integration

# Register MCP tools
let tools = getMCPTools()
for tool in tools:
  echo "Tool: ", tool.name
  echo "Description: ", tool.description

# Get MCP resources
let resources = getMCPResources()
for resource in resources:
  echo "Resource: ", resource.uri
```

## Creating Custom Delegations

To add a new delegation:

1. Create a new command module in `src/delegation/commands/`
2. Implement the delegation interface
3. Register in the delegation configuration

Example custom delegation:

```nim
# src/delegation/commands/custom.nim
import ../base

proc executeCustomCommand*(config: Config, args: seq[string]): int =
  let delegateConfig = getDelegationConfig(config)
  
  delegateOr(delegateConfig, dcCustom):
    # Delegation logic
    let tool = findTool("custom-tool")
    if tool.isSome:
      return execCmd(tool.get & " " & args.join(" "))
  do:
    # Fallback logic
    echo "Custom tool not available, using fallback"
    return 0
```

## Best Practices

1. **Tool Discovery**: Always check tool availability before delegation
2. **Fallback Chains**: Provide sensible fallbacks for missing tools
3. **Configuration**: Make delegation configurable per project
4. **Logging**: Log delegation decisions for debugging
5. **Error Handling**: Handle tool failures gracefully

## Performance Considerations

The delegation system uses nim-testkit's performance framework when available:
- LRU caching for tool discovery results
- Profiling for delegation overhead
- Parallel execution support

## Troubleshooting

### Common Issues

1. **Tool Not Found**
   - Check PATH for the delegated tool
   - Verify tool installation
   - Check delegation configuration

2. **Delegation Loop**
   - Ensure tools don't delegate back to niuv
   - Check circular dependencies in configuration

3. **Performance Issues**
   - Enable caching for tool discovery
   - Use priority-based selection
   - Profile delegation overhead

### Debug Mode

Enable detailed delegation logging:

```bash
# Verbose delegation info
NIUV_DELEGATION_DEBUG=1 niuv build

# Trace all delegation decisions
NIUV_TRACE=1 niuv test
```