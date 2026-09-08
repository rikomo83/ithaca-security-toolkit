#!/usr/bin/env bash
set -u

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ITHACA_BASE_DIR="$(cd "$TEST_DIR/../.." && pwd -P)"
export ITHACA_BASE_DIR

source "$ITHACA_BASE_DIR/core/bootstrap.sh"
source "$ITHACA_BASE_DIR/core/legacy-adapter.sh"

TESTS=0
FAILURES=0

assert_equal() {
    local expected="$1"
    local actual="$2"
    local description="$3"
    TESTS=$((TESTS + 1))
    if [[ "$expected" == "$actual" ]]; then
        printf 'ok %s - %s\n' "$TESTS" "$description"
    else
        FAILURES=$((FAILURES + 1))
        printf 'not ok %s - %s (atteso=%s, ottenuto=%s)\n' \
            "$TESTS" "$description" "$expected" "$actual"
    fi
}

ithaca_core_init
legacy_parse_report "$ITHACA_BASE_DIR/tests/fixtures/legacy-report.txt"
parse_rc=$?

assert_equal "0" "$parse_rc" "converte un report Sentinel valido"
assert_equal "4" "${#ITHACA_RESULT_STATUSES[@]}" "importa quattro risultati"
assert_equal "1" "$(_ithaca_result_count WARN)" "importa il warning"
assert_equal "1" "$(_ithaca_result_count CRITICAL)" "importa il critical"
assert_equal "87" "$(_ithaca_legacy_score)" "calcola lo score Sentinel"
assert_equal "1" "$ITHACA_LEGACY_ADAPTER_MATCH" "conferma la parita del riepilogo"
assert_equal "legacy.system.check001" "${ITHACA_RESULT_CHECK_IDS[0]}" "assegna ID deterministici"
assert_equal "legacy.firewall.check003" "${ITHACA_RESULT_CHECK_IDS[2]}" "mantiene la sezione"

if (( FAILURES > 0 )); then
    printf '%s test falliti su %s\n' "$FAILURES" "$TESTS" >&2
    exit 1
fi

printf '%s test superati\n' "$TESTS"
