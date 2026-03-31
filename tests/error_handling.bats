#!/usr/bin/env bats

setup() {
    load test_helper
    setup
}

teardown() {
    teardown
}

# --- No arguments ---

@test "no arguments prints usage and exits 1" {
    run "$XCB"
    [[ "$status" -eq 1 ]]
    local out
    out=$(echo "$output" | strip_ansi)
    [[ "$out" == *'Usage:'* ]]
}

# --- Unknown action ---

@test "unknown action prints usage and exits 1" {
    run "$XCB" foobar
    [[ "$status" -eq 1 ]]
    local out
    out=$(echo "$output" | strip_ansi)
    [[ "$out" == *'Usage:'* ]]
}

# --- Unknown option ---

@test "unknown option prints error and exits 1" {
    run "$XCB" clean "${STD_ARGS[@]}" --bogus
    [[ "$status" -eq 1 ]]
    local out
    out=$(echo "$output" | strip_ansi)
    [[ "$out" == *'Unknown option: --bogus'* ]]
}

# --- Unknown sub-actions ---

@test "unknown build sub-action prints error and exits 1" {
    run "$XCB" build nope "${STD_ARGS[@]}"
    [[ "$status" -eq 1 ]]
    local out
    out=$(echo "$output" | strip_ansi)
    [[ "$out" == *"Unknown build sub-action"* ]]
}

@test "unknown test sub-action prints error and exits 1" {
    run "$XCB" test nope "${STD_ARGS[@]}"
    [[ "$status" -eq 1 ]]
    local out
    out=$(echo "$output" | strip_ansi)
    [[ "$out" == *"Unknown test sub-action"* ]]
}

@test "setup rejects sub-actions" {
    run "$XCB" setup nope
    [[ "$status" -eq 1 ]]
}

# --- Missing required flags ---

@test "missing scheme prints error and exits 1" {
    run "$XCB" clean -w Test.xcworkspace --simulator-id "TEST-SIM-UUID" --dry-run
    [[ "$status" -eq 1 ]]
    local out
    out=$(echo "$output" | strip_ansi)
    [[ "$out" == *'Scheme is required'* ]]
}

@test "missing workspace prints error and exits 1" {
    run "$XCB" clean -s TestScheme --simulator-id "TEST-SIM-UUID" --dry-run
    [[ "$status" -eq 1 ]]
    local out
    out=$(echo "$output" | strip_ansi)
    [[ "$out" == *'Workspace is not set'* ]]
}

@test "missing simulator prints error and exits 1" {
    run "$XCB" clean -s TestScheme -w Test.xcworkspace --dry-run
    [[ "$status" -eq 1 ]]
    local out
    out=$(echo "$output" | strip_ansi)
    [[ "$out" == *'Simulator is not set'* ]]
}

# --- Device destination errors ---

@test "missing device-id with device destination prints error and exits 1" {
    run "$XCB" clean -s TestScheme -w Test.xcworkspace -d device --dry-run
    [[ "$status" -eq 1 ]]
    local out
    out=$(echo "$output" | strip_ansi)
    [[ "$out" == *'Device identifier is not set'* ]]
}

@test "invalid destination type prints error and exits 1" {
    run "$XCB" clean -s TestScheme -w Test.xcworkspace -d foobar --dry-run
    [[ "$status" -eq 1 ]]
    local out
    out=$(echo "$output" | strip_ansi)
    [[ "$out" == *"Unknown destination type"* ]]
}

@test ".xcbrc with device config loads correctly" {
    cat > .xcbrc <<'CONF'
WORKSPACE="Saved.xcworkspace"
SCHEME="SavedScheme"
DESTINATION_TYPE="device"
DEVICE_ID="ABCD-1234-EFGH-5678"
DEVICE_NAME="Test iPhone"
CONF
    run "$XCB" clean --dry-run
    assert_success
    local out
    out=$(echo "$output" | strip_ansi)
    [[ "$out" == *'-destination "platform=iOS,id=ABCD-1234-EFGH-5678"'* ]]
}

# --- Help flags ---

@test "--help prints usage and exits 1" {
    run "$XCB" --help
    [[ "$status" -eq 1 ]]
    local out
    out=$(echo "$output" | strip_ansi)
    [[ "$out" == *'Usage:'* ]]
}

@test "-h prints usage and exits 1" {
    run "$XCB" -h
    [[ "$status" -eq 1 ]]
    local out
    out=$(echo "$output" | strip_ansi)
    [[ "$out" == *'Usage:'* ]]
}

# --- .xcbrc isolation ---

@test "no .xcbrc in temp dir requires explicit flags" {
    # Running from temp dir with no .xcbrc and no flags should fail
    run "$XCB" clean --dry-run
    [[ "$status" -eq 1 ]]
}

@test ".xcbrc values are loaded from working directory" {
    cat > .xcbrc <<'CONF'
WORKSPACE="Saved.xcworkspace"
SCHEME="SavedScheme"
SIMULATOR_ID="AAAA-BBBB-CCCC-DDDD"
CONF
    run "$XCB" clean --dry-run
    assert_success
    local out
    out=$(echo "$output" | strip_ansi)
    [[ "$out" == *'-workspace "Saved.xcworkspace"'* ]]
    [[ "$out" == *'-scheme "SavedScheme"'* ]]
    [[ "$out" == *'id=AAAA-BBBB-CCCC-DDDD'* ]]
}

@test "CLI flags override .xcbrc values" {
    cat > .xcbrc <<'CONF'
WORKSPACE="Saved.xcworkspace"
SCHEME="SavedScheme"
SIMULATOR_ID="AAAA-BBBB-CCCC-DDDD"
CONF
    run "$XCB" clean -s OverrideScheme -w Override.xcworkspace --dry-run
    assert_success
    local out
    out=$(echo "$output" | strip_ansi)
    [[ "$out" == *'-workspace "Override.xcworkspace"'* ]]
    [[ "$out" == *'-scheme "OverrideScheme"'* ]]
    # simulator should still come from .xcbrc
    [[ "$out" == *'id=AAAA-BBBB-CCCC-DDDD'* ]]
}

# --- Deprecation and migration ---

@test "-i flag prints deprecation warning" {
    run "$XCB" clean -s TestScheme -w Test.xcworkspace -i "iPhone 16" -o 18.0 --simulator-id "TEST-UUID" --dry-run
    assert_success
    local out
    out=$(echo "$output" | strip_ansi)
    [[ "$out" == *'deprecated'* ]]
}

@test "old .xcbrc with IPHONE_NAME prints migration message" {
    cat > .xcbrc <<'CONF'
WORKSPACE="Saved.xcworkspace"
SCHEME="SavedScheme"
IPHONE_NAME="iPhone 15"
OS_VERSION="17.0"
CONF
    run "$XCB" clean --dry-run
    [[ "$status" -eq 1 ]]
    local out
    out=$(echo "$output" | strip_ansi)
    [[ "$out" == *'old IPHONE_NAME/OS_VERSION format'* ]]
    [[ "$out" == *'xcb select simulator'* ]]
}

assert_success() {
    if [[ "$status" -ne 0 ]]; then
        echo "Expected exit 0, got $status"
        echo "Output: $output"
        return 1
    fi
}
