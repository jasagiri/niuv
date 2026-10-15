Feature: Cleaning Project Artifacts
  As a Nim developer
  I want to clean build artifacts from my project
  So that I can ensure a fresh build environment

  Background:
    Given I have Niuv installed
    And I am in a project directory

  Scenario: Clean basic build artifacts
    Given build artifacts exist in the project
    When I run "niuv clean"
    Then the "build" directory should be removed
    And the "nimcache" directory should be removed
    And the command should complete successfully

  Scenario: Run clean in dry-run mode
    Given build artifacts exist in the project
    When I run "niuv clean --dry-run"
    Then I should see what would be cleaned
    But no files should actually be removed
    And the command should complete successfully

  Scenario: Clean with verbose output
    Given build artifacts exist in the project
    When I run "niuv clean --verbose"
    Then I should see detailed information about cleaned files
    And all build artifacts should be removed
    And the command should complete successfully

  Scenario: Clean only specific directories
    Given build artifacts exist in the project
    When I run "niuv clean --only=nimcache"
    Then the "nimcache" directory should be removed
    But the "build" directory should remain intact
    And the command should complete successfully

  Scenario: Clean in a project with no artifacts
    Given no build artifacts exist in the project
    When I run "niuv clean"
    Then I should see a message indicating nothing to clean
    And the command should complete successfully

  Scenario: Full clean of all artifacts
    Given build artifacts and temporary files exist
    When I run "niuv clean --full"
    Then all build artifacts should be removed
    And all temporary files should be removed
    And the command should complete successfully

  Scenario: Custom clean path
    Given build artifacts exist in a custom location
    When I run "niuv clean --path=/custom/path"
    Then build artifacts in the custom path should be removed
    And the command should complete successfully