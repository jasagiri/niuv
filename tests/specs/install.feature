Feature: Package Installation
  As a developer
  I want to manage package installations
  So that I can ensure all dependencies are correctly installed

  Scenario: Install single package
    Given a valid package name "testpkg"
    When I install the package
    Then it should be installed in the nimbledeps directory
    And the package cache should be updated

  Scenario: Install package with version
    Given a package "testpkg" with version "1.0.0"
    When I install the package with version
    Then version "1.0.0" should be installed
    And the package should be cached

  Scenario: Install from cache
    Given a cached package "testpkg" version "1.0.0"
    When I install the package
    Then it should use the cached version
    And not download from remote

  Scenario: Parallel installation
    Given 3 packages to install with no dependencies
    When I install them in parallel
    Then all packages should be installed
    And installation time should be faster than sequential

  Scenario: Failed installation
    Given an invalid package name "invalid_pkg"
    When I try to install it
    Then it should return an error
    And the error should be properly logged

  Scenario: Sync with lockfile
    Given a valid lockfile with 3 packages
    And 2 packages are already installed
    When I sync with the lockfile
    Then the missing package should be installed
    And no extra packages should be removed

  Scenario: Version mismatch warning
    Given a lockfile with package "testpkg" version "1.0.0"
    And installed package "testpkg" version "0.9.0"
    When I sync with the lockfile
    Then it should show version mismatch warning
    And the package should not be updated

  Scenario: Force sync with version mismatch
    Given a lockfile with package "testpkg" version "1.0.0"
    And installed package "testpkg" version "0.9.0"
    When I force sync with the lockfile
    Then it should update to version "1.0.0"
    And the lockfile checksum should be updated

  Scenario: Remove extra packages
    Given a lockfile with 2 packages
    And 3 packages are installed
    When I sync with the lockfile
    Then the extra package should be removed
    And the installed packages should match lockfile

  Scenario: Sync with missing lockfile
    Given no lockfile exists
    When I try to sync
    Then it should return an error
    And suggest creating a lockfile first
