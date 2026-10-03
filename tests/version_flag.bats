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

@test "VERSION file matches xcbVersion in Version.swift" {
    file_version=$(tr -d '[:space:]' < "$REPO_ROOT/VERSION")
    [ "$file_version" = "$(source_version)" ]
}

@test "--version reports the version from Version.swift" {
    run "$XCB" --version
    [ "$output" = "xcb $(source_version)" ]
}
