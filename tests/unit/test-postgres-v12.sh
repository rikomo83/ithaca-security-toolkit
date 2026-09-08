#!/usr/bin/env bash
set -u

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ITHACA_BASE_DIR="$(cd "$TEST_DIR/../.." && pwd -P)"
export ITHACA_BASE_DIR

source "$ITHACA_BASE_DIR/core/bootstrap.sh"
source "$ITHACA_BASE_DIR/core/runner.sh"

PG_ACTIVE=yes
PG_SOCKETS=""

systemctl() {
    [[ "${1:-}" == "is-active" &&
       "${3:-}" == "postgresql" &&
       "$PG_ACTIVE" == yes ]]
}

ss() {
    printf '%s\n' "$PG_SOCKETS"
}

failures=0
ithaca_core_init
source "$ITHACA_BASE_DIR/modules-v12/postgres.sh"
_ithaca_registry_lock

PG_SOCKETS='LISTEN 0 244 127.0.0.1:5432 0.0.0.0:*'
_ithaca_run_registered_check_id "postgres.service"
_ithaca_run_registered_check_id "postgres.listener"
[[ "${#ITHACA_CHECK_IDS[@]}" == 2 ]] || failures=$((failures + 1))
[[ "${ITHACA_RESULT_STATUSES[0]}" == OK &&
   "${ITHACA_RESULT_MESSAGES[0]}" == "PostgreSQL attivo" ]] || failures=$((failures + 1))
[[ "${ITHACA_RESULT_STATUSES[1]}" == OK &&
   "${ITHACA_RESULT_MESSAGES[1]}" == "PostgreSQL ascolta solo localmente" ]] || failures=$((failures + 1))

_ithaca_results_reset
PG_ACTIVE=no
PG_SOCKETS='LISTEN 0 244 0.0.0.0:5432 0.0.0.0:*'
_ithaca_run_registered_check_id "postgres.service"
_ithaca_run_registered_check_id "postgres.listener"
[[ "${ITHACA_RESULT_STATUSES[0]}" == WARN &&
   "${ITHACA_RESULT_MESSAGES[0]}" == "PostgreSQL non attivo" ]] || failures=$((failures + 1))
[[ "${ITHACA_RESULT_STATUSES[1]}" == CRITICAL &&
   "${ITHACA_RESULT_MESSAGES[1]}" == "PostgreSQL esposto su rete" ]] || failures=$((failures + 1))

_ithaca_results_reset
PG_SOCKETS=''
_ithaca_run_registered_check_id "postgres.listener"
[[ "${ITHACA_RESULT_STATUSES[0]}" == WARN &&
   "${ITHACA_RESULT_MESSAGES[0]}" == "PostgreSQL porta 5432 non rilevata" ]] || failures=$((failures + 1))

if (( failures == 0 )); then
    printf 'ok 1 - registra ed esegue i check postgresql v1.2\n'
    printf 'ok 2 - distingue listener locale, esposto e assente\n'
    printf '2 test superati\n'
    exit 0
fi

printf 'not ok 1 - modulo postgresql v1.2 non conforme (%s errori)\n' "$failures" >&2
exit 1
