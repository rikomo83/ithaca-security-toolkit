#!/usr/bin/env bash
set -u

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ITHACA_BASE_DIR="$(cd "$TEST_DIR/../.." && pwd -P)"

source "$ITHACA_BASE_DIR/core/shadow.sh"

legacy_statuses=(OK WARN)
legacy_messages=("Servizi OK" "Disco alto")
v12_statuses=(OK WARN)
v12_messages=("Servizi OK" "Disco alto")

_ithaca_shadow_compare legacy_statuses legacy_messages v12_statuses v12_messages
equal_rc=$?

v12_statuses=(OK CRITICAL)
_ithaca_shadow_compare legacy_statuses legacy_messages v12_statuses v12_messages
different_rc=$?

if [[ "$equal_rc" == 0 && "$different_rc" == 1 &&
      "$ITHACA_SHADOW_ERROR" == Stato* ]]; then
    printf 'ok 1 - confronta risultati shadow equivalenti e diversi\n'
    printf '1 test superato\n'
    exit 0
fi

printf 'not ok 1 - confronto shadow non valido\n' >&2
exit 1
