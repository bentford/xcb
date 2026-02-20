#!/usr/bin/env bats

setup() {
    load test_helper
    setup
}

teardown() {
    teardown
}

@test "test coverage --dry-run outputs xcodebuild test with coverage enabled" {
    run "$XCB" test coverage "${STD_ARGS[@]}" --dry-run
    assert_success
    local out
    out=$(echo "$output" | strip_ansi)
    [[ "$out" == *'xcodebuild test \'* ]]
    [[ "$out" == *'-workspace "Test.xcworkspace"'* ]]
    [[ "$out" == *'-scheme "TestScheme"'* ]]
    [[ "$out" == *'-enableCodeCoverage YES'* ]]
    [[ "$out" == *'-resultBundlePath "/tmp/TestScheme-Coverage-<timestamp>.xcresult"'* ]]
}

@test "test coverage --only --dry-run includes both coverage and only-testing" {
    run "$XCB" test coverage "${STD_ARGS[@]}" --only MyTests/MyTestClass --dry-run
    assert_success
    local out
    out=$(echo "$output" | strip_ansi)
    [[ "$out" == *'-enableCodeCoverage YES'* ]]
    [[ "$out" == *'-only-testing:MyTests/MyTestClass'* ]]
    [[ "$out" == *'-resultBundlePath "/tmp/TestScheme-Coverage-<timestamp>.xcresult"'* ]]
}

assert_success() {
    if [[ "$status" -ne 0 ]]; then
        echo "Expected exit 0, got $status"
        echo "Output: $output"
        return 1
    fi
}
