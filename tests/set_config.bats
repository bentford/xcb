#!/usr/bin/env bats
# Tests for set_config helper

load test_helper

# Source just the set_config function from xcb
setup() {
    TEST_DIR="$(mktemp -d)"
    cd "$TEST_DIR"
    XCB_CONFIG=".xcbrc"
    # Extract set_config from xcb
    eval "$(sed -n '/^set_config()/,/^}/p' "$XCB")"
}

@test "creates new key in new file" {
    set_config SCHEME "MyApp"
    [[ -f .xcbrc ]]
    grep -q '^SCHEME="MyApp"$' .xcbrc
}

@test "creates new key in existing file" {
    echo 'WORKSPACE="Test.xcworkspace"' > .xcbrc
    set_config SCHEME "MyApp"
    grep -q '^WORKSPACE="Test.xcworkspace"$' .xcbrc
    grep -q '^SCHEME="MyApp"$' .xcbrc
}

@test "updates existing key" {
    echo 'SCHEME="OldScheme"' > .xcbrc
    set_config SCHEME "NewScheme"
    grep -q '^SCHEME="NewScheme"$' .xcbrc
    ! grep -q 'OldScheme' .xcbrc
}

@test "removes key when value is empty" {
    echo 'SCHEME="MyApp"' > .xcbrc
    set_config SCHEME ""
    ! grep -q 'SCHEME' .xcbrc
}

@test "remove is a no-op when key does not exist" {
    echo 'WORKSPACE="Test.xcworkspace"' > .xcbrc
    set_config SCHEME ""
    grep -q '^WORKSPACE="Test.xcworkspace"$' .xcbrc
}

@test "remove is a no-op when file does not exist" {
    set_config SCHEME ""
    [[ ! -f .xcbrc ]]
}

@test "does not affect other keys when updating" {
    cat > .xcbrc <<'EOF'
WORKSPACE="Test.xcworkspace"
SCHEME="OldScheme"
SIMULATOR_ID="some-uuid"
EOF
    set_config SCHEME "NewScheme"
    grep -q '^WORKSPACE="Test.xcworkspace"$' .xcbrc
    grep -q '^SIMULATOR_ID="some-uuid"$' .xcbrc
    grep -q '^SCHEME="NewScheme"$' .xcbrc
}

@test "handles value with forward slashes" {
    set_config WORKSPACE "path/to/My.xcworkspace"
    grep -q '^WORKSPACE="path/to/My.xcworkspace"$' .xcbrc
}

@test "handles value with ampersand" {
    set_config DEVICE_NAME "Tom & Jerry"
    grep -q '^DEVICE_NAME="Tom & Jerry"$' .xcbrc
}

@test "handles value with special sed characters" {
    set_config DEVICE_NAME 'a/b&c\d'
    grep -qF 'DEVICE_NAME="a/b&c\d"' .xcbrc
}

@test "update does not corrupt value with special characters" {
    echo 'DEVICE_NAME="old"' > .xcbrc
    set_config DEVICE_NAME 'new/name&co'
    grep -qF 'DEVICE_NAME="new/name&co"' .xcbrc
    ! grep -q 'old' .xcbrc
}
