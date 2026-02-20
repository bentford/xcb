# Shared setup/teardown and helpers for xcb bats tests

XCB="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/xcb"

# Standard test arguments used by most tests
STD_ARGS=(-s TestScheme -w Test.xcworkspace -i "iPhone 16" -o 18.0)

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
