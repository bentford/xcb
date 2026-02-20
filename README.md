# xcb

A command-line tool that brings Xcode build, test, and run workflows to the terminal. Quickly switch between schemes, run tests with coverage reports, and launch apps on simulators — without leaving your shell.

Born out of frustration with a large Xcode project containing hundreds of schemes, where constantly switching between builds, tests, and simulators in the IDE was painfully slow. `xcb` makes it easy to repeat commands, jump between schemes, and get fast feedback from the command line.

## Features

- **Build & Run** — Build schemes and launch apps on simulators directly from the terminal
- **Test with Coverage** — Run tests with color-coded coverage reports, with file-level detail
- **Scheme Switching** — Save defaults to `.xcbrc` and override per-command with `-s`
- **Smart Error Parsing** — Extracts compiler, linker, and test errors with file locations and line numbers
- **Simulator Management** — Auto-boots simulators, installs and launches your app
- **Dry Run** — Preview the exact `xcodebuild` commands before executing

## Quick Start

```bash
# One-time setup: pick your workspace, scheme, and simulator
xcb select workspace
xcb select scheme
xcb select iphone

# Build and run
xcb build run
```

Your selections are saved to `.xcbrc` so you don't need to specify them again. Override any time with flags:

```bash
xcb build run -s DifferentScheme -i "iPhone 16" -o 18.0
```

## Examples

### Build

```bash
# Build the current scheme
xcb build

# Build a specific scheme
xcb build -s MyApp

# Clean build
xcb build -s MyApp --clean
```

### Build and Run

```bash
# Build and launch on the selected simulator
xcb build run

# Build and run a specific scheme
xcb build run -s MyApp
```

### Clean

```bash
# Clean derived data for the current scheme
xcb clean

# Clean a specific scheme
xcb clean -s MyApp
```

### Run Only (skip build)

```bash
# Re-launch the last built app without rebuilding
xcb run -s MyApp
```

### Test

```bash
# Run all tests
xcb test -s MyApp

# Run a specific test class
xcb test -s MyApp --only MyTests/LoginTests

# Run a single test method
xcb test -s MyApp --only MyTests/LoginTests/testValidCredentials
```

### Test with Coverage

```bash
# Run tests and show a coverage summary
xcb test coverage -s MyApp

# Include file-level coverage breakdown
xcb test coverage -s MyApp --detailed

# Coverage for a specific test class
xcb test coverage -s MyApp --only MyTests/LoginTests
```

### Show Coverage Without Building

```bash
# Report on the most recent test results without rebuilding
xcb test coverage -s MyApp --skip-build
```

### View Test Errors

```bash
# Show errors and failures from the last test run
xcb test errors -s MyApp
```

### Cleanup

```bash
# Remove xcresult bundles from /tmp
xcb purge

# Skip confirmation
xcb purge --force
```

### Dry Run

Preview commands without executing them:

```bash
xcb build run -s MyApp --dry-run
xcb test coverage -s MyApp --dry-run
```

## Configuration

### Interactive Setup

```bash
xcb select workspace              # Pick from .xcworkspace files in the current directory
xcb select scheme                 # Pick from available schemes
xcb select scheme --filter Auth   # Filter the scheme list
xcb select iphone                 # Pick a simulator and iOS version
```

### `.xcbrc`

Selections are stored in `.xcbrc` in your project directory:

```bash
WORKSPACE="MyApp.xcworkspace"
SCHEME="MyApp"
IPHONE_NAME="iPhone 16"
OS_VERSION="18.0"
```

Command-line flags (`-s`, `-w`, `-i`, `-o`) override these defaults for a single invocation.

## Command Reference

| Command | Description |
|---|---|
| `xcb select workspace` | Choose default workspace |
| `xcb select scheme` | Choose default scheme |
| `xcb select iphone` | Choose default simulator |
| `xcb build` | Build the scheme |
| `xcb build run` | Build and launch on simulator |
| `xcb run` | Launch last built app (no rebuild) |
| `xcb clean` | Clean derived data for a scheme |
| `xcb test` | Run tests |
| `xcb test coverage` | Run tests with coverage report |
| `xcb test errors` | Show errors from last test run |
| `xcb purge` | Remove xcresult bundles from /tmp |

### Flags

| Flag | Description |
|---|---|
| `-s`, `--scheme` | Xcode scheme name |
| `-w`, `--workspace` | Xcode workspace path |
| `-i`, `--iphone` | Simulator name (e.g. `"iPhone 16"`) |
| `-o`, `--os-version` | iOS version (e.g. `18.0`) |
| `--only` | Run specific test (`Target/Class[/method]`) |
| `--detailed` | Show file-level coverage breakdown |
| `--skip-build` | Report coverage from last build |
| `--clean` | Clean before building |
| `--dry-run` | Show commands without executing |
| `--force` | Skip confirmation prompts |
| `--filter` | Filter scheme list during selection |

## Requirements

- macOS with Xcode installed
- Xcode Command Line Tools (`xcode-select --install`)

## License

MIT
