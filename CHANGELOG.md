# Changelog

All notable changes to the Niuv project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Configuration consolidation using nim-configkit and nim-testkit
- Dynamic build profiles (debug, release, test, benchmark)
- Minimal configuration files with profile-based settings
- Configuration manager for unified configuration handling
- Integration with nim-testkit for test management
- Delegation architecture for nimble replacement functionality
- Command implementations for build, test, and package management
- Support for workspace management
- Parallel task execution capabilities

### Changed
- Reduced configuration files from multiple nim.cfg to minimal set
- Moved build artifacts to organized build/ directory structure
- Updated test framework to use nim-testkit integration

### Fixed
- Import path issues in test files
- Configuration file organization and redundancy
- Build output directory structure

## [0.1.0] - 2025-05-10

### Added
- Initial release of Niuv
- Core environment management functionality
- Package installation with parallel processing
- Dependency management with lockfile support
- Shell integration for easy activation
- Cross-platform support (Linux, macOS, Windows)
- Configuration via TOML files
- Comprehensive documentation
- Test suite for all components
EOF < /dev/null