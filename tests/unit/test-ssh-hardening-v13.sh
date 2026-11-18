#!/usr/bin/env bash
set -u

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ITHACA_BASE_DIR="$(cd "$TEST_DIR/../.." && pwd -P)"
export ITHACA_BASE_DIR

source "$ITHACA_BASE_DIR/core/bootstrap.sh"
source "$ITHACA_BASE_DIR/core/runner.sh"

MOCK_SSHD=hardened

sshd() {
    if [[ "$MOCK_SSHD" == hardened ]]; then
        printf '%s\n' \
            'passwordauthentication no' 'permitrootlogin no' \
            'kbdinteractiveauthentication no' 'x11forwarding no' \
            'allowagentforwarding no' 'maxauthtries 3' 'logingracetime 30' \
            'clientaliveinterval 300' 'clientalivecountmax 2' 'allowusers haiti'
    else
        # Valori predefiniti di Ubuntu 22.04.
        printf '%s\n' \
            'passwordauthentication yes' 'permitrootlogin without-password' \
            'kbdinteractiveauthentication no' 'x11forwarding yes' \
            'allowagentforwarding yes' 'maxauthtries 6' 'logingracetime 120' \
            'clientaliveinterval 0' 'clientalivecountmax 3'
    fi
}

ithaca_core_init
source "$ITHACA_BASE_DIR/modules-v12/ssh.sh"
_ithaca_registry_lock

failures=0
fail() { printf 'not ok - %s\n' "$1" >&2; failures=$((failures + 1)); }

unset ITHACA_SSHD_EFFECTIVE_CONFIG
_ithaca_run_registered_check_id "ssh.hardening"
_ithaca_run_registered_check_id "ssh.allow_users"
[[ "${ITHACA_RESULT_STATUSES[0]}" == OK ]] || fail "hardening OK: ${ITHACA_RESULT_DETAILS[0]}"
[[ "${ITHACA_RESULT_STATUSES[1]}" == OK &&
   "${ITHACA_RESULT_DETAILS[1]}" == "allowusers haiti" ]] || fail "allow_users OK"

_ithaca_results_reset
unset ITHACA_SSHD_EFFECTIVE_CONFIG
MOCK_SSHD=default
_ithaca_run_registered_check_id "ssh.hardening"
_ithaca_run_registered_check_id "ssh.allow_users"
[[ "${ITHACA_RESULT_STATUSES[0]}" == WARN ]] || fail "hardening WARN"
for item in x11forwarding allowagentforwarding 'maxauthtries=6' 'logingracetime=120' 'clientaliveinterval=0'; do
    [[ "${ITHACA_RESULT_DETAILS[0]}" == *"$item"* ]] || fail "dettaglio mancante: $item"
done
[[ "${ITHACA_RESULT_DETAILS[0]}" != *kbdinteractive* ]] || fail "kbdinteractive gia conforme"
[[ "${ITHACA_RESULT_STATUSES[1]}" == WARN ]] || fail "allow_users WARN"

if (( failures == 0 )); then
    printf 'ok 1 - riconosce la baseline SSH applicata\n'
    printf 'ok 2 - elenca i parametri SSH non conformi\n'
    printf 'ok 3 - segnala l assenza di AllowUsers/AllowGroups\n'
    printf '3 test superati\n'
    exit 0
fi
exit 1
