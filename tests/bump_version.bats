#!/usr/bin/env bash
# Tests for scripts/bump-version.sh — operates on a copy of the repo so
# real VERSION/Version.swift files are not modified.

load test_helper

setup() {
    TEST_DIR="$(mktemp -d)"
    mkdir -p "$TEST_DIR/scripts" "$TEST_DIR/Sources/XCBCore"
    cp "$REPO_ROOT/VERSION" "$TEST_DIR/VERSION"
    cp "$REPO_ROOT/Sources/XCBCore/Version.swift" "$TEST_DIR/Sources/XCBCore/Version.swift"
    cp "$REPO_ROOT/scripts/bump-version.sh" "$TEST_DIR/scripts/bump-version.sh"
    chmod +x "$TEST_DIR/scripts/bump-version.sh"

    # Reset to a known starting version regardless of repo state
    echo "0.1.5" > "$TEST_DIR/VERSION"
    set_source_version 0.1.5

    cd "$TEST_DIR"
}

set_source_version() {
    local swift="$TEST_DIR/Sources/XCBCore/Version.swift"
    sed "s/^let xcbVersion = \".*\"/let xcbVersion = \"$1\"/" "$swift" > "$swift.tmp"
    mv "$swift.tmp" "$swift"
}

teardown() {
    rm -rf "$TEST_DIR"
}

@test "default bump increments patch in VERSION and Version.swift" {
    run ./scripts/bump-version.sh
    [ "$status" -eq 0 ]
    [[ "$output" == *"Bumped: 0.1.5 -> 0.1.6"* ]]
    [ "$(cat VERSION)" = "0.1.6" ]
    grep -q '^let xcbVersion = "0.1.6"$' Sources/XCBCore/Version.swift
}

@test "--revert-version decrements patch" {
    run ./scripts/bump-version.sh --revert-version
    [ "$status" -eq 0 ]
    [[ "$output" == *"Reverted: 0.1.5 -> 0.1.4"* ]]
    [ "$(cat VERSION)" = "0.1.4" ]
    grep -q '^let xcbVersion = "0.1.4"$' Sources/XCBCore/Version.swift
}

@test "bump then revert returns to original" {
    ./scripts/bump-version.sh
    ./scripts/bump-version.sh --revert-version
    [ "$(cat VERSION)" = "0.1.5" ]
    grep -q '^let xcbVersion = "0.1.5"$' Sources/XCBCore/Version.swift
}

@test "--revert-version refuses to go below .0" {
    echo "0.1.0" > VERSION
    set_source_version 0.1.0

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
