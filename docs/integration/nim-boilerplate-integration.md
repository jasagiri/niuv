# Nim Boilerplate Integration

This document describes the integration between Niuv and nim_boilerplate.

## Overview

Niuv is integrated with nim_boilerplate to provide a seamless project generation and package management experience. The integration has two main components:

1. **nim_boilerplate uses Niuv as default package manager**: When creating a project with nim_boilerplate, Niuv is used as the default package manager, replacing nimble.
2. **Niuv can generate projects using nim_boilerplate**: Niuv includes a `generate` command that uses nim_boilerplate to create new projects.

## nim_boilerplate Changes

nim_boilerplate has been modified to support Niuv as a package manager:

- Added a `PackageManager` enum with `pmNiuv` and `pmNimble` options
- Made Niuv the default package manager
- Added the `--pkg-manager` option to allow selecting the package manager
- Modified the .nimble file template to use Niuv for task execution
- Added generation of a niuv.toml configuration file

## Niuv Changes

Niuv has been extended to support nim_boilerplate:

- Added the `generate` command to create projects using nim_boilerplate
- Added nim_boilerplate project detection
- Extended CliOptions to support project generation parameters
- Added utility functions for working with nim_boilerplate

## Using the Integration

### Creating a Project with nim_boilerplate

```bash
nim_boilerplate init my_project
```

This will create a new project with Niuv as the package manager. To use nimble instead:

```bash
nim_boilerplate init my_project --pkg-manager=nimble
```

### Creating a Project with Niuv

```bash
niuv generate my_project --desc="My project description" --author="Your Name"
```

Options:
- `--desc`: Project description
- `--author`: Project author
- `--license`: Project license (default: MIT)
- `--dir`: Directory to create the project in (default: project name)

### Working with the Project

After creating a project:

```bash
cd my_project
niuv init     # Initialize the Niuv environment
source ./activate   # Activate the environment
nimble build  # Run the build task using Niuv
```

## nimble Tasks with Niuv

The integration replaces standard nimble task execution with Niuv-powered alternatives:

```nimble
task build, "Build the project":
  when defined(windows):
    exec "niuv run scripts\\build.bat"
  else:
    exec "niuv run sh scripts/build.sh"
```

This approach provides better isolation and dependency management while maintaining the familiar nimble interface.

## Additional Features

- **Automatic Project Detection**: Niuv automatically detects projects created with nim_boilerplate
- **Environment Variables**: Configuration can be provided via environment variables
- **Customization**: All aspects of the integration can be customized

## Future Improvements

- Add more project templates
- Improve error handling and reporting
- Add integration tests
- Support for additional package managers