#!/usr/bin/env bash
# Bump (or revert) the patch version in VERSION and sync XCB_VERSION in xcb.
#   bump-version.sh                    increment patch
#   bump-version.sh --revert-version   decrement patch
set -euo pipefail

cd "$(dirname "$0")/.."

direction=1
case "${1:-}" in
    "") ;;
    --revert-version) direction=-1 ;;
    -h|--help)
        sed -n '2,5p' "$0" | sed 's/^# \?//'
        exit 0
        ;;
    *)
        echo "Error: unknown option '$1'" >&2
        exit 1
        ;;
esac

if [[ ! -f VERSION ]]; then
    echo "Error: VERSION file not found" >&2
    exit 1
fi

current=$(tr -d '[:space:]' < VERSION)

if [[ ! "$current" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    echo "Error: VERSION '$current' is not semver (x.y.z)" >&2
    exit 1
fi

major="${BASH_REMATCH[1]}"
minor="${BASH_REMATCH[2]}"
patch="${BASH_REMATCH[3]}"
new_patch=$((patch + direction))

if (( new_patch < 0 )); then
    echo "Error: cannot revert below ${major}.${minor}.0" >&2
    exit 1
fi

new="${major}.${minor}.${new_patch}"

echo "$new" > VERSION

# Update XCB_VERSION="x.y.z" line in xcb
if ! grep -q '^XCB_VERSION="' xcb; then
    echo "Error: XCB_VERSION line not found in xcb" >&2
    exit 1
fi
tmp=$(mktemp)
sed "s/^XCB_VERSION=\".*\"/XCB_VERSION=\"$new\"/" xcb > "$tmp"
mv "$tmp" xcb
chmod +x xcb

if (( direction > 0 )); then
    echo "Bumped: $current -> $new"
else
    echo "Reverted: $current -> $new"
fi
