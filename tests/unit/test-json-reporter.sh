#!/usr/bin/env bash
set -u

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ITHACA_BASE_DIR="$(cd "$TEST_DIR/../.." && pwd -P)"
export ITHACA_BASE_DIR

source "$ITHACA_BASE_DIR/core/bootstrap.sh"
source "$ITHACA_BASE_DIR/core/json-reporter.sh"

TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT
REPORT="$TEST_ROOT/check.json"

check_report_fixture() {
    result_warn "fixture.escape" $'Riga "uno"\nseconda' $'dettaglio\tX'
}

failures=0
ithaca_core_init
register_check \
    "fixture.escape" \
    "check_report_fixture" \
    "security" \
    "Fixture reporter JSON" \
    "yes" \
    "5"

result_warn "fixture.escape" $'Riga "uno"\nseconda' $'dettaglio\tX'
ITHACA_RESULT_TIMESTAMPS[0]="2026-09-10T12:00:00+0200"
ITHACA_RESULT_DURATIONS_MS[0]="17"
ITHACA_TOOLKIT_VERSION="1.2.0-rc.1"
ITHACA_RUN_ID="run-test"
ITHACA_REPORT_HOST="host-test"
ITHACA_REPORT_TIMESTAMP="2026-09-10T12:00:01+0200"
WARN=1
CRIT=0
SCORE=97

write_json_report "$REPORT" || failures=$((failures + 1))
grep -Fq '"schema_version": 1' "$REPORT" || failures=$((failures + 1))
grep -Fq '"run_id": "run-test"' "$REPORT" || failures=$((failures + 1))
grep -Fq '"summary": {"warnings": 1, "critical": 0, "score": 97}' "$REPORT" ||
    failures=$((failures + 1))
grep -Fq '"check_id":"fixture.escape"' "$REPORT" || failures=$((failures + 1))
grep -Fq '"category":"security"' "$REPORT" || failures=$((failures + 1))
grep -Fq '"message":"Riga \"uno\"\nseconda"' "$REPORT" || failures=$((failures + 1))
grep -Fq '"details":"dettaglio\tX"' "$REPORT" || failures=$((failures + 1))
grep -Fq '"duration_ms":17' "$REPORT" || failures=$((failures + 1))
[[ "$(stat -c '%a' "$REPORT")" == 640 ]] || failures=$((failures + 1))

if command -v python3 >/dev/null 2>&1; then
    python3 -m json.tool "$REPORT" >/dev/null || failures=$((failures + 1))
fi

if (( failures == 0 )); then
    printf 'ok 1 - genera un report JSON schema 1 valido\n'
    printf 'ok 2 - preserva escaping, metadati, durata e permessi\n'
    printf '2 test superati\n'
    exit 0
fi

printf 'not ok 1 - reporter JSON non conforme (%s errori)\n' "$failures" >&2
exit 1
