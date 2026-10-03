#!/usr/bin/env bash
# Bump (or revert) the patch version in VERSION and sync xcbVersion in Version.swift.
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

# Update the `let xcbVersion = "x.y.z"` line in Version.swift
version_swift="Sources/XCBCore/Version.swift"
if ! grep -q '^let xcbVersion = "' "$version_swift"; then
    echo "Error: xcbVersion line not found in $version_swift" >&2
    exit 1
fi
tmp=$(mktemp)
sed "s/^let xcbVersion = \".*\"/let xcbVersion = \"$new\"/" "$version_swift" > "$tmp"
mv "$tmp" "$version_swift"

if (( direction > 0 )); then
    echo "Bumped: $current -> $new"
else
    echo "Reverted: $current -> $new"
fi
