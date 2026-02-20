#!/usr/bin/env bats

setup() {
    load test_helper
    setup
}

teardown() {
    teardown
}

@test "clean --dry-run outputs xcodebuild clean command" {
    run "$XCB" clean "${STD_ARGS[@]}" --dry-run
    assert_success
    local out
    out=$(echo "$output" | strip_ansi)
    [[ "$out" == *'xcodebuild clean \'* ]]
    [[ "$out" == *'-workspace "Test.xcworkspace"'* ]]
    [[ "$out" == *'-scheme "TestScheme"'* ]]
    [[ "$out" == *'-destination "platform=iOS Simulator,name=iPhone 16,OS=18.0"'* ]]
}

assert_success() {
    if [[ "$status" -ne 0 ]]; then
        echo "Expected exit 0, got $status"
        echo "Output: $output"
        return 1
    fi
}
