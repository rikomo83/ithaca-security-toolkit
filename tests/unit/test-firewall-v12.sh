#!/usr/bin/env bash
set -u

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ITHACA_BASE_DIR="$(cd "$TEST_DIR/../.." && pwd -P)"
export ITHACA_BASE_DIR

source "$ITHACA_BASE_DIR/core/bootstrap.sh"
source "$ITHACA_BASE_DIR/core/runner.sh"

ufw() { printf 'Status: active\n'; }

ithaca_core_init
source "$ITHACA_BASE_DIR/modules-v12/firewall.sh"
_ithaca_registry_lock
_ithaca_run_registered_check_id "firewall.status"

if [[ "${#ITHACA_CHECK_IDS[@]}" == 1 &&
      "${ITHACA_RESULT_STATUSES[0]}" == OK &&
      "${ITHACA_RESULT_MESSAGES[0]}" == "UFW attivo" ]]; then
    printf 'ok 1 - registra ed esegue il check firewall v1.2\n'
    printf '1 test superato\n'
    exit 0
fi

printf 'not ok 1 - modulo firewall v1.2 non conforme\n' >&2
exit 1
