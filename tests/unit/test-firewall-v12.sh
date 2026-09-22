#!/usr/bin/env bash
set -u

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ITHACA_BASE_DIR="$(cd "$TEST_DIR/../.." && pwd -P)"
export ITHACA_BASE_DIR

source "$ITHACA_BASE_DIR/core/bootstrap.sh"
source "$ITHACA_BASE_DIR/core/runner.sh"

MOCK_FIREWALL_MODE=ufw

command() {
    if [[ "${1:-}" == "-v" ]]; then
        case "$MOCK_FIREWALL_MODE:${2:-}" in
            ufw:ufw|nft:nft|iptables:iptables|failed:nft)
                return 0
                ;;
            *:ufw|*:nft|*:iptables)
                return 1
                ;;
        esac
    fi
    builtin command "$@"
}

ufw() {
    printf 'Status: active\n'
}

nft() {
    if [[ "$MOCK_FIREWALL_MODE" == "failed" ]]; then
        printf 'permission denied\n' >&2
        return 1
    fi
    printf '%s\n' \
        'table inet filter {' \
        '  chain input {' \
        '    type filter hook input priority filter; policy drop;' \
        '  }' \
        '}'
}

iptables() {
    printf '%s\n' '-P INPUT DROP' '-P FORWARD DROP' '-P OUTPUT ACCEPT'
}

ithaca_core_init
source "$ITHACA_BASE_DIR/modules-v12/firewall.sh"
_ithaca_registry_lock
_ithaca_run_registered_check_id "firewall.status"
MOCK_FIREWALL_MODE=nft
_ithaca_run_registered_check_id "firewall.status"
MOCK_FIREWALL_MODE=iptables
_ithaca_run_registered_check_id "firewall.status"
MOCK_FIREWALL_MODE=missing
_ithaca_run_registered_check_id "firewall.status"
MOCK_FIREWALL_MODE=failed
_ithaca_run_registered_check_id "firewall.status"

if [[ "${#ITHACA_CHECK_IDS[@]}" == 1 &&
      "${ITHACA_RESULT_STATUSES[0]}" == OK &&
      "${ITHACA_RESULT_MESSAGES[0]}" == "UFW attivo" &&
      "${ITHACA_RESULT_STATUSES[1]}" == OK &&
      "${ITHACA_RESULT_MESSAGES[1]}" == \
          "nftables attivo con policy input restrittiva" &&
      "${ITHACA_RESULT_STATUSES[2]}" == OK &&
      "${ITHACA_RESULT_MESSAGES[2]}" == \
          "iptables attivo con policy INPUT restrittiva" &&
      "${ITHACA_RESULT_STATUSES[3]}" == CRITICAL &&
      "${ITHACA_RESULT_MESSAGES[3]}" == \
          "Nessun firewall attivo con policy input restrittiva" &&
      "${ITHACA_RESULT_STATUSES[4]}" == CRITICAL &&
      "${ITHACA_RESULT_DETAILS[4]}" == "nft: permission denied" ]]; then
    printf 'ok 1 - registra ed esegue il check firewall v1.2\n'
    printf 'ok 2 - riconosce UFW, nftables e iptables attivi\n'
    printf 'ok 3 - segnala configurazioni assenti senza output inatteso\n'
    printf 'ok 4 - conserva solo gli errori delle sonde fallite\n'
    printf '4 test superati\n'
    exit 0
fi

printf 'not ok 1 - modulo firewall v1.2 non conforme\n' >&2
exit 1
