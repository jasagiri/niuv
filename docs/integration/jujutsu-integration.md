# Jujutsu Integration for niuv

## Overview

niuv supports both Git and Jujutsu for version control. While Git is the default for compatibility, Jujutsu can be enabled for a more modern development experience.

## Enabling Jujutsu

### 1. Install Jujutsu

```bash
# Using Cargo
cargo install jj

# Using Homebrew (macOS)
brew install jj

# Verify installation
jj --version
```

### 2. Configure niuv

Edit `niuv.toml`:

```toml
[vcs]
type = "jujutsu"      # Switch from "git" to "jujutsu"
enableJujutsu = true  # Enable Jujutsu features
```

### 3. Initialize Jujutsu (if needed)

For existing Git repositories:

```bash
# Create colocated Jujutsu repo
jj git init --colocate

# This preserves your Git history
# You can still use Git commands
```

For new projects:

```bash
# Initialize new Jujutsu repo
jj init
```

## Using Jujutsu with niuv

### Development Workflow

```bash
# Check status
jj status

# Make changes (automatically tracked)
# No need to stage!

# Describe your change
jj describe -m "Add new feature"

# Create a new change
jj new
```

### Release Process

With Jujutsu enabled:

```bash
# Run release checks
nimble releaseCheck

# Prepare release
nimble releaseMinor

# Execute release
nim r scripts/release.nim execute minor
```

### Benefits

1. **Automatic Commits**
   - Every file save is tracked
   - No lost work
   - Easy experimentation

2. **Better Conflicts**
   - 3-way merge resolution
   - Conflicts as first-class objects
   - No merge commits needed

3. **Operational Safety**
   - Undo any operation
   - Operation log
   - Time travel

## Coexistence with Git

### Colocated Mode

When Jujutsu is initialized with `--colocate`:

```bash
# Jujutsu commands
jj status
jj describe
jj new

# Git commands still work
git status
git log
git push
```

### Pushing to Git Remotes

```bash
# Push current change to Git
jj git push

# Push specific branch
jj git push --branch main
```

## Configuration Examples

### Basic Jujutsu Setup

```toml
# niuv.toml
[vcs]
type = "jujutsu"
enableJujutsu = true

[build]
dir = "build"

[test]
useTestKit = true
```

### Advanced Configuration

```toml
# niuv.toml
[vcs]
type = "jujutsu"
enableJujutsu = true

[jujutsu]
# Custom Jujutsu settings
autoCommit = true
conflictMarkers = "diff3"
```

## Troubleshooting

### Issue: Release checks fail

```bash
# Ensure working copy is clean
jj status

# Create a new change if needed
jj new
```

### Issue: Git compatibility

```bash
# Ensure colocated mode
jj git init --colocate

# Sync with Git
jj git export
```

### Issue: Switching back to Git

```toml
# niuv.toml
[vcs]
type = "git"
enableJujutsu = false
```

## Best Practices

1. **Use Jujutsu for**:
   - Active development
   - Experimental features
   - Complex merges

2. **Use Git for**:
   - CI/CD pipelines
   - Legacy tooling
   - Team compatibility

3. **Hybrid Approach**:
   - Develop with Jujutsu
   - Push to Git remotes
   - Best of both worlds

## Migration Path

### Gradual Adoption

1. Start with Git (default)
2. Enable Jujutsu for personal use
3. Team adoption when ready
4. Full migration optional

### Team Adoption

```bash
# Team member 1 (early adopter)
jj git init --colocate
# Uses Jujutsu

# Team member 2 (traditional)
git pull
# Continues with Git

# Both can collaborate!
```

## Summary

Jujutsu integration in niuv provides:

- **Modern VCS features** while maintaining Git compatibility
- **Seamless switching** between Git and Jujutsu
- **Gradual adoption** path for teams
- **Enhanced developer experience** with automatic commits

Enable Jujutsu when you want a more advanced VCS experience, or stick with Git for maximum compatibility. The choice is yours!