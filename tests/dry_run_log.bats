#!/usr/bin/env bats

setup() {
    load test_helper
    setup
}

teardown() {
    teardown
}

@test "log --dry-run outputs simctl log stream command" {
    run "$XCB" log "${STD_ARGS[@]}" --subsystem com.example.app --dry-run
    assert_success
    local out
    out=$(echo "$output" | strip_ansi)
    [[ "$out" == *'xcrun simctl spawn "TEST-SIM-UUID-1234" log stream \'* ]]
    [[ "$out" == *'--level=debug'* ]]
    [[ "$out" == *"--predicate 'subsystem == \"com.example.app\"'"* ]]
    [[ "$out" == *'--style compact'* ]]
}

@test "log --dry-run passes --level through" {
    run "$XCB" log "${STD_ARGS[@]}" --subsystem com.example.app --level info --dry-run
    assert_success
    [[ "$output" == *'--level=info'* ]]
}

@test "log rejects an unknown --level" {
    run "$XCB" log "${STD_ARGS[@]}" --subsystem com.example.app --level error --dry-run
    [[ "$status" -eq 1 ]]
    [[ "$output" == *'--level must be default, info, or debug'* ]]
}

@test "log --dry-run filters categories, using LIKE for wildcards" {
    run "$XCB" log "${STD_ARGS[@]}" --subsystem com.example.app -c Networking -c 'Auth*' --dry-run
    assert_success
    local out
    out=$(echo "$output" | strip_ansi)
    [[ "$out" == *'AND (category == "Networking" OR category LIKE "Auth*")'* ]]
}

@test "log --dry-run uses saved LOG_SUBSYSTEM from .xcbrc" {
    echo 'LOG_SUBSYSTEM="com.saved.app"' > .xcbrc
    run "$XCB" log "${STD_ARGS[@]}" --dry-run
    assert_success
    [[ "$output" == *'subsystem == "com.saved.app"'* ]]
}

@test "log --dry-run without a subsystem shows the bundle ID placeholder" {
    run "$XCB" log "${STD_ARGS[@]}" --dry-run
    assert_success
    [[ "$output" == *'subsystem == "<bundle-id>"'* ]]
}

@test "log with device destination fails" {
    run "$XCB" log "${STD_DEVICE_ARGS[@]}" --subsystem com.example.app --dry-run
    [[ "$status" -eq 1 ]]
    [[ "$output" == *'log only supports simulators'* ]]
}

@test "log with an unknown destination fails even with a subsystem" {
    run "$XCB" log "${STD_ARGS[@]}" -d devcie --subsystem com.example.app --dry-run
    [[ "$status" -eq 1 ]]
    [[ "$output" == *"Unknown destination type 'devcie'"* ]]
}

@test "select subsystem keeps the saved value when input ends" {
    echo 'LOG_SUBSYSTEM="com.saved.app"' > .xcbrc
    run "$XCB" select subsystem < /dev/null
    [[ "$status" -eq 1 ]]
    [[ "$(cat .xcbrc)" == 'LOG_SUBSYSTEM="com.saved.app"' ]]
}

@test "select subsystem clears the saved value on a blank line" {
    echo 'LOG_SUBSYSTEM="com.saved.app"' > .xcbrc
    run "$XCB" select subsystem <<< ""
    assert_success
    [[ "$(cat .xcbrc)" != *LOG_SUBSYSTEM* ]]
}

@test "select subsystem saves an entered value" {
    run "$XCB" select subsystem <<< "com.example.app"
    assert_success
    [[ "$(cat .xcbrc)" == 'LOG_SUBSYSTEM="com.example.app"' ]]
}

@test "log without a simulator fails" {
    run "$XCB" log -s TestScheme -w Test.xcworkspace --subsystem com.example.app --dry-run
    [[ "$status" -eq 1 ]]
    [[ "$output" == *'Simulator is not set'* ]]
}

assert_success() {
    if [[ "$status" -ne 0 ]]; then
        echo "Expected exit 0, got $status"
        echo "Output: $output"
        return 1
    fi
}
