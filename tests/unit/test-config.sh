#!/usr/bin/env bash
set -u

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ITHACA_BASE_DIR="$(cd "$TEST_DIR/../.." && pwd -P)"
TEST_CONFIG="$(mktemp)"
trap 'rm -f "$TEST_CONFIG"' EXIT

source "$ITHACA_BASE_DIR/core/config.sh"

cat > "$TEST_CONFIG" <<'EOF'
# profilo test
WEB_SERVER="apache"
FAIL2BAN=yes
EMPTY=""
UNSAFE="$(touch /tmp/ithaca-config-must-not-run)"
EOF

rm -f /tmp/ithaca-config-must-not-run
config_load "$TEST_CONFIG" 2>/dev/null

failures=0
[[ "$(config_get WEB_SERVER)" == apache ]] || failures=$((failures + 1))
config_is_enabled FAIL2BAN no || failures=$((failures + 1))
config_equals WEB_SERVER apache || failures=$((failures + 1))
[[ "$(config_get MISSING fallback)" == fallback ]] || failures=$((failures + 1))
[[ ! -e /tmp/ithaca-config-must-not-run ]] || failures=$((failures + 1))
[[ -z "$(config_get UNSAFE)" ]] || failures=$((failures + 1))

if (( failures == 0 )); then
    printf 'ok 1 - carica la configurazione senza eseguirla\n'
    printf 'ok 2 - espone valori, flag e default\n'
    printf '2 test superati\n'
    exit 0
fi

printf 'not ok 1 - API configurazione non conforme (%s errori)\n' "$failures" >&2
exit 1
