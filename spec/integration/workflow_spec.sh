#!/bin/bash
# Integration tests for complete workflows

Describe 'Integration workflows'
  Include spec_helper.sh
  
  BUILD_SCRIPT="$SHELLSPEC_PROJECT_ROOT/scripts/build.sh"
  TEST_SCRIPT="$SHELLSPEC_PROJECT_ROOT/scripts/test.sh"
  
  BeforeEach 'setup_integration_test'
  AfterEach 'cleanup'
  
  setup_integration_test() {
    export TEST_PROJECT=$(create_test_project)
    cd "$TEST_PROJECT"
    mock_nim
  }
  
  Describe 'full build and test workflow'
    It 'can build and then test'
      # First build
      When run script "$BUILD_SCRIPT" all
      The status should be success
      The output should include "Build process completed successfully"
      
      # Create mock test executables from build
      for test in build/debug/tests/*; do
        if [[ -f "$test" ]]; then
          cat > "$test" << 'EOF'
#!/bin/bash
echo "Test $(basename $0) passed"
exit 0
EOF
          chmod +x "$test"
        fi
      done
      
      # Then test
      When run script "$TEST_SCRIPT" --no-build
      The status should be success
      The output should include "All tests passed!"
    End
    
    It 'can clean, build, and test'
      # Create some old artifacts
      mkdir -p build/old nimcache/old
      touch build/old/artifact nimcache/old/cache
      
      # Clean
      When run script "$BUILD_SCRIPT" clean
      The status should be success
      Path build should not exist
      Path nimcache should not exist
      
      # Build
      When run script "$BUILD_SCRIPT" tests
      The status should be success
      
      # Test
      When run script "$TEST_SCRIPT" --no-build
      The status should be success
    End
  End
  
  Describe 'release workflow'
    It 'can build everything in release mode'
      When run script "$BUILD_SCRIPT" all --release
      The status should be success
      Path build/release/bin/niuv should exist
      The error should include "-d:release"
    End
    
    It 'separates debug and release builds'
      # Build debug
      When run script "$BUILD_SCRIPT" main --debug
      The status should be success
      Path build/debug/bin/niuv should exist
      
      # Build release
      When run script "$BUILD_SCRIPT" main --release
      The status should be success
      Path build/release/bin/niuv should exist
      
      # Both should exist
      Path build/debug/bin/niuv should exist
      Path build/release/bin/niuv should exist
    End
  End
  
  Describe 'error recovery workflow'
    It 'can recover from partial builds'
      # Simulate partial build by creating some directories
      mkdir -p build/debug/bin
      # But not others
      
      When run script "$BUILD_SCRIPT" all
      The status should be success
      Path build/debug/tests should be directory
      Path build/debug/examples should be directory
    End
    
    It 'handles test failures gracefully'
      # Build first
      When run script "$BUILD_SCRIPT" tests
      The status should be success
      
      # Create a failing test
      cat > build/debug/tests/test_example << 'EOF'
#!/bin/bash
echo "This test fails" >&2
exit 1
EOF
      chmod +x build/debug/tests/test_example
      
      # Run tests - should fail but gracefully
      When run script "$TEST_SCRIPT" --no-build
      The status should be failure
      The output should include "test_example FAILED"
      The output should include "Some tests failed"
      The error should not include "command not found"
    End
  End
  
  Describe 'coverage workflow'
    It 'can build and test with coverage'
      # Mock coverage tools
      cat > "$TEST_TEMP_DIR/gcov" << 'EOF'
#!/bin/bash
echo "Generated coverage for $*"
touch coverage.gcov
exit 0
EOF
      chmod +x "$TEST_TEMP_DIR/gcov"
      
      # Build with coverage
      When run script "$BUILD_SCRIPT" tests
      The status should be success
      
      # Test with coverage
      When run script "$TEST_SCRIPT" --coverage --no-build
      The output should include "Coverage reporting enabled"
      The output should include "Generating coverage report"
    End
  End
End