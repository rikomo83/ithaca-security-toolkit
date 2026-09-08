#!/usr/bin/env bash
set -u

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ITHACA_BASE_DIR="$(cd "$TEST_DIR/../.." && pwd -P)"
DISPATCHER="$ITHACA_BASE_DIR/bin/ithaca-check"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

mkdir -p "$TEST_ROOT/bin"

printf '%s\n' \
    '#!/usr/bin/env bash' \
    'printf "legacy:%s\\n" "$*"' \
    > "$TEST_ROOT/bin/ithaca-check-legacy"

printf '%s\n' \
    '#!/usr/bin/env bash' \
    'printf "v12:%s\\n" "$*"' \
    > "$TEST_ROOT/bin/ithaca-check-v12"

chmod 0755 \
    "$TEST_ROOT/bin/ithaca-check-legacy" \
    "$TEST_ROOT/bin/ithaca-check-v12"

failures=0

output="$(env -u ITHACA_ENGINE ITHACA_BASE_DIR="$TEST_ROOT" "$DISPATCHER" alpha beta)"
[[ "$output" == "v12:alpha beta" ]] || failures=$((failures + 1))

output="$(ITHACA_ENGINE=legacy ITHACA_BASE_DIR="$TEST_ROOT" "$DISPATCHER" rollback)"
[[ "$output" == "legacy:rollback" ]] || failures=$((failures + 1))

output="$(ITHACA_ENGINE=v12 ITHACA_BASE_DIR="$TEST_ROOT" "$DISPATCHER" explicit)"
[[ "$output" == "v12:explicit" ]] || failures=$((failures + 1))

set +e
output="$(ITHACA_ENGINE=invalid ITHACA_BASE_DIR="$TEST_ROOT" "$DISPATCHER" 2>&1)"
invalid_rc=$?
set -e
[[ "$invalid_rc" == 3 ]] || failures=$((failures + 1))
[[ "$output" == "ITHACA_ENGINE non valido: invalid (valori: legacy, v12)" ]] ||
    failures=$((failures + 1))

if (( failures == 0 )); then
    printf 'ok 1 - usa v1.2 come motore predefinito\n'
    printf 'ok 2 - mantiene il rollback esplicito a Sentinel\n'
    printf 'ok 3 - inoltra gli argomenti e rifiuta motori non validi\n'
    printf '3 test superati\n'
    exit 0
fi

printf 'not ok 1 - selettore motore non conforme (%s errori)\n' "$failures" >&2
exit 1
