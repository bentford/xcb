#!/usr/bin/env bats

setup() {
    load test_helper
    setup
}

teardown() {
    teardown
}

@test "--quiet accepted with build --dry-run" {
    run "$XCB" build "${STD_ARGS[@]}" --quiet --dry-run
    assert_success
}

@test "-q short flag accepted with build --dry-run" {
    run "$XCB" build "${STD_ARGS[@]}" -q --dry-run
    assert_success
}

@test "--quiet adds -quiet to build --dry-run output" {
    run "$XCB" build "${STD_ARGS[@]}" --quiet --dry-run
    assert_success
    local out
    out=$(echo "$output" | strip_ansi)
    [[ "$out" == *'-quiet \'* ]]
}

@test "build --dry-run without --quiet does not include -quiet" {
    run "$XCB" build "${STD_ARGS[@]}" --dry-run
    assert_success
    local out
    out=$(echo "$output" | strip_ansi)
    [[ "$out" != *'-quiet'* ]]
}

@test "--quiet adds -quiet to build run --dry-run output" {
    run "$XCB" build run "${STD_ARGS[@]}" --quiet --dry-run
    assert_success
    local out
    out=$(echo "$output" | strip_ansi)
    [[ "$out" == *'-quiet \'* ]]
}

@test "--quiet adds -quiet to test --dry-run output" {
    run "$XCB" test "${STD_ARGS[@]}" --quiet --dry-run
    assert_success
    local out
    out=$(echo "$output" | strip_ansi)
    [[ "$out" == *'-quiet \'* ]]
}

@test "--quiet adds -quiet to test coverage --dry-run output" {
    run "$XCB" test coverage "${STD_ARGS[@]}" --quiet --dry-run
    assert_success
    local out
    out=$(echo "$output" | strip_ansi)
    [[ "$out" == *'-quiet \'* ]]
}

@test "--quiet flag does not leak into dry-run header" {
    run "$XCB" build "${STD_ARGS[@]}" --quiet --dry-run
    assert_success
    local out
    out=$(echo "$output" | strip_ansi)
    # -quiet should appear as xcodebuild flag, not in the info header
    [[ "$out" == *'xcodebuild build \'* ]]
    [[ "$out" == *'-quiet \'* ]]
}

assert_success() {
    if [[ "$status" -ne 0 ]]; then
        echo "Expected exit 0, got $status"
        echo "Output: $output"
        return 1
    fi
}
