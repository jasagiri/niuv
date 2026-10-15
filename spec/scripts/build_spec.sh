#!/bin/bash
# ShellSpec tests for build.sh

Describe 'build.sh'
  Include spec_helper.sh
  
  # Path to the script being tested
  BUILD_SCRIPT="$SHELLSPEC_PROJECT_ROOT/scripts/build.sh"
  
  BeforeEach 'setup_test_environment'
  AfterEach 'cleanup'
  
  setup_test_environment() {
    # Create test project
    export TEST_PROJECT=$(create_test_project)
    cd "$TEST_PROJECT"
    
    # Mock nim if needed
    mock_nim
  }
  
  Describe 'help command'
    It 'shows help with --help flag'
      When run script "$BUILD_SCRIPT" --help
      The status should be success
      The output should include "Unified Build Script for niuv"
      The output should include "Usage:"
      The output should include "Targets:"
      The output should include "Options:"
    End
    
    It 'shows help with -h flag'
      When run script "$BUILD_SCRIPT" -h
      The status should be success
      The output should include "Unified Build Script for niuv"
    End
    
    It 'shows help with help target'
      When run script "$BUILD_SCRIPT" help
      The status should be success
      The output should include "Unified Build Script for niuv"
    End
  End
  
  Describe 'argument parsing'
    It 'accepts valid targets'
      When run script "$BUILD_SCRIPT" examples
      The status should be success
      The output should include "Building example files"
    End
    
    It 'rejects invalid targets'
      When run script "$BUILD_SCRIPT" invalid_target
      The status should be failure
      The error should include "Unknown option: invalid_target"
    End
    
    It 'accepts debug mode flag'
      When run script "$BUILD_SCRIPT" main --debug
      The status should be success
      The output should include "Building main niuv executable in debug mode"
    End
    
    It 'accepts release mode flag'
      When run script "$BUILD_SCRIPT" main --release
      The status should be success
      The output should include "Building main niuv executable in release mode"
    End
    
    It 'defaults to all target'
      When run script "$BUILD_SCRIPT"
      The status should be success
      The output should include "Building main niuv executable"
      The output should include "Building example files"
      The output should include "Building test files"
    End
  End
  
  Describe 'build targets'
    Describe 'all target'
      It 'builds everything'
        When run script "$BUILD_SCRIPT" all
        The status should be success
        The output should include "Building main niuv executable"
        The output should include "Building example files"
        The output should include "Building test files"
        The output should include "Build process completed successfully"
      End
      
      It 'creates build directories'
        When run script "$BUILD_SCRIPT" all
        The status should be success
        Path build/debug/bin should be directory
        Path build/debug/tests should be directory
        Path build/debug/examples should be directory
        Path build/nimcache should be directory
      End
    End
    
    Describe 'main target'
      It 'builds main executable only'
        When run script "$BUILD_SCRIPT" main
        The status should be success
        The output should include "Building main niuv executable"
        The output should not include "Building example files"
        The output should not include "Building test files"
      End
      
      It 'creates main executable'
        When run script "$BUILD_SCRIPT" main
        The status should be success
        Path build/debug/bin/niuv should exist
      End
    End
    
    Describe 'examples target'
      It 'builds examples only'
        When run script "$BUILD_SCRIPT" examples
        The status should be success
        The output should include "Building example files"
        The output should not include "Building main niuv executable"
        The output should not include "Building test files"
      End
      
      It 'processes all example files'
        When run script "$BUILD_SCRIPT" examples
        The status should be success
        The output should include "Examples: 1/1 compiled successfully"
      End
    End
    
    Describe 'tests target'
      It 'builds tests only'
        When run script "$BUILD_SCRIPT" tests
        The status should be success
        The output should include "Building test files"
        The output should not include "Building main niuv executable"
        The output should not include "Building example files"
      End
      
      It 'processes all test files'
        When run script "$BUILD_SCRIPT" tests
        The status should be success
        The output should include "Tests: 1/1 compiled successfully"
      End
    End
    
    Describe 'clean target'
      It 'removes build artifacts'
        mkdir -p build/debug/bin build/release/bin nimcache
        touch build/debug/bin/niuv
        When run script "$BUILD_SCRIPT" clean
        The status should be success
        The output should include "Cleaning build artifacts"
        The output should include "Build artifacts cleaned"
        Path build should not exist
        Path nimcache should not exist
      End
    End
  End
  
  Describe 'error handling'
    It 'fails when not in project root'
      cd /tmp
      When run script "$BUILD_SCRIPT"
      The status should be failure
      The error should include "Must be run from project root"
    End
    
    It 'handles compilation failures'
      # Create a file that will fail compilation
      echo 'echo "fail"' > "$TEST_PROJECT/tests/test_fail.nim"
      When run script "$BUILD_SCRIPT" tests
      The status should be failure
      The output should include "Failed to compile test_fail"
      The error should include "Some tests failed to compile"
    End
    
    It 'reports build statistics correctly'
      # Add another example
      echo 'echo "example2"' > "$TEST_PROJECT/examples/example2.nim"
      When run script "$BUILD_SCRIPT" examples
      The status should be success
      The output should include "Examples: 2/2 compiled successfully"
    End
  End
  
  Describe 'build modes'
    It 'applies debug flags correctly'
      When run script "$BUILD_SCRIPT" main --debug
      The status should be success
      The error should include "--nimcache:build/nimcache"
      The error should not include "-d:release"
    End
    
    It 'applies release flags correctly'
      When run script "$BUILD_SCRIPT" main --release
      The status should be success
      The error should include "--nimcache:build/nimcache"
      The error should include "-d:release"
    End
    
    It 'creates mode-specific output directories'
      When run script "$BUILD_SCRIPT" main --release
      The status should be success
      Path build/release/bin/niuv should exist
      
      When run script "$BUILD_SCRIPT" main --debug
      The status should be success
      Path build/debug/bin/niuv should exist
    End
  End
End