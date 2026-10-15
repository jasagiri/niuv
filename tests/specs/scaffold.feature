Feature: Project Scaffolding
  As a Nim developer
  I want to scaffold new projects and modules
  So that I can quickly start development with best practices

  Background:
    Given I have Niuv installed
    And I am in a project directory

  Scenario: Scaffold a new module
    When I run "niuv scaffold module mymodule"
    Then a "src/mymodule.nim" file should be created
    And a "tests/test_mymodule.nim" file should be created
    And the module should have proper structure and imports
    And the command should complete successfully

  Scenario: Scaffold a new project
    When I run "niuv scaffold project myproject"
    Then a "myproject" directory should be created
    And all necessary project files should be created
    And a project structure following best practices should be established
    And the command should complete successfully

  Scenario: Scaffold with custom template
    When I run "niuv scaffold module mymodule --template=custom"
    Then a module should be created using the custom template
    And the custom template structure should be applied
    And the command should complete successfully

  Scenario: Scaffold with test generation
    When I run "niuv scaffold module mymodule --with-tests"
    Then a module file should be created
    And comprehensive test files should be created
    And the tests should cover basic functionality
    And the command should complete successfully

  Scenario: Scaffold in existing directory
    Given a directory that already exists
    When I run "niuv scaffold module existingmodule"
    Then I should be prompted for confirmation
    And if confirmed, the module should be created
    And existing files should not be overwritten without confirmation
    And the command should complete successfully

  Scenario: Scaffold with custom author information
    When I run "niuv scaffold project myproject --author='John Doe' --email='john@example.com'"
    Then a project should be created
    And author information should be included in appropriate files
    And the command should complete successfully

  Scenario: Scaffold with license selection
    When I run "niuv scaffold project myproject --license=MIT"
    Then a project should be created
    And an MIT license file should be included
    And the command should complete successfully

  Scenario: Scaffold with Git initialization
    When I run "niuv scaffold project myproject --git-init"
    Then a project should be created
    And Git should be initialized in the project directory
    And a .gitignore file should be included
    And the command should complete successfully

  Scenario: Scaffold a library project
    When I run "niuv scaffold project mylib --type=lib"
    Then a library project should be created
    And appropriate library export structure should be set up
    And the command should complete successfully

  Scenario: Scaffold a binary project
    When I run "niuv scaffold project myapp --type=bin"
    Then a binary application project should be created
    And a proper main entry point should be set up
    And the command should complete successfully