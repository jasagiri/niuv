# Workspace Guide

## Overview

Niuv workspaces allow you to manage multiple related packages in a single repository (monorepo). This is particularly useful for large projects with shared dependencies and internal packages.

## Getting Started

### 1. Initialize a Workspace

Create a `niuv.workspace.toml` file in your repository root:

```bash
niuv workspace init packages/* apps/*
```

This creates a workspace configuration with the specified member patterns.

### 2. Workspace Configuration

The `niuv.workspace.toml` file structure:

```toml
[workspace]
# Workspace members - can use glob patterns
members = ["packages/*", "apps/*", "tools/*"]

# Patterns to exclude
exclude = ["packages/deprecated/*"]

# Shared dependencies for all workspace packages
[workspace.dependencies]
chronicles = ">= 0.10.0"
jester = "^0.5.0"
asynctools = "~> 0.1.1"

# Shared dev dependencies
[workspace.devDependencies]
testament = "*"
```

### 3. Member Package Structure

Each workspace member should have its own `.nimble` file:

```
my-workspace/
├── niuv.workspace.toml
├── packages/
│   ├── core/
│   │   ├── core.nimble
│   │   └── src/
│   └── utils/
│       ├── utils.nimble
│       └── src/
└── apps/
    └── server/
        ├── server.nimble
        └── src/
```

## Workspace Commands

### Install Dependencies

Install all dependencies for the entire workspace:

```bash
niuv workspace install
```

This will:
- Resolve all dependencies (shared and package-specific)
- Install them in a shared `nimbledeps` directory at the workspace root
- Create symlinks from each package to the shared dependencies

### Build All Packages

Build all packages in dependency order:

```bash
niuv workspace build
```

Packages are built in topological order, ensuring dependencies are built first.

### Run Tests

Run tests for all workspace packages:

```bash
niuv workspace test
```

### Publish Packages

Publish all non-private packages:

```bash
niuv workspace publish
```

## Features

### 1. Shared Dependencies

Dependencies specified in `[workspace.dependencies]` are available to all workspace members without needing to declare them in individual `.nimble` files.

### 2. Internal Package Dependencies

Workspace members can depend on each other:

```nim
# In apps/server/server.nimble
requires "core >= 0.1.0"  # Internal package
requires "utils >= 0.1.0"  # Internal package
```

### 3. Dependency Resolution

The workspace resolver:
- Handles both internal and external dependencies
- Detects circular dependencies
- Optimizes shared dependencies to avoid duplication

### 4. Parallel Operations

Workspace operations leverage niuv's parallel execution engine for:
- Faster dependency installation
- Concurrent package builds (respecting dependency order)
- Parallel test execution

## Best Practices

### 1. Project Organization

```
workspace/
├── niuv.workspace.toml
├── packages/          # Shared libraries
├── apps/             # Applications
├── tools/            # Development tools
└── docs/             # Documentation
```

### 2. Version Management

- Use consistent versioning across workspace members
- Consider using a version management tool for coordinated releases
- Tag releases at the workspace level

### 3. Dependency Management

- Put truly shared dependencies in `[workspace.dependencies]`
- Keep package-specific dependencies in individual `.nimble` files
- Use exact versions for internal dependencies during development

### 4. CI/CD Integration

```yaml
# Example GitHub Actions workflow
steps:
  - uses: actions/checkout@v3
  - uses: iffy/install-nim@v4
  - run: niuv workspace install
  - run: niuv workspace test
  - run: niuv workspace build
```

## Advanced Usage

### Custom Build Order

While niuv automatically determines build order, you can influence it through dependencies:

```nim
# Force package A to build before package B
# In B's .nimble file:
requires "A >= 0.0.0"  # Even if B doesn't use A
```

### Private Packages

Mark packages as private to prevent publishing:

```nim
# In package.nimble
# TODO: Private package support coming soon
```

### Workspace-level Scripts

Coming soon: Define custom scripts that run across all packages.

## Troubleshooting

### Circular Dependencies

If you get a circular dependency error:
1. Review the dependency graph
2. Consider extracting shared code to a new package
3. Use dependency inversion principles

### Missing Internal Packages

Ensure:
1. The package directory matches the glob patterns in `members`
2. The package has a valid `.nimble` file
3. The package name in `.nimble` matches dependency declarations

### Build Failures

Check:
1. Build order (dependencies should build first)
2. Shared dependency compatibility
3. Nim version compatibility across packages