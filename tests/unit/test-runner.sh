#!/usr/bin/env bash
set -u

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ITHACA_BASE_DIR="$(cd "$TEST_DIR/../.." && pwd -P)"
export ITHACA_BASE_DIR

source "$ITHACA_BASE_DIR/core/bootstrap.sh"
source "$ITHACA_BASE_DIR/core/runner.sh"

TESTS=0
FAILURES=0

assert_equal() {
    local expected="$1" actual="$2" description="$3"
    TESTS=$((TESTS + 1))
    if [[ "$expected" == "$actual" ]]; then
        printf 'ok %s - %s\n' "$TESTS" "$description"
    else
        FAILURES=$((FAILURES + 1))
        printf 'not ok %s - %s (atteso=%s, ottenuto=%s)\n' \
            "$TESTS" "$description" "$expected" "$actual"
    fi
}

check_runner_ok() { result_ok "runner.ok" "OK"; }
check_runner_empty() { return 0; }
check_runner_failure() { return 7; }

ithaca_core_init
register_check "runner.ok" "check_runner_ok" "system" "Successful check"
register_check "runner.empty" "check_runner_empty" "other" "Empty check"
register_check "runner.failure" "check_runner_failure" "other" "Failed check"
_ithaca_registry_lock

_ithaca_run_registered_checks system
assert_equal "1" "${#ITHACA_RESULT_STATUSES[@]}" "filtra i check per categoria"
assert_equal "OK" "${ITHACA_RESULT_STATUSES[0]}" "mantiene il risultato del check"

_ithaca_results_reset
_ithaca_run_registered_check_id "runner.ok"
assert_equal "1" "${#ITHACA_RESULT_STATUSES[@]}" "esegue un check per ID"
duration_valid=no
[[ "${ITHACA_RESULT_DURATIONS_MS[0]}" =~ ^[0-9]+$ ]] && duration_valid=yes
assert_equal "yes" "$duration_valid" "assegna la durata del check in millisecondi"

_ithaca_results_reset
_ithaca_run_registered_checks other
assert_equal "2" "${#ITHACA_RESULT_STATUSES[@]}" "esegue tutti i check della categoria"
assert_equal "ERROR" "${ITHACA_RESULT_STATUSES[0]}" "segnala un check senza risultato"
assert_equal "ERROR" "${ITHACA_RESULT_STATUSES[1]}" "segnala un ritorno non-zero"

(( FAILURES == 0 )) || exit 1
printf '%s test superati\n' "$TESTS"
