#!/usr/bin/env bash
set -u

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ITHACA_BASE_DIR="$(cd "$TEST_DIR/../.." && pwd -P)"
export ITHACA_BASE_DIR

source "$ITHACA_BASE_DIR/core/bootstrap.sh"
source "$ITHACA_BASE_DIR/core/legacy-renderer.sh"

RENDERED=()
ok()   { RENDERED+=("OK:$1"); }
warn() { RENDERED+=("WARN:$1"); }
crit() { RENDERED+=("CRITICAL:$1"); }
info() { RENDERED+=("INFO:$1"); }

ithaca_core_init
result_ok "render.ok" "Conforme"
result_warn "render.warn" "Da verificare"
result_critical "render.critical" "Non conforme"
result_skip "render.skip" "Non applicabile"
result_error "render.error" "Esecuzione fallita"

tmp_output="$(mktemp)"
_ithaca_render_results_legacy 0 > "$tmp_output"
render_rc=$?
output="$(<"$tmp_output")"
rm -f "$tmp_output"

failures=0
[[ "$render_rc" == 0 ]] || failures=$((failures + 1))
[[ "${RENDERED[0]}" == "OK:Conforme" ]] || failures=$((failures + 1))
[[ "${RENDERED[1]}" == "WARN:Da verificare" ]] || failures=$((failures + 1))
[[ "${RENDERED[2]}" == "CRITICAL:Non conforme" ]] || failures=$((failures + 1))
[[ "${RENDERED[3]}" == "INFO:SKIP: Non applicabile" ]] || failures=$((failures + 1))
[[ "${RENDERED[4]}" == "CRITICAL:Errore check: Esecuzione fallita" ]] || failures=$((failures + 1))
[[ -z "$output" ]] || failures=$((failures + 1))

if (( failures == 0 )); then
    printf 'ok 1 - rende gli stati Core nel formato Sentinel\n'
    printf '1 test superato\n'
    exit 0
fi

printf 'not ok 1 - renderer legacy non conforme (%s errori)\n' "$failures" >&2
exit 1
