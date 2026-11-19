#!/usr/bin/env bash
set -u

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ITHACA_BASE_DIR="$(cd "$TEST_DIR/../.." && pwd -P)"
export ITHACA_BASE_DIR

source "$ITHACA_BASE_DIR/core/bootstrap.sh"
source "$ITHACA_BASE_DIR/core/runner.sh"
ITHACA_CONFIG_VALUES[FAIL2BAN]="yes"

MOCK_MATCH_UNIT=sshd.service
MOCK_JAIL=present

fail2ban-client() {
    if [[ "$MOCK_JAIL" != present ]]; then
        printf 'Sorry but the jail %s does not exist\n' "'sshd'"
        return 255
    fi
    printf '%s\n' \
        'Status for the jail: sshd' \
        '|- Filter' \
        '|  |- Currently failed: 1' \
        '|  |- Total failed:     12' \
        "|  \`- Journal matches:  _SYSTEMD_UNIT=${MOCK_MATCH_UNIT} + _COMM=sshd" \
        "\`- Actions" \
        '   |- Currently banned: 1' \
        '   |- Total banned:     4' \
        '   `- Banned IP list:   2001:db8::10'
}

# Su Ubuntu sshd.service e un alias di ssh.service.
systemctl() {
    if [[ "${1:-}" == show && "${5:-}" == sshd.service ]]; then
        printf 'ssh.service\n'
    elif [[ "${1:-}" == show ]]; then
        printf '%s\n' "${5:-}"
    fi
}

ithaca_core_init
source "$ITHACA_BASE_DIR/modules-v12/fail2ban.sh"
_ithaca_registry_lock

failures=0
fail() { printf 'not ok - %s\n' "$1" >&2; failures=$((failures + 1)); }

_ithaca_run_registered_check_id "fail2ban.sshd_jail"
MOCK_MATCH_UNIT=ssh.service
_ithaca_run_registered_check_id "fail2ban.sshd_jail"
MOCK_JAIL=missing
_ithaca_run_registered_check_id "fail2ban.sshd_jail"
ITHACA_CONFIG_VALUES[FAIL2BAN]="no"
_ithaca_run_registered_check_id "fail2ban.sshd_jail"

[[ "${ITHACA_RESULT_STATUSES[0]}" == CRITICAL &&
   "${ITHACA_RESULT_DETAILS[0]}" == *"_SYSTEMD_UNIT=ssh.service"* ]] || fail "jail cieca su alias"
[[ "${ITHACA_RESULT_STATUSES[1]}" == OK &&
   "${ITHACA_RESULT_MESSAGES[1]}" == "Jail sshd attiva (falliti totali 12, ban totali 4)" ]] ||
    fail "jail corretta: ${ITHACA_RESULT_MESSAGES[1]}"
[[ "${ITHACA_RESULT_STATUSES[2]}" == CRITICAL ]] || fail "jail mancante"
[[ "${ITHACA_RESULT_STATUSES[3]}" == SKIP ]] || fail "SKIP fuori profilo"

if (( failures == 0 )); then
    printf 'ok 1 - rileva journalmatch su unit alias (sshd.service)\n'
    printf 'ok 2 - riporta contatori della jail funzionante\n'
    printf 'ok 3 - segnala jail assente e rispetta il profilo\n'
    printf '3 test superati\n'
    exit 0
fi
exit 1
