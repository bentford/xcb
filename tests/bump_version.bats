#!/usr/bin/env bash
# Tests for scripts/bump-version.sh — operates on a copy of the repo so
# real VERSION/xcb files are not modified.

load test_helper

setup() {
    TEST_DIR="$(mktemp -d)"
    repo_root="$(cd "$(dirname "$XCB")" && pwd)"
    mkdir -p "$TEST_DIR/scripts"
    cp "$repo_root/VERSION" "$TEST_DIR/VERSION"
    cp "$repo_root/xcb" "$TEST_DIR/xcb"
    cp "$repo_root/scripts/bump-version.sh" "$TEST_DIR/scripts/bump-version.sh"
    chmod +x "$TEST_DIR/scripts/bump-version.sh"

    # Reset to a known starting version regardless of repo state
    echo "0.1.5" > "$TEST_DIR/VERSION"
    sed -i.bak 's/^XCB_VERSION=".*"/XCB_VERSION="0.1.5"/' "$TEST_DIR/xcb"
    rm -f "$TEST_DIR/xcb.bak"

    cd "$TEST_DIR"
}

teardown() {
    rm -rf "$TEST_DIR"
}

@test "default bump increments patch in VERSION and xcb" {
    run ./scripts/bump-version.sh
    [ "$status" -eq 0 ]
    [[ "$output" == *"Bumped: 0.1.5 -> 0.1.6"* ]]
    [ "$(cat VERSION)" = "0.1.6" ]
    grep -q '^XCB_VERSION="0.1.6"$' xcb
}

@test "--revert-version decrements patch" {
    run ./scripts/bump-version.sh --revert-version
    [ "$status" -eq 0 ]
    [[ "$output" == *"Reverted: 0.1.5 -> 0.1.4"* ]]
    [ "$(cat VERSION)" = "0.1.4" ]
    grep -q '^XCB_VERSION="0.1.4"$' xcb
}

@test "bump then revert returns to original" {
    ./scripts/bump-version.sh
    ./scripts/bump-version.sh --revert-version
    [ "$(cat VERSION)" = "0.1.5" ]
    grep -q '^XCB_VERSION="0.1.5"$' xcb
}

@test "--revert-version refuses to go below .0" {
    echo "0.1.0" > VERSION
    sed -i.bak 's/^XCB_VERSION=".*"/XCB_VERSION="0.1.0"/' xcb
    rm -f xcb.bak

    run ./scripts/bump-version.sh --revert-version
    [ "$status" -ne 0 ]
    [[ "$output" == *"cannot revert below 0.1.0"* ]]
    [ "$(cat VERSION)" = "0.1.0" ]
}

@test "rejects non-semver VERSION" {
    echo "not-a-version" > VERSION
    run ./scripts/bump-version.sh
    [ "$status" -ne 0 ]
    [[ "$output" == *"is not semver"* ]]
}

@test "rejects unknown option" {
    run ./scripts/bump-version.sh --frobnicate
    [ "$status" -ne 0 ]
    [[ "$output" == *"unknown option"* ]]
}
