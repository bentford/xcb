#!/usr/bin/env bats
# Tests for install.sh. Stubs `curl` via PATH to serve a fake release from a
# local directory, so no network calls occur. install.sh is macOS-only.

load test_helper

ASSET="xcb-macos-universal.tar.gz"

setup() {
    if [[ "$(uname -s)" != "Darwin" ]]; then
        skip "install.sh only supports macOS"
    fi

    TEST_DIR="$(mktemp -d)"
    BIN_DIR="$TEST_DIR/stubs"
    RELEASE_DIR="$TEST_DIR/release"
    URL_LOG="$TEST_DIR/urls"
    mkdir -p "$BIN_DIR" "$RELEASE_DIR"

    # Fake release: a tarball holding an `xcb` that reports its version
    mkdir "$TEST_DIR/payload"
    printf '#!/bin/bash\necho "xcb 9.9.9"\n' > "$TEST_DIR/payload/xcb"
    chmod +x "$TEST_DIR/payload/xcb"
    tar -czf "$RELEASE_DIR/$ASSET" -C "$TEST_DIR/payload" xcb
    (cd "$RELEASE_DIR" && shasum -a 256 "$ASSET" > "$ASSET.sha256")

    # Curl stub: log the URL, then copy the release file it names to the -o path
    cat > "$BIN_DIR/curl" <<'STUB'
#!/usr/bin/env bash
out=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        -o) out="$2"; shift 2 ;;
        -*) shift ;;
        *) url="$1"; shift ;;
    esac
done
echo "$url" >> "$URL_LOG"
src="$RELEASE_DIR/$(basename "$url")"
[[ -f "$src" ]] || exit 22
cp "$src" "$out"
STUB
    chmod +x "$BIN_DIR/curl"

    export PATH="$BIN_DIR:$PATH" RELEASE_DIR URL_LOG
    export HOME="$TEST_DIR/home"
    mkdir -p "$HOME"
}

teardown() {
    [[ -n "${TEST_DIR:-}" ]] && rm -rf "$TEST_DIR"
}

@test "installs the latest release to ~/bin/xcb" {
    run bash "$REPO_ROOT/install.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"xcb 9.9.9 installed successfully!"* ]]
    [ -x "$HOME/bin/xcb" ]
    grep -q "/releases/latest/download/$ASSET" "$URL_LOG"
}

@test "replaces an existing install" {
    mkdir -p "$HOME/bin"
    echo "old bash script" > "$HOME/bin/xcb"
    run bash "$REPO_ROOT/install.sh"
    [ "$status" -eq 0 ]
    [ "$("$HOME/bin/xcb")" = "xcb 9.9.9" ]
}

@test "XCB_INSTALL_VERSION installs a specific release" {
    XCB_INSTALL_VERSION=v9.9.9 run bash "$REPO_ROOT/install.sh"
    [ "$status" -eq 0 ]
    grep -q "/releases/download/v9.9.9/$ASSET" "$URL_LOG"
}

@test "fails and installs nothing when the checksum does not match" {
    echo "0000000000000000000000000000000000000000000000000000000000000000  $ASSET" > "$RELEASE_DIR/$ASSET.sha256"
    run bash "$REPO_ROOT/install.sh"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Checksum verification failed"* ]]
    [ ! -e "$HOME/bin/xcb" ]
}

@test "fails when the release cannot be downloaded" {
    rm "$RELEASE_DIR/$ASSET"
    run bash "$REPO_ROOT/install.sh"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Failed to download xcb"* ]]
    [ ! -e "$HOME/bin/xcb" ]
}
