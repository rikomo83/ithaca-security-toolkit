#!/usr/bin/env bash
set -u

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ITHACA_BASE_DIR="$(cd "$TEST_DIR/../.." && pwd -P)"
export ITHACA_BASE_DIR

source "$ITHACA_BASE_DIR/core/bootstrap.sh"
source "$ITHACA_BASE_DIR/core/runner.sh"

ARC_SERVICE="himdsd"
PATCH_FAILED=no

systemctl() {
    case "${1:-}" in
        is-active)
            [[ "${3:-}" == "$ARC_SERVICE" ]]
            ;;
        is-failed)
            [[ "${3:-}" == "MsftLinuxPatchAutoAssess.service" &&
               "$PATCH_FAILED" == yes ]]
            ;;
        *) return 1 ;;
    esac
}

failures=0
ithaca_core_init
source "$ITHACA_BASE_DIR/modules-v12/azurearc.sh"
_ithaca_registry_lock

_ithaca_run_registered_check_id "azurearc.status"
[[ "${#ITHACA_CHECK_IDS[@]}" == 1 ]] || failures=$((failures + 1))
[[ "${#ITHACA_RESULT_STATUSES[@]}" == 1 &&
   "${ITHACA_RESULT_STATUSES[0]}" == OK &&
   "${ITHACA_RESULT_MESSAGES[0]}" == "Azure Arc servizi attivi" ]] || failures=$((failures + 1))

_ithaca_results_reset
ARC_SERVICE="none"
PATCH_FAILED=yes
_ithaca_run_registered_check_id "azurearc.status"
[[ "${#ITHACA_RESULT_STATUSES[@]}" == 2 ]] || failures=$((failures + 1))
[[ "${ITHACA_RESULT_STATUSES[0]}" == WARN &&
   "${ITHACA_RESULT_MESSAGES[0]}" == "Azure Arc non rilevato" ]] || failures=$((failures + 1))
[[ "${ITHACA_RESULT_STATUSES[1]}" == WARN &&
   "${ITHACA_RESULT_MESSAGES[1]}" == "Azure Patch Assessment extension in errore" ]] || failures=$((failures + 1))

if (( failures == 0 )); then
    printf 'ok 1 - registra ed esegue il check azure arc v1.2\n'
    printf 'ok 2 - preserva il risultato patch condizionale di Sentinel\n'
    printf '2 test superati\n'
    exit 0
fi

printf 'not ok 1 - modulo azure arc v1.2 non conforme (%s errori)\n' "$failures" >&2
exit 1
