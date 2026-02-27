#!/usr/bin/env bats

setup() {
    load test_helper
    setup

    # Source color vars and functions from xcb (stop before main logic)
    eval "$(sed -n '9,16p' "$XCB")"      # color variables
    eval "$(sed -n '28,48p' "$XCB")"      # show_error_summary()
}

teardown() {
    teardown
}

@test "show_error_summary --grep-errors extracts Swift Testing failures" {
    GREP_ERRORS=true
    cat > "$TEST_DIR/build.log" <<'EOF'
note: Build complete!
◇ Test run started.
◇ Suite MyTests started.
◇ Test myPassingTest() started.
✔ Test myPassingTest() passed after 0.001 seconds.
◇ Test myFailingTest() started.
✘ Test myFailingTest() recorded an issue at MyTests.swift:42:9: Expectation failed: (a → 1) == (2)
✘ Test myFailingTest() failed after 0.010 seconds with 1 issue.
✘ Suite MyTests failed after 0.011 seconds with 1 issue.
✘ Test run with 2 tests failed after 0.011 seconds with 1 issue.
EOF

    run show_error_summary "$TEST_DIR/build.log" true
    local out
    out=$(echo "$output" | strip_ansi)
    [[ "$out" == *'recorded an issue at MyTests.swift:42:9'* ]]
    [[ "$out" == *'Expectation failed'* ]]
    [[ "$out" == *'Suite MyTests failed'* ]]
    [[ "$out" != *'myPassingTest'* ]]
    [[ "$out" != *'Build complete'* ]]
}

@test "show_error_summary --grep-errors extracts XCTest failures" {
    GREP_ERRORS=true
    cat > "$TEST_DIR/build.log" <<'EOF'
note: Build complete!
Test Suite 'All tests' started
Test Case '-[MyTests testSomething]' started.
/path/to/MyTests.swift:42: error: -[MyTests testSomething] : XCTAssertEqual failed: ("foo") is not equal to ("bar")
Test Case '-[MyTests testSomething]' failed (0.001 seconds).
Test Suite 'MyTests' failed
EOF

    run show_error_summary "$TEST_DIR/build.log" true
    local out
    out=$(echo "$output" | strip_ansi)
    [[ "$out" == *'XCTAssertEqual failed'* ]]
    [[ "$out" == *'error: -[MyTests testSomething]'* ]]
    [[ "$out" != *'Build complete'* ]]
}

@test "show_error_summary --grep-errors prints nothing when no failures" {
    GREP_ERRORS=true
    cat > "$TEST_DIR/build.log" <<'EOF'
note: Build complete!
◇ Test run started.
✔ Test myPassingTest() passed after 0.001 seconds.
EOF

    run show_error_summary "$TEST_DIR/build.log" true
    local out
    out=$(echo "$output" | strip_ansi)
    [[ -z "$(echo "$out" | sed '/^[[:space:]]*$/d')" ]]
}
