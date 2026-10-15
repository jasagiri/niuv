# TDD Cycle Command

## Description
Complete Test-Driven Development cycle implementation for modern-dev-env.

## Usage
```bash
/tdd-cycle [component_name]
```

## TDD Cycle Steps

### Red Phase (Write Failing Test)
1. **Understand Requirements**
   - Analyze feature requirements
   - Identify edge cases
   - Define success criteria

2. **Write Failing Test**
   - Create test file in appropriate directory
   - Write test that captures the requirement
   - Ensure test fails initially (Red)

3. **Verify Test Failure**
   - Run test suite to confirm failure
   - Check failure message is meaningful
   - Validate test logic

### Green Phase (Make Test Pass)
1. **Minimal Implementation**
   - Write simplest code to make test pass
   - Focus on functionality, not optimization
   - Avoid over-engineering

2. **Verify Test Success**
   - Run test suite to confirm all tests pass
   - Check for any side effects
   - Validate behavior meets requirements

### Refactor Phase (Improve Quality)
1. **Code Quality Improvement**
   - Remove duplication
   - Improve naming and structure
   - Optimize performance if needed

2. **Maintain Test Success**
   - Run tests after each refactoring step
   - Ensure no regressions introduced
   - Keep all tests passing

3. **Documentation Update**
   - Update code comments
   - Update API documentation
   - Record design decisions

## Quality Gates
- [ ] Test written and initially failing
- [ ] Implementation makes test pass
- [ ] Code refactored for quality
- [ ] All existing tests still pass
- [ ] Code coverage maintained at 100%
- [ ] Documentation updated

## Integration with modern-dev-env
- Uses nim-testkit for testing framework
- Integrates with plugin validation system
- Follows MECE test organization
- Maintains GodsGolemInc quality standards

## Notes
This command enforces TDD methodology and contributes to the 20% token optimization by replacing repetitive TDD instructions.