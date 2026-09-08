#!/usr/bin/env bash
set -u

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ITHACA_BASE_DIR="$(cd "$TEST_DIR/../.." && pwd -P)"
export ITHACA_BASE_DIR

source "$ITHACA_BASE_DIR/core/bootstrap.sh"
source "$ITHACA_BASE_DIR/core/runner.sh"

CERT_DAYS=90

certbot() {
    printf '  Expiry Date: 2026-12-01 00:00:00+00:00 VALID: (%s days)\n' "$CERT_DAYS"
}

failures=0
ithaca_core_init
source "$ITHACA_BASE_DIR/modules-v12/certs.sh"
_ithaca_registry_lock

_ithaca_run_registered_check_id "certs.expiry"
[[ "${#ITHACA_CHECK_IDS[@]}" == 1 ]] || failures=$((failures + 1))
[[ "${ITHACA_RESULT_STATUSES[0]}" == OK &&
   "${ITHACA_RESULT_MESSAGES[0]}" == "Certificati validi oltre 30 giorni" &&
   -z "${ITHACA_RESULT_DETAILS[0]}" ]] || failures=$((failures + 1))

_ithaca_results_reset
CERT_DAYS=10
_ithaca_run_registered_check_id "certs.expiry"
[[ "${ITHACA_RESULT_STATUSES[0]}" == WARN &&
   "${ITHACA_RESULT_MESSAGES[0]}" == "Certificati in scadenza entro 30 giorni" ]] || failures=$((failures + 1))
[[ "${ITHACA_RESULT_DETAILS[0]}" == *"VALID: 10 days"* ]] || failures=$((failures + 1))

if (( failures == 0 )); then
    printf 'ok 1 - registra ed esegue il check certificati v1.2\n'
    printf 'ok 2 - conserva i dettagli dei certificati in scadenza\n'
    printf '2 test superati\n'
    exit 0
fi

printf 'not ok 1 - modulo certificati v1.2 non conforme (%s errori)\n' "$failures" >&2
exit 1
