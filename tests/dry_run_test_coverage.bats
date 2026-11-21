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
    [[ "$out" == *'xcbeautify'* ]]
}

@test "test coverage --dry-run with device destination outputs device destination" {
    run "$XCB" test coverage "${STD_DEVICE_ARGS[@]}" --dry-run
    assert_success
    local out
    out=$(echo "$output" | strip_ansi)
    [[ "$out" == *'xcodebuild test \'* ]]
    [[ "$out" == *'-destination "platform=iOS,id=TEST-UUID-1234"'* ]]
    [[ "$out" == *'-enableCodeCoverage YES'* ]]
    [[ "$out" == *'xcbeautify'* ]]
}

@test "test coverage --only-testing --skip-testing --dry-run includes coverage and both test flags" {
    run "$XCB" test coverage "${STD_ARGS[@]}" --only-testing MyTests/MyTestClass --skip-testing MyTests/MyTestClass/testSlow --dry-run
    assert_success
    local out
    out=$(echo "$output" | strip_ansi)
    [[ "$out" == *'-enableCodeCoverage YES'* ]]
    [[ "$out" == *'-only-testing:MyTests/MyTestClass'* ]]
    [[ "$out" == *'-skip-testing:MyTests/MyTestClass/testSlow'* ]]
    [[ "$out" == *'-resultBundlePath "/tmp/TestScheme-Coverage-<timestamp>.xcresult"'* ]]
}

@test "test coverage --last-results --dry-run shows xccov command" {
    run "$XCB" test coverage --last-results --dry-run
    assert_success
    local out
    out=$(echo "$output" | strip_ansi)
    [[ "$out" == *'xcrun xccov view --report --json <most-recent>.xcresult'* ]]
}

@test "--skip-build still works as the old name for --last-results" {
    run "$XCB" test coverage --skip-build --dry-run
    assert_success
    [[ "$(echo "$output" | strip_ansi)" == *'xcrun xccov view --report --json <most-recent>.xcresult'* ]]
}

@test "--without-building, --only-testing and --skip-testing with --last-results explain why they're ignored" {
    run "$XCB" test coverage --last-results --without-building --only-testing MyTests/MyClass --skip-testing MyAppUITests --dry-run
    assert_success
    local out
    out=$(echo "$output" | strip_ansi)
    [[ "$out" == *"--without-building is ignored with --last-results, which doesn't run tests"* ]]
    [[ "$out" == *"--only-testing is ignored with --last-results, which doesn't run tests"* ]]
    [[ "$out" == *"--skip-testing is ignored with --last-results, which doesn't run tests"* ]]
    [[ "$out" != *'ignored in coverage action'* ]]
}

assert_success() {
    if [[ "$status" -ne 0 ]]; then
        echo "Expected exit 0, got $status"
        echo "Output: $output"
        return 1
    fi
}
