#!/usr/bin/env bats

setup() {
    load test_helper
    setup
}

teardown() {
    teardown
}

@test "--audible accepted with build --dry-run" {
    run "$XCB" build "${STD_ARGS[@]}" --audible --dry-run
    assert_success
    local out
    out=$(echo "$output" | strip_ansi)
    [[ "$out" == *'xcodebuild build \'* ]]
}

@test "--audible accepted with clean --dry-run" {
    run "$XCB" clean "${STD_ARGS[@]}" --audible --dry-run
    assert_success
    local out
    out=$(echo "$output" | strip_ansi)
    [[ "$out" == *'xcodebuild clean \'* ]]
}

@test "--audible accepted with test --dry-run" {
    run "$XCB" test "${STD_ARGS[@]}" --audible --dry-run
    assert_success
    local out
    out=$(echo "$output" | strip_ansi)
    [[ "$out" == *'xcodebuild test \'* ]]
}

@test "--audible accepted with test coverage --dry-run" {
    run "$XCB" test coverage "${STD_ARGS[@]}" --audible --dry-run
    assert_success
    local out
    out=$(echo "$output" | strip_ansi)
    [[ "$out" == *'xcodebuild test \'* ]]
    [[ "$out" == *'-enableCodeCoverage YES'* ]]
}

@test "--audible accepted with build run --dry-run" {
    run "$XCB" build run "${STD_ARGS[@]}" --audible --dry-run
    assert_success
    local out
    out=$(echo "$output" | strip_ansi)
    [[ "$out" == *'xcodebuild build \'* ]]
}

@test "-a short flag accepted" {
    run "$XCB" build "${STD_ARGS[@]}" -a --dry-run
    assert_success
    local out
    out=$(echo "$output" | strip_ansi)
    [[ "$out" == *'xcodebuild build \'* ]]
}

@test "--audible flag does not leak into dry-run output" {
    run "$XCB" build "${STD_ARGS[@]}" --audible --dry-run
    assert_success
    local out
    out=$(echo "$output" | strip_ansi)
    [[ "$out" != *'audible'* ]]
    [[ "$out" != *'afplay'* ]]
    [[ "$out" != *'sound'* ]]
}

assert_success() {
    if [[ "$status" -ne 0 ]]; then
        echo "Expected exit 0, got $status"
        echo "Output: $output"
        return 1
    fi
}
