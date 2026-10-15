# Test Workflow Command

## Description
Complete testing workflow for modern-dev-env including unit tests, integration tests, and plugin validation.

## Usage
```bash
/test-workflow [component]
```

## Steps
1. **Environment Check**
   - Verify development environment setup
   - Check all dependencies are installed
   - Validate configuration files

2. **Unit Testing**
   - Run all unit tests with nim-testkit
   - Verify 100% test coverage
   - Check for test failures or warnings

3. **Integration Testing**
   - Test plugin system integration
   - Verify agent communication
   - Check workspace management

4. **Plugin Validation**
   - Run plugin test suite
   - Verify MECE compliance
   - Check performance metrics

5. **Cleanup**
   - Clean temporary files
   - Reset test environment
   - Generate test report

## Expected Output
- All tests should pass (100% pass rate)
- Coverage should be 100%
- No performance regressions
- Clean plugin validation results

## Notes
This command replaces repetitive testing instructions in CLAUDE.md, contributing to token optimization.