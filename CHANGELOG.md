# Changelog

All notable changes to xcb are documented here. Versions follow [Semantic Versioning](https://semver.org/).

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
