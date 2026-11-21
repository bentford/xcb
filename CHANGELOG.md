# Changelog

All notable changes to xcb are documented here. Versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Changed

- `build run`, `run` and `log` find the app in seconds instead of minutes on large workspaces. xcb used to run `xcodebuild -showBuildSettings` every time, which loads the whole workspace (over a minute on big ones). It now reads the scheme's Run action and the DerivedData folder Xcode created for this exact workspace path, so worktrees of the same repo never pick up each other's builds. When it can't be sure (custom DerivedData or build location, a scheme that doesn't launch an app, or no matching build) it falls back to build settings and remembers the result in `~/Library/Caches/xcb/app-paths.json`. A remembered path is only used while the scheme files and Xcode's location settings are unchanged, and xcb says when it uses one.
- `--skip-build` is now `--last-results`, which says what it does: show the last test coverage results without running tests. `--skip-build` still works.
- `--only` and `--without-building` with `--last-results` now say they're ignored because no tests run, instead of "ignored in coverage action".

### Added

- `--no-fast-app-lookup` always reads build settings to find the app. Set `FAST_APP_LOOKUP="0"` in `.xcbrc` to make it the default, and pass `--fast-app-lookup` to turn it back on for one run.
- `--skip-package-updates` passes `-skipPackageUpdates` to xcodebuild, so it doesn't check remote packages for updates (about 20 s per run on large workspaces). Set `SKIP_PACKAGE_UPDATES="1"` in `.xcbrc` to make it the default, and pass `--no-skip-package-updates` to check anyway.
- `test` and `test coverage` accept `--without-building`, which runs `xcodebuild test-without-building` from the scheme's `.xctestrun` in DerivedData. On a large workspace, rerunning one test went from about 2 minutes to 20 seconds. The first run builds for testing to create the `.xctestrun`; coverage runs only use one built with coverage.

## [0.3.2]

### Fixed

- `build run` and `run` open the active Xcode's simulator app ([#18](https://github.com/bentford/xcb/issues/18)). Xcode 27 replaced Simulator.app with DeviceHub.app, and `open -a Simulator` picked up an older Xcode's Simulator.app instead, which conflicted with DeviceHub and could shut devices down. xcb now opens DeviceHub.app or Simulator.app from the Xcode that `xcode-select` points to.

## [0.3.1]

### Fixed

- `log -c` treats `?` and `\` literally in wildcard categories ([#16](https://github.com/bentford/xcb/issues/16)). Previously a category containing `*` also treated `?` as a single-character wildcard and `\` as an escape character, so `-c 'Cache?*'` matched `CacheStore` and `-c 'Foo\Bar*'` matched `FooBar`. Only `*` is a wildcard now.

### Changed

- The README now documents `select subsystem`, the default subsystem `log` uses, how category matching works, and why to quote wildcard categories.

## [0.3.0]

### Added

- `log` streams the app's debug logs from the simulator ([#14](https://github.com/bentford/xcb/issues/14)). It filters by the app's bundle ID by default, or by `--subsystem`, and by one or more `-c`/`--category` values, which accept `*` wildcards. `--level` sets the log level (`default`, `info`, or `debug`; defaults to `debug`). Physical devices aren't supported.
- `select subsystem` saves a default log subsystem to `.xcbrc` as `LOG_SUBSYSTEM`.

## [0.2.0]

### Changed

- Rewritten in Swift as a Swift package ([#12](https://github.com/bentford/xcb/issues/12)). Commands, flags, `.xcbrc`, and output are unchanged.
- `jq` and `bc` are no longer required; coverage and device JSON are parsed natively.
- `test --skip-build` and other non-coverage actions now ignore `--skip-build` instead of running with an unset destination.
- `install.sh` now installs a prebuilt universal binary from the latest GitHub Release and verifies its checksum. Set `XCB_INSTALL_VERSION` (e.g. `v0.2.0`) to install a specific release.
- `--update` checks the latest GitHub Release instead of the `VERSION` file on `main`.

### Fixed

- `test coverage --detailed` no longer depends on `tac`, which macOS doesn't ship, so the "Bottom 10 Files" list now appears.

## [0.1.2]

### Added

- `-v`/`--version` flag prints the current xcb version.
- `--update` flag updates xcb in place by re-running the install script from GitHub.
- `VERSION` file at the repo root tracks the canonical version.
