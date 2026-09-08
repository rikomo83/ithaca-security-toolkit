#!/usr/bin/env bash
set -u

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ITHACA_BASE_DIR="$(cd "$TEST_DIR/../.." && pwd -P)"
export ITHACA_BASE_DIR

source "$ITHACA_BASE_DIR/core/bootstrap.sh"
source "$ITHACA_BASE_DIR/core/runner.sh"

sshd() {
    printf 'passwordauthentication no\n'
    printf 'permitrootlogin no\n'
}

ithaca_core_init
source "$ITHACA_BASE_DIR/modules-v12/ssh.sh"
_ithaca_registry_lock
_ithaca_run_registered_check_id "ssh.password_authentication"
_ithaca_run_registered_check_id "ssh.root_login"

if [[ "${#ITHACA_CHECK_IDS[@]}" == 2 &&
      "${ITHACA_RESULT_STATUSES[0]}" == OK &&
      "${ITHACA_RESULT_MESSAGES[0]}" == "SSH password disabilitata" &&
      "${ITHACA_RESULT_STATUSES[1]}" == OK &&
      "${ITHACA_RESULT_MESSAGES[1]}" == "Root login SSH disabilitato" ]]; then
    printf 'ok 1 - registra ed esegue i check ssh v1.2\n'
    printf '1 test superato\n'
    exit 0
fi

printf 'not ok 1 - modulo ssh v1.2 non conforme\n' >&2
exit 1
