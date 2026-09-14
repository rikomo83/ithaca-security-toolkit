#!/usr/bin/env bash
set -u

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ITHACA_BASE_DIR="$(cd "$TEST_DIR/../.." && pwd -P)"
WORKFLOW="$ITHACA_BASE_DIR/.github/workflows/odyssey-guard.yml"

failures=0

[[ -f "$WORKFLOW" ]] || failures=$((failures + 1))
grep -Fq 'permissions:' "$WORKFLOW" || failures=$((failures + 1))
grep -Fq 'contents: read' "$WORKFLOW" || failures=$((failures + 1))
grep -Fq 'actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1' "$WORKFLOW" ||
    failures=$((failures + 1))
grep -Fq 'persist-credentials: false' "$WORKFLOW" || failures=$((failures + 1))
grep -Fq 'ubuntu-22.04' "$WORKFLOW" || failures=$((failures + 1))
grep -Fq 'ubuntu-24.04' "$WORKFLOW" || failures=$((failures + 1))
grep -Fq 'bash tests/run.sh' "$WORKFLOW" || failures=$((failures + 1))

if (( failures == 0 )); then
    printf 'ok 1 - Odyssey Guard applica CI minima e permessi sicuri\n'
    printf '1 test superato\n'
    exit 0
fi

printf 'not ok 1 - configurazione Odyssey Guard non valida (%s errori)\n' \
    "$failures" >&2
exit 1
