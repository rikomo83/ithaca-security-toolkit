#!/usr/bin/env bash
set -u

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ITHACA_BASE_DIR="$(cd "$TEST_DIR/../.." && pwd -P)"
export ITHACA_BASE_DIR

source "$ITHACA_BASE_DIR/core/bootstrap.sh"
source "$ITHACA_BASE_DIR/core/runner.sh"

systemctl() { return 0; }
df() {
    printf 'Use%% Mounted on\n'
    printf ' 90%% /\n'
}

ithaca_core_init
source "$ITHACA_BASE_DIR/modules-v12/system.sh"
_ithaca_registry_lock
_ithaca_run_registered_checks system

failures=0
[[ "${#ITHACA_CHECK_IDS[@]}" == 2 ]] || failures=$((failures + 1))
[[ "${ITHACA_RESULT_STATUSES[0]}" == OK ]] || failures=$((failures + 1))
[[ "${ITHACA_RESULT_MESSAGES[0]}" == "Nessun servizio systemd in errore" ]] || failures=$((failures + 1))
[[ "${ITHACA_RESULT_STATUSES[1]}" == WARN ]] || failures=$((failures + 1))
[[ "${ITHACA_RESULT_MESSAGES[1]}" == "Partizioni oltre 85%:" ]] || failures=$((failures + 1))
[[ "${ITHACA_RESULT_DETAILS[1]}" == *"90"* ]] || failures=$((failures + 1))

if (( failures == 0 )); then
    printf 'ok 1 - registra ed esegue i check system v1.2\n'
    printf '1 test superato\n'
    exit 0
fi

printf 'not ok 1 - modulo system v1.2 non conforme (%s errori)\n' "$failures" >&2
exit 1
