#!/usr/bin/env bats

load test_helper

@test "--version prints xcb and the version" {
    run "$XCB" --version
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^xcb\ [0-9]+\.[0-9]+\.[0-9]+$ ]]
}

@test "-v prints xcb and the version" {
    run "$XCB" -v
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^xcb\ [0-9]+\.[0-9]+\.[0-9]+$ ]]
}

@test "VERSION file matches XCB_VERSION in xcb" {
    repo_root="$(cd "$(dirname "$XCB")" && pwd)"
    file_version=$(tr -d '[:space:]' < "$repo_root/VERSION")
    xcb_version=$(grep '^XCB_VERSION="' "$XCB" | sed 's/^XCB_VERSION="\(.*\)"/\1/')
    [ "$file_version" = "$xcb_version" ]
}
