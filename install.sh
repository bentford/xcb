#!/usr/bin/env bash
# Install the latest xcb release to ~/bin/xcb.
# Set XCB_INSTALL_VERSION (e.g. v0.2.0) to install a specific release.
set -euo pipefail

INSTALL_DIR="$HOME/bin"
ASSET="xcb-macos-universal.tar.gz"
if [[ -n "${XCB_INSTALL_VERSION:-}" ]]; then
    BASE_URL="https://github.com/bentford/xcb/releases/download/$XCB_INSTALL_VERSION"
else
    BASE_URL="https://github.com/bentford/xcb/releases/latest/download"
fi

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "Error: xcb release builds are for macOS only." >&2
    echo "To build from source, see https://github.com/bentford/xcb/blob/main/CONTRIBUTING.md" >&2
    exit 1
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "Downloading xcb..."
if ! curl -fsSL "$BASE_URL/$ASSET" -o "$tmp/$ASSET" ||
   ! curl -fsSL "$BASE_URL/$ASSET.sha256" -o "$tmp/$ASSET.sha256"; then
    echo "Error: Failed to download xcb from $BASE_URL" >&2
    exit 1
fi

if ! (cd "$tmp" && shasum -a 256 -c "$ASSET.sha256" >/dev/null 2>&1); then
    echo "Error: Checksum verification failed for $ASSET" >&2
    exit 1
fi

tar -xzf "$tmp/$ASSET" -C "$tmp"
mkdir -p "$INSTALL_DIR"
# mv replaces the file rather than overwriting it in place, which is safe
# even while the old xcb is running (e.g. during `xcb --update`).
mv -f "$tmp/xcb" "$INSTALL_DIR/xcb"
chmod +x "$INSTALL_DIR/xcb"

if ! echo "$PATH" | tr ':' '\n' | grep -qx "$INSTALL_DIR"; then
    shell_name="$(basename "$SHELL")"
    case "$shell_name" in
        zsh)  rc_file="~/.zshrc" ;;
        bash) rc_file="~/.bashrc" ;;
        *)    rc_file="your shell's rc file" ;;
    esac
    echo ""
    echo "Note: $INSTALL_DIR is not in your PATH."
    echo "Add it by running:"
    echo ""
    echo "  echo 'export PATH=\"\$HOME/bin:\$PATH\"' >> $rc_file"
    echo ""
fi

echo "$("$INSTALL_DIR/xcb" --version) installed successfully!"
