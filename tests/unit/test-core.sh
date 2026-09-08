#!/usr/bin/env bash
set -u

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ITHACA_BASE_DIR="$(cd "$TEST_DIR/../.." && pwd -P)"
export ITHACA_BASE_DIR

# shellcheck source=core/bootstrap.sh
source "$ITHACA_BASE_DIR/core/bootstrap.sh"

TESTS=0
FAILURES=0

pass() {
    TESTS=$((TESTS + 1))
    printf 'ok %s - %s\n' "$TESTS" "$1"
}

fail() {
    TESTS=$((TESTS + 1))
    FAILURES=$((FAILURES + 1))
    printf 'not ok %s - %s\n' "$TESTS" "$1"
}

assert_equal() {
    local expected="$1"
    local actual="$2"
    local description="$3"
    [[ "$expected" == "$actual" ]] && pass "$description" ||
        fail "$description (atteso=$expected, ottenuto=$actual)"
}

check_test_service() { :; }
check_second_service() { :; }

ithaca_core_init

register_check "test.service" "check_test_service" "system" "Test service" "yes" "15"
assert_equal "1" "${#ITHACA_CHECK_IDS[@]}" "registra un check valido"
assert_equal "check_test_service" "${ITHACA_CHECK_FUNCTIONS[test.service]}" "memorizza la funzione"
assert_equal "15" "${ITHACA_CHECK_TIMEOUTS[test.service]}" "memorizza il timeout"

if register_check "test.service" "check_test_service" "system" "Duplicato"; then
    fail "rifiuta ID duplicati"
else
    pass "rifiuta ID duplicati"
fi
assert_equal "duplicate_check_id" "$ITHACA_ERROR_CODE" "espone il codice di errore del duplicato"

if register_check "Invalid" "check_second_service" "system" "ID invalido"; then
    fail "rifiuta ID non validi"
else
    pass "rifiuta ID non validi"
fi

if register_check "test.undefined" "check_missing_service" "system" "Funzione assente"; then
    fail "rifiuta funzioni non definite"
else
    pass "rifiuta funzioni non definite"
fi

register_check "test.second" "check_second_service" "security" "Second service" "no" "30"
_ithaca_registry_lock
if register_check "test.locked" "check_second_service" "system" "Registro chiuso"; then
    fail "rifiuta registrazioni dopo il lock"
else
    pass "rifiuta registrazioni dopo il lock"
fi

result_ok "test.service" "Servizio attivo"
result_warn "test.service" "Configurazione migliorabile"
result_critical "test.second" "Servizio non attivo"
result_skip "test.second" "Non applicabile"

assert_equal "4" "${#ITHACA_RESULT_STATUSES[@]}" "registra tutti gli stati"
assert_equal "1" "$(_ithaca_result_count WARN)" "conta i warning"
assert_equal "1" "$(_ithaca_result_count CRITICAL)" "conta i critical"
assert_equal "87" "$(_ithaca_legacy_score)" "preserva la formula score v1.1"

if (( FAILURES > 0 )); then
    printf '%s test falliti su %s\n' "$FAILURES" "$TESTS" >&2
    exit 1
fi

printf '%s test superati\n' "$TESTS"
