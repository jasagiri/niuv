Feature: Building Nim Projects
  As a Nim developer
  I want to build my Nim projects
  So that I can create executables and run tests efficiently

  Background:
    Given I have Niuv installed
    And I am in a project directory

  Scenario: Build main executable
    When I run "niuv build"
    Then the main executable should be created in the build directory
    And the executable should be runnable
    And the build should complete successfully

  Scenario: Build with release optimization
    When I run "niuv build --release"
    Then the executable should be built with release optimizations
    And the executable size should be smaller than debug build
    And the build should complete successfully

  Scenario: Build with debug information
    When I run "niuv build --debug"
    Then the executable should be built with debug information
    And debugging symbols should be present
    And the build should complete successfully

  Scenario: Build with custom defines
    When I run "niuv build --define:CUSTOM_FEATURE"
    Then the executable should be built with the custom define
    And the CUSTOM_FEATURE should be active when running
    And the build should complete successfully

  Scenario: Build tests
    When I run "niuv build --tests"
    Then all test executables should be built
    And the test executables should be runnable
    And the build should complete successfully

  Scenario: Build examples
    When I run "niuv build --examples"
    Then example executables should be built
    And the example executables should be runnable
    And the build should complete successfully

  Scenario: Build all
    When I run "niuv build --all"
    Then the main executable should be built
    And all test executables should be built
    And all example executables should be built
    And the build should complete successfully

  Scenario: Build with nimcache customization
    When I run "niuv build --nimcache=/custom/path"
    Then the nimcache should be created at the custom path
    And the executable should be built using the custom nimcache
    And the build should complete successfully

  Scenario: Failed build with compilation errors
    Given source code with compilation errors
    When I run "niuv build"
    Then the build should fail
    And error messages should be displayed
    And no executable should be created