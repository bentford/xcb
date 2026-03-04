#!/usr/bin/env bats

setup() {
    load test_helper
    setup
}

teardown() {
    teardown
}

@test "test --dry-run outputs xcodebuild test command" {
    run "$XCB" test "${STD_ARGS[@]}" --dry-run
    assert_success
    local out
    out=$(echo "$output" | strip_ansi)
    [[ "$out" == *'xcodebuild test \'* ]]
    [[ "$out" == *'-workspace "Test.xcworkspace"'* ]]
    [[ "$out" == *'-scheme "TestScheme"'* ]]
    [[ "$out" == *'-destination "platform=iOS Simulator,name=iPhone 16,OS=18.0"'* ]]
    [[ "$out" == *'xcbeautify'* ]]
}

@test "test --dry-run does not include enableCodeCoverage" {
    run "$XCB" test "${STD_ARGS[@]}" --dry-run
    assert_success
    local out
    out=$(echo "$output" | strip_ansi)
    [[ "$out" != *'enableCodeCoverage'* ]]
}

@test "test --only --dry-run includes only-testing flag" {
    run "$XCB" test "${STD_ARGS[@]}" --only MyTests/MyTestClass --dry-run
    assert_success
    local out
    out=$(echo "$output" | strip_ansi)
    [[ "$out" == *'xcodebuild test \'* ]]
    [[ "$out" == *'-only-testing:MyTests/MyTestClass'* ]]
}

assert_success() {
    if [[ "$status" -ne 0 ]]; then
        echo "Expected exit 0, got $status"
        echo "Output: $output"
        return 1
    fi
}
