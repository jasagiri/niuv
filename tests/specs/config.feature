Feature: Configuration Management
  As a Nim developer
  I want to configure my Niuv environment
  So that I can customize behavior for my projects

  Background:
    Given I have Niuv installed
    And I am in a project directory

  Scenario: Load default configuration
    When I run "niuv config show"
    Then the default configuration should be displayed
    And all configuration values should have defaults
    And the command should complete successfully

  Scenario: Create configuration file
    When I run "niuv config init"
    Then a "niuv.toml" configuration file should be created
    And the file should contain default settings
    And the command should complete successfully
    
  Scenario: Create user configuration file
    When I run "niuv config init --user"
    Then a global user configuration file should be created
    And the file should contain default settings
    And the command should complete successfully

  Scenario: Set configuration value
    When I run "niuv config set parallelJobs 4"
    Then the configuration value should be updated
    And the updated value should be saved to the configuration file
    And the command should complete successfully

  Scenario: Get configuration value
    Given a configuration with "parallelJobs" set to "4"
    When I run "niuv config get parallelJobs"
    Then the output should be "4"
    And the command should complete successfully

  Scenario: Configuration precedence
    Given a user configuration with "parallelJobs" set to "2"
    And a project configuration with "parallelJobs" set to "4"
    When I run "niuv config get parallelJobs"
    Then the output should be "4"
    And the command should complete successfully

  Scenario: Override configuration with environment variables
    Given a configuration with "parallelJobs" set to "4"
    When I set environment variable "NIUV_PARALLEL_JOBS" to "6"
    And I run "niuv config get parallelJobs"
    Then the output should be "6"
    And the command should complete successfully

  Scenario: Override configuration with command line
    Given a configuration with "parallelJobs" set to "4"
    When I run "niuv --parallel-jobs=8 config get parallelJobs"
    Then the output should be "8"
    And the command should complete successfully

  Scenario: List all configuration
    When I run "niuv config list"
    Then all configuration variables should be listed
    And their current values should be displayed
    And the command should complete successfully

  Scenario: Reset configuration
    Given a custom configuration
    When I run "niuv config reset"
    Then the configuration should be reset to defaults
    And the command should complete successfully

  Scenario: Invalid configuration value
    When I run "niuv config set parallelJobs invalid"
    Then an error should be displayed
    And the configuration should not be updated
    And the command should fail with non-zero status