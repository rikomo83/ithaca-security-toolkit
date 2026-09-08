#!/usr/bin/env bash
set -u

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ITHACA_BASE_DIR="$(cd "$TEST_DIR/../.." && pwd -P)"
export ITHACA_BASE_DIR

source "$ITHACA_BASE_DIR/core/bootstrap.sh"
source "$ITHACA_BASE_DIR/core/runner.sh"

GEOSERVER_PORT=yes
GEOSERVER_JAVA=yes

ss() {
    [[ "$GEOSERVER_PORT" == yes ]] &&
        printf 'LISTEN 0 100 127.0.0.1:8080 0.0.0.0:*\n'
}

pgrep() {
    [[ "${1:-}" == "-f" && "${2:-}" == "java" && "$GEOSERVER_JAVA" == yes ]]
}

failures=0
ithaca_core_init
source "$ITHACA_BASE_DIR/modules-v12/geoserver.sh"
_ithaca_registry_lock

_ithaca_run_registered_check_id "geoserver.port"
_ithaca_run_registered_check_id "geoserver.java"
[[ "${#ITHACA_CHECK_IDS[@]}" == 2 ]] || failures=$((failures + 1))
[[ "${ITHACA_RESULT_STATUSES[0]}" == OK &&
   "${ITHACA_RESULT_MESSAGES[0]}" == "GeoServer/Java porta 8080 attiva" ]] || failures=$((failures + 1))
[[ "${ITHACA_RESULT_STATUSES[1]}" == OK &&
   "${ITHACA_RESULT_MESSAGES[1]}" == "Processo Java rilevato" ]] || failures=$((failures + 1))

_ithaca_results_reset
GEOSERVER_PORT=no
GEOSERVER_JAVA=no
_ithaca_run_registered_check_id "geoserver.port"
_ithaca_run_registered_check_id "geoserver.java"
[[ "${ITHACA_RESULT_STATUSES[0]}" == WARN &&
   "${ITHACA_RESULT_MESSAGES[0]}" == "Porta 8080 non rilevata" ]] || failures=$((failures + 1))
[[ "${ITHACA_RESULT_STATUSES[1]}" == WARN &&
   "${ITHACA_RESULT_MESSAGES[1]}" == "Processo Java non rilevato" ]] || failures=$((failures + 1))

if (( failures == 0 )); then
    printf 'ok 1 - registra ed esegue i check geoserver v1.2\n'
    printf 'ok 2 - distingue porta e processo presenti o assenti\n'
    printf '2 test superati\n'
    exit 0
fi

printf 'not ok 1 - modulo geoserver v1.2 non conforme (%s errori)\n' "$failures" >&2
exit 1
