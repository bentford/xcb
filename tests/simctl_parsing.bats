#!/usr/bin/env bats
# Tests for simulator list parsing regex

load test_helper

# Runs the simctl parsing regex against provided input lines and prints
# matched entries as "name|uuid|os" (one per line).
parse_simulators() {
    local simulators=()
    local current_os=""
    while IFS= read -r line; do
        if [[ "$line" =~ ^--\ iOS\ (.+)\ --$ ]]; then
            current_os="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^-- ]]; then
            current_os=""
        elif [[ -n "$current_os" ]] && SIM_RE='^[[:space:]]+(.+) \(([A-F0-9-]{36})\)' && [[ "$line" =~ $SIM_RE ]]; then
            name="${BASH_REMATCH[1]}"
            uuid="${BASH_REMATCH[2]}"
            simulators+=("${name}|${uuid}|${current_os}")
        fi
    done
    for entry in "${simulators[@]}"; do
        echo "$entry"
    done
}

@test "parses standard simctl device line" {
    result=$(parse_simulators <<'EOF'
-- iOS 18.0 --
    iPhone 16 (AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE) (Shutdown)
EOF
)
    [[ "$result" == "iPhone 16|AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE|18.0" ]]
}

@test "parses booted simulator" {
    result=$(parse_simulators <<'EOF'
-- iOS 18.0 --
    iPhone 16 Pro Max (AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE) (Booted)
EOF
)
    [[ "$result" == "iPhone 16 Pro Max|AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE|18.0" ]]
}

@test "parses multiple devices across OS versions" {
    result=$(parse_simulators <<'EOF'
-- iOS 17.5 --
    iPhone 15 (11111111-2222-3333-4444-555555555555) (Shutdown)
-- iOS 18.0 --
    iPhone 16 (AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE) (Shutdown)
    iPhone 16 Pro (FFFFFFFF-1111-2222-3333-444444444444) (Booted)
EOF
)
    local count
    count=$(echo "$result" | wc -l | tr -d ' ')
    [[ "$count" -eq 3 ]]
    [[ "$result" == *"iPhone 15|11111111-2222-3333-4444-555555555555|17.5"* ]]
    [[ "$result" == *"iPhone 16|AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE|18.0"* ]]
    [[ "$result" == *"iPhone 16 Pro|FFFFFFFF-1111-2222-3333-444444444444|18.0"* ]]
}

@test "parses iPad simulators with parentheses in name" {
    result=$(parse_simulators <<'EOF'
-- iOS 18.0 --
    iPad Pro (13-inch) (M4) (AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE) (Shutdown)
EOF
)
    [[ "$result" == "iPad Pro (13-inch) (M4)|AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE|18.0" ]]
}

@test "skips non-iOS sections" {
    result=$(parse_simulators <<'EOF'
== Devices ==
-- iOS 18.0 --
    iPhone 16 (AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE) (Shutdown)
-- tvOS 18.0 --
    Apple TV (FFFFFFFF-1111-2222-3333-444444444444) (Shutdown)
EOF
)
    local count
    count=$(echo "$result" | wc -l | tr -d ' ')
    [[ "$count" -eq 1 ]]
    [[ "$result" == "iPhone 16|AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE|18.0" ]]
}

@test "handles no devices" {
    result=$(parse_simulators <<'EOF'
== Devices ==
EOF
)
    [[ -z "$result" ]]
}
