#!/usr/bin/env bats

setup() {
    load test_helper
    setup
}

teardown() {
    teardown
}

@test "build run --dry-run outputs xcodebuild build and simulator comment" {
    run "$XCB" build run "${STD_ARGS[@]}" --dry-run
    assert_success
    local out
    out=$(echo "$output" | strip_ansi)
    [[ "$out" == *'xcodebuild build \'* ]]
    [[ "$out" == *'-workspace "Test.xcworkspace"'* ]]
    [[ "$out" == *'-scheme "TestScheme"'* ]]
    [[ "$out" == *'-destination "platform=iOS Simulator,name=iPhone 16,OS=18.0"'* ]]
    [[ "$out" == *'# Then: boot simulator, install app, launch app'* ]]
}

@test "build run --dry-run does not include clean without --clean" {
    run "$XCB" build run "${STD_ARGS[@]}" --dry-run
    assert_success
    local out
    out=$(echo "$output" | strip_ansi)
    [[ "$out" != *'xcodebuild clean'* ]]
}

@test "build run --clean --dry-run outputs clean before build and simulator comment" {
    run "$XCB" build run "${STD_ARGS[@]}" --clean --dry-run
    assert_success
    local out
    out=$(echo "$output" | strip_ansi)
    [[ "$out" == *'xcodebuild clean \'* ]]
    [[ "$out" == *'xcodebuild build \'* ]]
    [[ "$out" == *'# Then: boot simulator, install app, launch app'* ]]

    # clean must appear before build
    local clean_pos build_pos
    clean_pos=$(echo "$out" | grep -n 'xcodebuild clean' | head -1 | cut -d: -f1)
    build_pos=$(echo "$out" | grep -n 'xcodebuild build' | head -1 | cut -d: -f1)
    [[ "$clean_pos" -lt "$build_pos" ]]
}

assert_success() {
    if [[ "$status" -ne 0 ]]; then
        echo "Expected exit 0, got $status"
        echo "Output: $output"
        return 1
    fi
}
