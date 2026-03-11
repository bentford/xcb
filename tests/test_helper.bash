# Shared setup/teardown and helpers for xcb bats tests

XCB="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/xcb"

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
