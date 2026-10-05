# Contributing to xcb

xcb is a Swift package with no third-party dependencies. It builds from the command line; you don't need to open Xcode.

## Prerequisites

- **macOS with Xcode 16 or later** (Swift 6.0+)
- **[bats-core](https://github.com/bats-core/bats-core)** for the CLI tests: `brew install bats-core`
- **[xcbeautify](https://github.com/cpisciotta/xcbeautify)** to run real builds and tests with xcb (not needed for the test suites)

## Build

```bash
swift build                  # debug build → .build/debug/xcb
swift build -c release       # optimized build → .build/release/xcb
```

Run it straight from the build folder:

```bash
.build/debug/xcb --version
.build/debug/xcb build --dry-run -s MyApp -w MyApp.xcworkspace --simulator-id <uuid>
```

To use your build as your everyday `xcb`, copy it to the folder `install.sh` installs to:

```bash
swift build -c release && cp .build/release/xcb ~/bin/xcb
```

To work in Xcode instead, run `xed .`, then pick the `xcb` scheme and **My Mac**.

## Test

```bash
swift test                   # unit tests (Swift Testing)
swift build && bats tests/   # CLI tests, run against .build/debug/xcb
```

The bats tests run the binary as a black box, so they check the commands, flags, dry-run output and errors. To test a different binary, set `XCB`, e.g. `XCB=.build/release/xcb bats tests/`.

CI runs the build, unit tests and bats tests on macOS for every pull request (`.github/workflows/test.yml`).

## Project layout

```
Package.swift
Sources/xcb/main.swift       entry point
Sources/XCBCore/             all the logic
  XCB.swift                  startup, shared validation and helpers
  Options.swift              argument parsing and usage text
  App+Build.swift            clean, build, build run, run
  App+Test.swift             test, test coverage, purge
  App+Select.swift           select and setup (interactive pickers)
  Parsers.swift              xcodebuild / simctl / devicectl output parsing
  Coverage.swift             xccov report decoding and formatting
  ConfigFile.swift           .xcbrc reading and writing
  Shell.swift                running commands and piping through xcbeautify
  Updater.swift              --update (checks the latest GitHub Release)
  Version.swift              current version
tests/XCBCoreTests/          Swift unit tests
tests/*.bats                 CLI tests
```

Logic that can be tested without Xcode, like parsing, formatting and config, goes in plain functions with unit tests. The bats tests cover the command line from the outside.

## Releasing

Releases are built and published by GitHub Actions (`.github/workflows/release.yml`) when you push a version tag.

1. Run `scripts/bump-version.sh` to bump the patch version in both `VERSION` and `Sources/XCBCore/Version.swift`. Use `--revert-version` to undo it. For a minor or major bump, edit both files by hand.
2. In `CHANGELOG.md`, rename `## [Unreleased]` to the new version (e.g. `## [0.2.0]`). That section becomes the release notes.
3. Commit, open a PR and merge to `main`.
4. Tag the merge commit and push the tag:

   ```bash
   git checkout main && git pull
   git tag v0.2.0
   git push origin v0.2.0
   ```

The workflow then:
- checks that the tag matches `VERSION` and `Version.swift`
- runs the unit tests
- builds a universal (arm64 + x86_64) binary
- publishes a GitHub Release with `xcb-macos-universal.tar.gz` and its `.sha256` checksum

`install.sh` and `xcb --update` always download the latest release, so a release reaches users as soon as it's published.

To try the release build locally:

```bash
swift build -c release --arch arm64 --arch x86_64
lipo -info "$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/xcb"
```
