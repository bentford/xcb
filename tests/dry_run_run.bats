#!/usr/bin/env bats

setup() {
    load test_helper
    setup
}

teardown() {
    teardown
}

@test "run --dry-run outputs xcrun simctl commands" {
    run "$XCB" run "${STD_ARGS[@]}" --dry-run
    assert_success
    local out
    out=$(echo "$output" | strip_ansi)
    [[ "$out" == *'xcrun simctl boot'* ]]
    [[ "$out" == *'xcrun simctl install'* ]]
    [[ "$out" == *'xcrun simctl launch'* ]]
}

assert_success() {
    if [[ "$status" -ne 0 ]]; then
        echo "Expected exit 0, got $status"
        echo "Output: $output"
        return 1
    fi
}
