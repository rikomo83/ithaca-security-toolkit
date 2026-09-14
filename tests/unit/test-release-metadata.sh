#!/usr/bin/env bash
set -u

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ITHACA_BASE_DIR="$(cd "$TEST_DIR/../.." && pwd -P)"

source "$ITHACA_BASE_DIR/VERSION"

failures=0
[[ "${VERSION:-}" == "1.2.0-rc.1" ]] || failures=$((failures + 1))
[[ "${CODENAME:-}" == "Odyssey" ]] || failures=$((failures + 1))
[[ "${BUILD:-}" == "2026.09.14" ]] || failures=$((failures + 1))
[[ "${CORE_API:-}" == "1" ]] || failures=$((failures + 1))
[[ "${REPORT_SCHEMA:-}" == "1" ]] || failures=$((failures + 1))
grep -Fq '1.2.0-rc.1 “Odyssey”' "$ITHACA_BASE_DIR/docs/README.md" ||
    failures=$((failures + 1))
grep -Fq 'ITHACA_ENGINE=legacy' "$ITHACA_BASE_DIR/docs/ROLLBACK-v1.2.md" ||
    failures=$((failures + 1))

if (( failures == 0 )); then
    printf 'ok 1 - metadati release candidate Odyssey coerenti\n'
    printf 'ok 2 - rollback Sentinel documentato\n'
    printf '2 test superati\n'
    exit 0
fi

printf 'not ok 1 - metadati release non coerenti (%s errori)\n' "$failures" >&2
exit 1
