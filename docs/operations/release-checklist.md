# Release Checklist for niuv

## Pre-release Verification

### 1. Build Tests
- [ ] Debug build: `nimble build`
- [ ] Release build: `nimble build -d:release`
- [ ] Test build: `nimble test`

### 2. Configuration Verification
- [ ] nim.cfg (minimal)
- [ ] config.nims (dynamic profiles)
- [ ] nimble.cfg (minimal)
- [ ] nimtestkit.toml (test configuration)

### 3. Documentation
- [ ] README.md updated
- [ ] CHANGELOG.md updated
- [ ] API documentation generated
- [ ] Configuration guide available

### 4. Clean Project State
- [ ] No temporary files in root
- [ ] Build artifacts in build/ directory
- [ ] .gitignore properly configured

### 5. Version Information
- [ ] Version bumped in niuv.nimble
- [ ] Version constant updated in src/niuv.nim

## Release Process

1. Run full test suite
2. Build release binary
3. Generate documentation
4. Create git tag
5. Build distribution packages
6. Update release notes