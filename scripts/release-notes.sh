#!/usr/bin/env bash
# Print the CHANGELOG.md section for a version (without its heading).
#   release-notes.sh 0.2.0
# Prints nothing if there is no "## [0.2.0]" section.
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <version>" >&2
    exit 1
fi

awk -v heading="## [$1]" '
    index($0, heading) == 1 { found = 1; next }
    found && /^## \[/ { exit }
    found { print }
' CHANGELOG.md | sed -e '/./,$!d'
