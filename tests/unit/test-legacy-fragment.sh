#!/usr/bin/env bash
set -u

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ITHACA_BASE_DIR="$(cd "$TEST_DIR/../.." && pwd -P)"
export ITHACA_BASE_DIR

source "$ITHACA_BASE_DIR/core/bootstrap.sh"
source "$ITHACA_BASE_DIR/core/legacy-adapter.sh"

ithaca_core_init
legacy_parse_fragment "$ITHACA_BASE_DIR/tests/fixtures/legacy-firewall.txt" firewall
parse_rc=$?

if [[ "$parse_rc" == 0 &&
      "${#ITHACA_RESULT_STATUSES[@]}" == 1 &&
      "${ITHACA_RESULT_STATUSES[0]}" == OK &&
      "${ITHACA_RESULT_MESSAGES[0]}" == "UFW attivo" ]]; then
    printf 'ok 1 - converte un frammento legacy\n'
    printf '1 test superato\n'
    exit 0
fi

printf 'not ok 1 - conversione frammento legacy fallita\n' >&2
exit 1
