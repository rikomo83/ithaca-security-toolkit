#!/usr/bin/env bash
set -u

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ITHACA_BASE_DIR="$(cd "$TEST_DIR/../.." && pwd -P)"
export ITHACA_BASE_DIR
OPENSSL_LOG="$(mktemp)"
trap 'rm -f "$OPENSSL_LOG"' EXIT

source "$ITHACA_BASE_DIR/core/bootstrap.sh"
source "$ITHACA_BASE_DIR/core/runner.sh"

apache2ctl() {
    printf 'port 443 namevhost example.ithaca.test\n'
}

openssl() {
    local argument=""

    printf '%s\n' "$*" >> "$OPENSSL_LOG"

    for argument in "$@"; do
        case "$argument" in
            -tls1_2|-tls1_3) return 0 ;;
            -tls1)
                printf 'Cipher is (NONE)\n'
                return 1
                ;;
        esac
    done
    return 1
}

ithaca_core_init
source "$ITHACA_BASE_DIR/modules-v12/tls.sh"
_ithaca_registry_lock
_ithaca_run_registered_check_id "tls.protocols"

if [[ "${#ITHACA_CHECK_IDS[@]}" == 1 &&
      "${#ITHACA_RESULT_STATUSES[@]}" == 3 &&
      "${ITHACA_RESULT_STATUSES[0]}" == OK &&
      "${ITHACA_RESULT_MESSAGES[0]}" == "example.ithaca.test TLS 1.2 attivo" &&
      "${ITHACA_RESULT_STATUSES[1]}" == OK &&
      "${ITHACA_RESULT_MESSAGES[1]}" == "example.ithaca.test TLS 1.3 attivo" &&
      "${ITHACA_RESULT_STATUSES[2]}" == OK &&
      "${ITHACA_RESULT_MESSAGES[2]}" == "example.ithaca.test TLS 1.0 bloccato" &&
      $(grep -c -- '-connect example.ithaca.test:443' "$OPENSSL_LOG") -eq 3 ]]; then
    printf 'ok 1 - registra ed esegue il check tls v1.2\n'
    printf '1 test superato\n'
    exit 0
fi

printf 'not ok 1 - modulo tls v1.2 non conforme\n' >&2
exit 1
