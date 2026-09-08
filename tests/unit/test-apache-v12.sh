#!/usr/bin/env bash
set -u

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ITHACA_BASE_DIR="$(cd "$TEST_DIR/../.." && pwd -P)"
export ITHACA_BASE_DIR

source "$ITHACA_BASE_DIR/core/bootstrap.sh"
source "$ITHACA_BASE_DIR/core/runner.sh"

apache2ctl() {
    [[ "${1:-}" == "configtest" ]]
}

systemctl() {
    [[ "${1:-}" == "is-active" && "${3:-}" == "apache2" ]]
}

ithaca_core_init
source "$ITHACA_BASE_DIR/modules-v12/apache.sh"
_ithaca_registry_lock
_ithaca_run_registered_check_id "apache.config"
_ithaca_run_registered_check_id "apache.service"

if [[ "${#ITHACA_CHECK_IDS[@]}" == 2 &&
      "${ITHACA_RESULT_STATUSES[0]}" == OK &&
      "${ITHACA_RESULT_MESSAGES[0]}" == "Apache config Syntax OK" &&
      "${ITHACA_RESULT_STATUSES[1]}" == OK &&
      "${ITHACA_RESULT_MESSAGES[1]}" == "Apache attivo" ]]; then
    printf 'ok 1 - registra ed esegue i check apache v1.2\n'
    printf '1 test superato\n'
    exit 0
fi

printf 'not ok 1 - modulo apache v1.2 non conforme\n' >&2
exit 1
