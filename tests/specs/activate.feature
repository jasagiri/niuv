Feature: Environment Activation
  As a Nim developer
  I want to activate and deactivate virtual environments
  So that I can work with specific project dependencies

  Background:
    Given I have Niuv installed
    And I have initialized a virtual environment
    And I am in the project directory

  Scenario: Generate activation scripts
    When I initialize a virtual environment
    Then an "activate" script should be created for Unix
    And an "activate.bat" script should be created for Windows
    And the scripts should have appropriate permissions

  Scenario: Activate with shell integration
    Given I have set up shell integration
    When I run "niuv activate"
    Then the environment should be activated
    And the environment variables should be updated
    And the prompt should indicate the active environment

  Scenario: Manual activation instruction
    Given I have not set up shell integration
    When I run "niuv activate"
    Then I should see instructions on how to activate the environment
    And the instructions should include the path to the activation script

  Scenario: Start new shell with environment
    When I run "niuv shell"
    Then a new shell should be started
    And the environment should be activated in the new shell
    And the prompt should indicate the active environment

  Scenario: Run command in environment
    When I run "niuv run nim --version"
    Then the command should be executed with environment variables set
    And the output should include the Nim version
    And the command should use the local nimbledeps directory

  Scenario: Setup shell integration
    When I run "niuv setup"
    Then shell integration should be configured
    And I should see instructions for completing the setup
    And the configuration should be saved
