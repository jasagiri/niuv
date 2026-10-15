# Release Process Integration with nim-testkit

## Overview

The release process for niuv has been integrated with nim-testkit's standardized release management system. This provides a consistent, automated approach to releasing Nim projects.

## Architecture

### 1. nim-testkit Release Manager (`nim-testkit/src/release/manager.nim`)

Provides comprehensive release management functionality:
- Pre-release checks (tests, coverage, documentation, git status)
- Version bumping (semantic versioning support)
- Release artifact generation
- Release notes generation
- Git operations (branching, tagging)

### 2. CLI Integration (`nim-testkit/src/cli/release.nim`)

Command-line interface for release operations:
```bash
ntk release check              # Run pre-release checks
ntk release prepare <type>     # Prepare release
ntk release execute <type>     # Execute full release process
ntk release report             # Generate release report
```

### 3. niuv Integration (`niuv/scripts/release.nim`)

Wrapper script that uses nim-testkit's release commands:
- Provides niuv-specific configuration
- Sets appropriate coverage thresholds
- Integrates with nimble tasks

## Usage

### Running Release Checks

```bash
# Via nimble task
nimble releaseCheck

# Via script directly
nim r scripts/release.nim check
```

### Preparing a Release

```bash
# Patch release (0.0.x)
nimble releasePatch

# Minor release (0.x.0)
nimble releaseMinor

# Major release (x.0.0)
nimble releaseMajor
```

### Generating Release Report

```bash
nimble releaseReport
```

## Release Checks

The following checks are performed:

1. **Build Check** (Critical)
   - Debug build must succeed
   - Release build must succeed

2. **Test Suite** (Critical)
   - All tests must pass
   - No failing test cases

3. **Code Coverage**
   - Must meet threshold (75% for niuv)
   - Coverage report generated

4. **Documentation**
   - README.md must exist
   - CHANGELOG.md must exist
   - LICENSE must exist

5. **Git Status** (Critical)
   - Working directory must be clean
   - No uncommitted changes

6. **License Check** (Critical)
   - Valid license file required

## Release Types

- **patch**: Bug fixes, minor updates (0.0.x)
- **minor**: New features, backwards compatible (0.x.0)
- **major**: Breaking changes (x.0.0)
- **alpha**: Alpha pre-release (x.y.z-alpha.n)
- **beta**: Beta pre-release (x.y.z-beta.n)
- **rc**: Release candidate (x.y.z-rc.n)

## Benefits

1. **Standardization**: All Nim projects use the same release process
2. **Automation**: Reduces manual steps and potential errors
3. **Validation**: Ensures quality checks before release
4. **Documentation**: Automatic generation of release notes and reports
5. **Flexibility**: Customizable checks and thresholds per project

## Future Enhancements

1. **CI/CD Integration**: GitHub Actions, GitLab CI support
2. **Package Registry**: Automatic publishing to nimble directory
3. **Changelog Generation**: Automatic CHANGELOG.md updates
4. **Version Tagging**: Semantic version management
5. **Distribution**: Cross-platform binary generation

## Configuration

Projects can customize release behavior through:
- Coverage thresholds
- Required documentation files
- Build profiles
- Test patterns
- Artifact generation

This integration demonstrates how nim-testkit can provide standardized tooling for the entire Nim ecosystem, making releases more reliable and consistent across projects.