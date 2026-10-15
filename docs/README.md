# niuv Documentation

This directory contains comprehensive documentation for niuv, organized using MECE (Mutually Exclusive, Collectively Exhaustive) principles.

## 📚 Documentation Structure

### 1. **user/** - End User Documentation
Documentation for users who want to use niuv.

- `getting-started.md` - Quick start guide
- `workspace-guide.md` - Workspace management
- `testing-guide.md` - Running tests with niuv
- `shellspec-setup.md` - Shell testing setup

### 2. **architecture/** - System Design Documentation
Technical architecture and design decisions.

- `architecture.md` - Overall system architecture
- `project-structure.md` - Directory and file organization
- `config-files.md` - Configuration system overview
- `resolver-implementation.md` - Dependency resolver design

### 3. **development/** - Developer Documentation
For contributors and maintainers.

- `api-reference.md` - API documentation
- `testing-refactor.md` - Test system refactoring
- `parallel-changes.md` - Parallelization implementation
- `implementation-summary.md` - Development progress

### 4. **integration/** - Integration Documentation
How niuv integrates with other tools.

- `nim-testkit-integration.md` - nim-testkit integration
- `nim-boilerplate-integration.md` - Boilerplate system
- `jujutsu-integration.md` - Jujutsu VCS support
- `vendor-packages.md` - Vendored dependencies

### 5. **analysis/** - Analysis and Reports
Studies, comparisons, and technical analysis.

- `niuv-vs-nimble-specification.md` - Comparison with Nimble
- `coverage-analysis/` - Coverage implementation analysis
  - `coverage-implementation.md`
  - `coverage-limitations.md`
  - `coverage-mece-analysis.md`
  - `coverage-technical-issues.md`

### 6. **operations/** - Operational Documentation
Release, deployment, and operational guides.

- `release-checklist.md` - Release process checklist
- `release-status.md` - Current release status
- `release-integration.md` - Release automation
- `config-consolidation-summary.md` - Configuration updates

### 7. **planning/** - Planning and Roadmap
Future plans and migration strategies.

- `reporting-migration-plan.md` - Reporting system migration

## 🔍 Finding Documentation

- **New to niuv?** Start with [`user/getting-started.md`](user/getting-started.md)
- **Contributing?** Read [`development/api-reference.md`](development/api-reference.md)
- **System design?** See [`architecture/architecture.md`](architecture/architecture.md)
- **Release process?** Check [`operations/release-checklist.md`](operations/release-checklist.md)

## 📝 Documentation Standards

- Use clear, descriptive filenames
- Include a table of contents for long documents
- Add code examples where relevant
- Keep documents focused on a single topic
- Update the index when adding new documents