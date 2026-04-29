#!/usr/bin/env bats
#
# Unit tests for parse_app_build_settings — driven via the hidden
# `xcb --parse-build-settings` subcommand which reads showBuildSettings
# output on stdin and prints "<APP_NAME>\t<APP_PATH>".
#
# BUNDLE_ID extraction (defaults read on Info.plist) is exercised at the
# integration layer, not here — it requires a real .app bundle on disk.

setup() {
    load test_helper
    setup
}

teardown() {
    teardown
}

assert_success() {
    if [[ "$status" -ne 0 ]]; then
        echo "Expected exit 0, got $status"
        echo "Output: $output"
        return 1
    fi
}

@test "parses single .app target" {
    run "$XCB" --parse-build-settings <<'EOF'
Build settings for action build and target "MyApp":
    BUILT_PRODUCTS_DIR = /DD/Build/Products/Debug-iphonesimulator
    FULL_PRODUCT_NAME = MyApp.app
    PRODUCT_BUNDLE_IDENTIFIER = com.example.MyApp
EOF
    assert_success
    [[ "$output" == $'MyApp.app\t/DD/Build/Products/Debug-iphonesimulator' ]]
}

@test "picks .app when framework target appears first" {
    run "$XCB" --parse-build-settings <<'EOF'
Build settings for action build and target "MyKit":
    BUILT_PRODUCTS_DIR = /WRONG/framework/dir
    FULL_PRODUCT_NAME = MyKit.framework
    PRODUCT_BUNDLE_IDENTIFIER = com.example.MyKit

Build settings for action build and target "MyApp":
    BUILT_PRODUCTS_DIR = /DD/Build/Products/Debug-iphonesimulator
    FULL_PRODUCT_NAME = MyApp.app
    PRODUCT_BUNDLE_IDENTIFIER = com.example.MyApp
EOF
    assert_success
    [[ "$output" == $'MyApp.app\t/DD/Build/Products/Debug-iphonesimulator' ]]
}

@test "picks .app when app target appears first" {
    run "$XCB" --parse-build-settings <<'EOF'
Build settings for action build and target "MyApp":
    BUILT_PRODUCTS_DIR = /DD/Build/Products/Debug-iphonesimulator
    FULL_PRODUCT_NAME = MyApp.app
    PRODUCT_BUNDLE_IDENTIFIER = com.example.MyApp

Build settings for action build and target "MyKit":
    BUILT_PRODUCTS_DIR = /WRONG/framework/dir
    FULL_PRODUCT_NAME = MyKit.framework
EOF
    assert_success
    [[ "$output" == $'MyApp.app\t/DD/Build/Products/Debug-iphonesimulator' ]]
}

@test "preserves spaces in BUILT_PRODUCTS_DIR" {
    run "$XCB" --parse-build-settings <<'EOF'
Build settings for action build and target "MyApp":
    BUILT_PRODUCTS_DIR = /Users/me/Build Products/Debug-iphonesimulator
    FULL_PRODUCT_NAME = MyApp.app
EOF
    assert_success
    [[ "$output" == $'MyApp.app\t/Users/me/Build Products/Debug-iphonesimulator' ]]
}

@test "emits empty output when no .app target exists" {
    run "$XCB" --parse-build-settings <<'EOF'
Build settings for action build and target "MyKit":
    BUILT_PRODUCTS_DIR = /tmp/Build/Products/Debug-iphonesimulator
    FULL_PRODUCT_NAME = MyKit.framework

Build settings for action build and target "MyKitTests":
    BUILT_PRODUCTS_DIR = /tmp/Build/Products/Debug-iphonesimulator
    FULL_PRODUCT_NAME = MyKitTests.xctest
EOF
    assert_success
    [[ -z "$output" ]]
}
