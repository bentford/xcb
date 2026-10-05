# Shared setup/teardown and helpers for xcb bats tests

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# The Swift binary under test. Build it first with `swift build`, or point
# XCB at another build (e.g. .build/release/xcb).
XCB="${XCB:-$REPO_ROOT/.build/debug/xcb}"
if [[ ! -x "$XCB" ]]; then
    echo "xcb binary not found at $XCB — run 'swift build' first" >&2
    exit 1
fi

# Version as declared in the Swift sources
source_version() {
    sed -n 's/^let xcbVersion = "\(.*\)"/\1/p' "$REPO_ROOT/Sources/XCBCore/Version.swift"
}

# Standard test arguments used by most tests (simulator, the default)
STD_ARGS=(-s TestScheme -w Test.xcworkspace --simulator-id "TEST-SIM-UUID-1234")

# Standard test arguments for device destination
STD_DEVICE_ARGS=(-s TestScheme -w Test.xcworkspace -d device --device-id "TEST-UUID-1234")

setup() {
    TEST_DIR="$(mktemp -d)"
    cd "$TEST_DIR"
}

teardown() {
    rm -rf "$TEST_DIR"
}

# Strip ANSI escape sequences from input
strip_ansi() {
    local esc=$'\x1b'
    sed "s/${esc}\[[0-9;]*m//g"
}
