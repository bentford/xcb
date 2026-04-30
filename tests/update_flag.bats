#!/usr/bin/env bats
# Tests for `xcb --update`. Stubs `curl` via PATH so no network calls occur.

load test_helper

setup() {
    TEST_DIR="$(mktemp -d)"
    BIN_DIR="$TEST_DIR/bin"
    mkdir -p "$BIN_DIR"

    # Marker that the install curl was invoked (should NOT happen on dry-run / up-to-date).
    INSTALL_MARKER="$TEST_DIR/install_called"

    # Curl stub: respond to VERSION URL with $FAKE_REMOTE_VERSION; for any
    # other URL, write to $INSTALL_MARKER so tests can detect an unexpected install.
    cat > "$BIN_DIR/curl" <<'STUB'
#!/usr/bin/env bash
url="${!#}"
if [[ "$url" == *"/VERSION" ]]; then
    printf '%s\n' "${FAKE_REMOTE_VERSION:-0.0.0}"
    exit 0
fi
echo "$url" >> "$INSTALL_MARKER"
exit 0
STUB
    chmod +x "$BIN_DIR/curl"

    export PATH="$BIN_DIR:$PATH"
    export INSTALL_MARKER

    cd "$TEST_DIR"
}

teardown() {
    rm -rf "$TEST_DIR"
}

local_version() {
    grep '^XCB_VERSION="' "$XCB" | sed 's/^XCB_VERSION="\(.*\)"/\1/'
}

@test "--update reports up to date when versions match" {
    export FAKE_REMOTE_VERSION="$(local_version)"
    run "$XCB" --update
    [ "$status" -eq 0 ]
    [[ "$output" == *"up to date"* ]]
    [ ! -f "$INSTALL_MARKER" ]
}

@test "--update --dry-run shows planned update without installing" {
    export FAKE_REMOTE_VERSION="9.9.9"
    run "$XCB" --update --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"Would update xcb $(local_version) -> 9.9.9"* ]]
    [[ "$output" == *"Would run: curl"* ]]
    [[ "$output" == *"Changelog:"* ]]
    [ ! -f "$INSTALL_MARKER" ]
}

@test "--update --dry-run still reports up to date when versions match" {
    export FAKE_REMOTE_VERSION="$(local_version)"
    run "$XCB" --update --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"up to date"* ]]
    [ ! -f "$INSTALL_MARKER" ]
}

@test "--update warns when running xcb is not at \$HOME/bin/xcb" {
    export FAKE_REMOTE_VERSION="9.9.9"
    # $XCB lives in the repo, not $HOME/bin — warning should fire.
    HOME="$TEST_DIR" run "$XCB" --update --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"Warning: running xcb is at"* ]]
    [[ "$output" == *"second copy"* ]]
}

@test "--update does not warn when running xcb is at \$HOME/bin/xcb" {
    export FAKE_REMOTE_VERSION="9.9.9"
    mkdir -p "$TEST_DIR/bin"
    cp "$XCB" "$TEST_DIR/bin/xcb"
    chmod +x "$TEST_DIR/bin/xcb"

    HOME="$TEST_DIR" run "$TEST_DIR/bin/xcb" --update --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" != *"Warning: running xcb"* ]]
}

@test "--update fails when remote VERSION cannot be fetched" {
    # Make curl exit non-zero for VERSION lookups
    cat > "$BIN_DIR/curl" <<'STUB'
#!/usr/bin/env bash
exit 22
STUB
    chmod +x "$BIN_DIR/curl"

    run "$XCB" --update --dry-run
    [ "$status" -ne 0 ]
    [[ "$output" == *"could not fetch remote version"* ]]
}
