#!/usr/bin/env bash
set -e

INSTALL_DIR="$HOME/bin"
XCB_URL="https://raw.githubusercontent.com/bentford/xcb/main/xcb"

mkdir -p "$INSTALL_DIR"

echo "Downloading xcb to $INSTALL_DIR/xcb..."
if ! curl -fsSL "$XCB_URL" -o "$INSTALL_DIR/xcb"; then
    echo "Error: Failed to download xcb." >&2
    exit 1
fi

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

echo "xcb installed successfully!"
