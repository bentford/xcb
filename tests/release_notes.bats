#!/usr/bin/env bats
# Tests for scripts/release-notes.sh — runs against a copy with a fixture CHANGELOG.

load test_helper

setup() {
    TEST_DIR="$(mktemp -d)"
    mkdir -p "$TEST_DIR/scripts"
    cp "$REPO_ROOT/scripts/release-notes.sh" "$TEST_DIR/scripts/"
    cat > "$TEST_DIR/CHANGELOG.md" <<'EOF'
# Changelog

## [Unreleased]

- Work in progress.

## [0.2.0]

### Changed

- Rewritten in Swift.

## [0.1.2]

### Added

- `--version` flag.
EOF
    cd "$TEST_DIR"
}

teardown() {
    rm -rf "$TEST_DIR"
}

@test "prints the section for a version without its heading" {
    run ./scripts/release-notes.sh 0.2.0
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "### Changed" ]
    [[ "$output" == *"- Rewritten in Swift."* ]]
    [[ "$output" != *"0.1.2"* ]]
    [[ "$output" != *"Unreleased"* ]]
}

@test "prints the last section through end of file" {
    run ./scripts/release-notes.sh 0.1.2
    [ "$status" -eq 0 ]
    [[ "$output" == *'- `--version` flag.'* ]]
}

@test "prints nothing for an unknown version" {
    run ./scripts/release-notes.sh 9.9.9
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "dots in the version are not treated as wildcards" {
    run ./scripts/release-notes.sh 0x2x0
    [ -z "$output" ]
}
