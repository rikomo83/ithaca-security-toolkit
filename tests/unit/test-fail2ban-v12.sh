#!/usr/bin/env bash
set -u

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ITHACA_BASE_DIR="$(cd "$TEST_DIR/../.." && pwd -P)"
export ITHACA_BASE_DIR

source "$ITHACA_BASE_DIR/core/bootstrap.sh"
source "$ITHACA_BASE_DIR/core/runner.sh"

systemctl() {
    [[ "${1:-}" == "is-active" && "${3:-}" == "fail2ban" ]]
}

fail2ban-client() {
    printf 'Status\n'
    printf 'Number of jail: 7\n'
}

ithaca_core_init
source "$ITHACA_BASE_DIR/modules-v12/fail2ban.sh"
_ithaca_registry_lock
_ithaca_run_registered_check_id "fail2ban.status"

if [[ "${#ITHACA_CHECK_IDS[@]}" == 1 &&
      "${ITHACA_RESULT_STATUSES[0]}" == OK &&
      "${ITHACA_RESULT_MESSAGES[0]}" == "Fail2Ban attivo (7 jail)" ]]; then
    printf 'ok 1 - registra ed esegue il check fail2ban v1.2\n'
    printf '1 test superato\n'
    exit 0
fi

printf 'not ok 1 - modulo fail2ban v1.2 non conforme\n' >&2
exit 1
