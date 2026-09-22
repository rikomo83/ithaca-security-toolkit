#!/usr/bin/env bash
set -u

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ITHACA_BASE_DIR="$(cd "$TEST_DIR/../.." && pwd -P)"

source "$ITHACA_BASE_DIR/core/report-file.sh"

TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT
REPORT="$TEST_ROOT/check.txt"
LINK="$TEST_ROOT/check-link.txt"
failures=0

umask 0002
_ithaca_prepare_text_report "$REPORT" || failures=$((failures + 1))
[[ -f "$REPORT" ]] || failures=$((failures + 1))
[[ "$(stat -c '%a' "$REPORT")" == 640 ]] || failures=$((failures + 1))

printf 'contenuto precedente\n' > "$REPORT"
chmod 0666 "$REPORT"
_ithaca_prepare_text_report "$REPORT" || failures=$((failures + 1))
[[ ! -s "$REPORT" ]] || failures=$((failures + 1))
[[ "$(stat -c '%a' "$REPORT")" == 640 ]] || failures=$((failures + 1))

ln -s "$REPORT" "$LINK"
if _ithaca_prepare_text_report "$LINK"; then
    failures=$((failures + 1))
fi

if (( failures == 0 )); then
    printf 'ok 1 - crea il report testuale con permessi 0640\n'
    printf 'ok 2 - normalizza i permessi indipendentemente dalla umask\n'
    printf 'ok 3 - rifiuta destinazioni simboliche\n'
    printf '3 test superati\n'
    exit 0
fi

printf 'not ok 1 - preparazione report testuale non conforme (%s errori)\n' \
    "$failures" >&2
exit 1
