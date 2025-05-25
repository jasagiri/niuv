# niuv Tests

This directory contains the test suite for niuv.

## Test Organization

- `test_all.nim` - Main test runner that imports selected test modules
- `test_*_minimal.nim` - Minimal test set for quick testing
- `testutils.nim` - Common test utilities

## Running Tests

```bash
# Run all tests (limited set due to dependency issues)
nimble test

# Run a specific test
nim c -r tests/test_fs_utils.nim
```

## Known Issues

Some tests have been excluded from the main test runner due to compilation timeout issues with the parallel module:
- test_cancellation
- test_config
- test_deps
- test_env
- test_install
- test_niuv_testing
- test_parallel
- test_progress
- test_report_generator
- test_retry
- test_run_specific_test
- test_venv

These tests run fine individually but cause hanging when compiled through the testrunner with all tests together.

## Dependencies

The project originally depended on power_assert and cucumber_nim packages, but these have been removed and tests now use the standard unittest framework.