Feature: Virtual Environment Creation and Management
  As a Nim developer
  I want to create and manage isolated environments for my projects
  So that dependencies don't conflict between projects

  Background:
    Given I have Niuv installed
    And I am in a project directory

  Scenario: Initialize a new virtual environment
    When I run "niuv init"
    Then a "nimbledeps" directory should be created
    And a "nim.cfg" file should be created with correct settings
    And activation scripts should be created
    And the command should complete successfully

  Scenario: Initialize with a specific Nim version
    When I run "niuv init --nim-version=1.6.8"
    Then the environment should be configured to use Nim 1.6.8
    And a ".niuv.json" file should be created with the Nim version
    And the command should complete successfully

  Scenario: Initialize in a directory with existing environment
    Given a virtual environment already exists
    When I run "niuv init"
    Then I should see a warning message
    And I should be asked if I want to overwrite the existing environment

  Scenario: Activate virtual environment
    Given I have initialized a virtual environment
    When I run "niuv activate"
    Then I should see instructions to activate the environment
    And the command should complete successfully

  Scenario: Run a command in the virtual environment
    Given I have initialized a virtual environment
    When I run "niuv run echo Hello"
    Then the command should be executed in the virtual environment
    And the output should include "Hello"
    And the command should complete successfully

  Scenario: Start a shell with activated environment
    Given I have initialized a virtual environment
    When I run "niuv shell"
    Then a new shell should be started with the environment activated
    And environment variables should be set correctly
