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

@test "test --only-testing --dry-run includes only-testing flag" {
    run "$XCB" test "${STD_ARGS[@]}" --only-testing MyTests/MyTestClass --dry-run
    assert_success
    local out
    out=$(echo "$output" | strip_ansi)
    [[ "$out" == *'xcodebuild test \'* ]]
    [[ "$out" == *'-only-testing:MyTests/MyTestClass'* ]]
    [[ "$out" == *'Only: MyTests/MyTestClass'* ]]
}

@test "test --only-testing: accepts xcodebuild's colon form" {
    run "$XCB" test "${STD_ARGS[@]}" --only-testing:MyTests/MyTestClass/testThing --dry-run
    assert_success
    [[ "$(echo "$output" | strip_ansi)" == *'-only-testing:MyTests/MyTestClass/testThing'* ]]
}

@test "test --only still works as the old name for --only-testing" {
    run "$XCB" test "${STD_ARGS[@]}" --only MyTests/MyTestClass --dry-run
    assert_success
    [[ "$(echo "$output" | strip_ansi)" == *'-only-testing:MyTests/MyTestClass'* ]]
}

@test "test --skip-testing --dry-run includes skip-testing flag" {
    run "$XCB" test "${STD_ARGS[@]}" --skip-testing MyAppUITests --skip-testing:MyTests/SlowTests --dry-run
    assert_success
    local out
    out=$(echo "$output" | strip_ansi)
    [[ "$out" == *'-skip-testing:MyAppUITests'* ]]
    [[ "$out" == *'-skip-testing:MyTests/SlowTests'* ]]
    [[ "$out" == *'Skip: MyAppUITests, MyTests/SlowTests'* ]]
}

@test "test with repeated --only-testing and --skip-testing passes each one" {
    run "$XCB" test "${STD_ARGS[@]}" --only-testing MyTests --only-testing OtherTests/LoginTests --skip-testing MyTests/NetworkTests --dry-run
    assert_success
    local out
    out=$(echo "$output" | strip_ansi)
    [[ "$out" == *'-only-testing:MyTests '* ]]
    [[ "$out" == *'-only-testing:OtherTests/LoginTests'* ]]
    [[ "$out" == *'-skip-testing:MyTests/NetworkTests'* ]]
    [[ "$out" == *'Only: MyTests, OtherTests/LoginTests'* ]]
}

@test "--only-testing and --skip-testing are ignored outside test actions" {
    run "$XCB" build "${STD_ARGS[@]}" --only-testing MyTests --skip-testing MyAppUITests --dry-run
    assert_success
    local out
    out=$(echo "$output" | strip_ansi)
    [[ "$out" == *'--only-testing is ignored in build action'* ]]
    [[ "$out" == *'--skip-testing is ignored in build action'* ]]
    [[ "$out" != *'-only-testing:'* ]]
    [[ "$out" != *'-skip-testing:'* ]]
}

assert_success() {
    if [[ "$status" -ne 0 ]]; then
        echo "Expected exit 0, got $status"
        echo "Output: $output"
        return 1
    fi
}

@test "test --without-building --dry-run runs from the .xctestrun without building" {
    run "$XCB" test "${STD_ARGS[@]}" --only-testing MyTests/MyClass --skip-testing MyTests/MyClass/testSlow --without-building --dry-run
    assert_success
    local out
    out=$(echo "$output" | strip_ansi)
    [[ "$out" == *'xcodebuild test-without-building'* ]]
    [[ "$out" == *'-xctestrun'* ]]
    [[ "$out" == *'-only-testing:MyTests/MyClass'* ]]
    [[ "$out" == *'-skip-testing:MyTests/MyClass/testSlow'* ]]
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

@test "--last-results outside test coverage says it's ignored" {
    run "$XCB" test "${STD_ARGS[@]}" --last-results --dry-run
    assert_success
    local out
    out=$(echo "$output" | strip_ansi)
    [[ "$out" == *"--last-results is ignored in test action (it's for test coverage)"* ]]
    [[ "$out" == *'xcodebuild test \'* ]]
}

@test "test --without-building --dry-run explains the build and the test run name" {
    run "$XCB" test "${STD_ARGS[@]}" --without-building --dry-run
    assert_success
    local out
    out=$(echo "$output" | strip_ansi)
    [[ "$out" == *"Build: skipped, using the last build for testing (builds once if there isn't one)"* ]]
    [[ "$out" == *'TestScheme[_<TestPlan>]_<platform><version>.xctestrun'* ]]
}
