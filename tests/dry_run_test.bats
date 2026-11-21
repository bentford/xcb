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
    [[ "$out" == *'-destination "platform=iOS Simulator,id=TEST-SIM-UUID-1234"'* ]]
    [[ "$out" == *'xcbeautify'* ]]
}

@test "test --dry-run with device destination outputs device destination" {
    run "$XCB" test "${STD_DEVICE_ARGS[@]}" --dry-run
    assert_success
    local out
    out=$(echo "$output" | strip_ansi)
    [[ "$out" == *'xcodebuild test \'* ]]
    [[ "$out" == *'-destination "platform=iOS,id=TEST-UUID-1234"'* ]]
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

@test "test --without-building --dry-run runs from the .xctestrun without building" {
    run "$XCB" test "${STD_ARGS[@]}" --only MyTests/MyClass --without-building --dry-run
    assert_success
    local out
    out=$(echo "$output" | strip_ansi)
    [[ "$out" == *'xcodebuild test-without-building'* ]]
    [[ "$out" == *'-xctestrun'* ]]
    [[ "$out" == *'-only-testing:MyTests/MyClass'* ]]
    [[ "$out" != *'-workspace'* ]]
}

@test "build --dry-run checks for package updates by default" {
    run "$XCB" build "${STD_ARGS[@]}" --dry-run
    assert_success
    [[ "$(echo "$output" | strip_ansi)" != *'-skipPackageUpdates'* ]]
}

@test "--skip-package-updates adds -skipPackageUpdates" {
    run "$XCB" build "${STD_ARGS[@]}" --skip-package-updates --dry-run
    assert_success
    [[ "$(echo "$output" | strip_ansi)" == *'-skipPackageUpdates'* ]]
}

@test "SKIP_PACKAGE_UPDATES in .xcbrc adds -skipPackageUpdates" {
    echo 'SKIP_PACKAGE_UPDATES="1"' > .xcbrc
    run "$XCB" test "${STD_ARGS[@]}" --dry-run
    assert_success
    [[ "$(echo "$output" | strip_ansi)" == *'-skipPackageUpdates'* ]]
}

@test "--no-skip-package-updates overrides .xcbrc" {
    echo 'SKIP_PACKAGE_UPDATES="1"' > .xcbrc
    run "$XCB" build "${STD_ARGS[@]}" --no-skip-package-updates --dry-run
    assert_success
    [[ "$(echo "$output" | strip_ansi)" != *'-skipPackageUpdates'* ]]
}

@test "the header says when package updates are skipped by a flag" {
    run "$XCB" build "${STD_ARGS[@]}" --skip-package-updates --dry-run
    assert_success
    [[ "$(echo "$output" | strip_ansi)" == *'Packages: not checking for updates (--skip-package-updates)'* ]]
}

@test "the header says when .xcbrc skips package updates and how to check" {
    echo 'SKIP_PACKAGE_UPDATES="1"' > .xcbrc
    run "$XCB" test "${STD_ARGS[@]}" --dry-run
    assert_success
    [[ "$(echo "$output" | strip_ansi)" == *'Packages: not checking for updates (SKIP_PACKAGE_UPDATES in .xcbrc; pass --no-skip-package-updates to check)'* ]]
}

@test "the header has no Packages line when updates are checked" {
    echo 'SKIP_PACKAGE_UPDATES="1"' > .xcbrc
    run "$XCB" clean "${STD_ARGS[@]}" --no-skip-package-updates --dry-run
    assert_success
    [[ "$(echo "$output" | strip_ansi)" != *'Packages:'* ]]
}

@test "test --without-building --dry-run leaves out -skipPackageUpdates" {
    run "$XCB" test "${STD_ARGS[@]}" --skip-package-updates --without-building --dry-run
    assert_success
    [[ "$(echo "$output" | strip_ansi)" != *'-skipPackageUpdates'* ]]
}

@test "--without-building is ignored outside test actions" {
    run "$XCB" build "${STD_ARGS[@]}" --without-building --dry-run
    assert_success
    [[ "$(echo "$output" | strip_ansi)" == *'--without-building is ignored'* ]]
}
