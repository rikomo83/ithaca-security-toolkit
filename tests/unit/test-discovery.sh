#!/usr/bin/env bash
set -u

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ITHACA_BASE_DIR="$(cd "$TEST_DIR/../.." && pwd -P)"
export ITHACA_BASE_DIR

source "$ITHACA_BASE_DIR/core/bootstrap.sh"
source "$ITHACA_BASE_DIR/core/runner.sh"
source "$ITHACA_BASE_DIR/core/discovery.sh"

TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT
ITHACA_PLUGIN_DIR="$TEST_ROOT/plugins.d"
ITHACA_TRUSTED_UID="$(id -u)"
mkdir -p "$ITHACA_PLUGIN_DIR/demo/checks"
chmod 0700 "$ITHACA_PLUGIN_DIR"
chmod 0755 "$ITHACA_PLUGIN_DIR/demo" "$ITHACA_PLUGIN_DIR/demo/checks"

printf '%s\n' \
    'PLUGIN_ID="demo"' \
    'PLUGIN_NAME="Demo checks"' \
    'PLUGIN_VERSION="1.0.0"' \
    'PLUGIN_API="1"' \
    'PLUGIN_VENDOR="ITHACA"' \
    'PLUGIN_DESCRIPTION="Plugin di test"' \
    'PLUGIN_ENABLED="yes"' \
    > "$ITHACA_PLUGIN_DIR/demo/plugin.conf"

printf '%s\n' \
    'check_demo_ping() {' \
    '    result_ok "demo.ping" "Plugin demo operativo"' \
    '}' \
    'register_check "demo.ping" "check_demo_ping" "application" "Check demo" "yes" "5"' \
    > "$ITHACA_PLUGIN_DIR/demo/checks/ping.sh"

chmod 0644 \
    "$ITHACA_PLUGIN_DIR/demo/plugin.conf" \
    "$ITHACA_PLUGIN_DIR/demo/checks/ping.sh"

failures=0
ithaca_core_init
discover_plugins
discover_rc=$?
_ithaca_registry_lock
_ithaca_run_registered_check_id "demo.ping"

[[ "$discover_rc" == 0 ]] || failures=$((failures + 1))
[[ "${#ITHACA_PLUGIN_IDS[@]}" == 1 && "${ITHACA_PLUGIN_IDS[0]}" == demo ]] ||
    failures=$((failures + 1))
[[ "${#ITHACA_DISCOVERY_ERRORS[@]}" == 0 ]] || failures=$((failures + 1))
[[ "${ITHACA_RESULT_STATUSES[0]}" == OK &&
   "${ITHACA_RESULT_MESSAGES[0]}" == "Plugin demo operativo" ]] || failures=$((failures + 1))

ithaca_core_init
printf '%s\n' \
    'check_wrong_ping() {' \
    '    result_ok "wrong.ping" "Namespace errato"' \
    '}' \
    'register_check "wrong.ping" "check_wrong_ping" "application" "Check errato" "yes" "5"' \
    > "$ITHACA_PLUGIN_DIR/demo/checks/ping.sh"
chmod 0644 "$ITHACA_PLUGIN_DIR/demo/checks/ping.sh"
discover_plugins
[[ "${#ITHACA_PLUGIN_IDS[@]}" == 0 ]] || failures=$((failures + 1))
[[ "${#ITHACA_DISCOVERY_ERRORS[@]}" == 1 ]] || failures=$((failures + 1))
[[ "${#ITHACA_CHECK_IDS[@]}" == 0 ]] || failures=$((failures + 1))

ithaca_core_init
chmod 0666 "$ITHACA_PLUGIN_DIR/demo/checks/ping.sh"
discover_plugins
[[ "${#ITHACA_PLUGIN_IDS[@]}" == 0 ]] || failures=$((failures + 1))
[[ "${#ITHACA_DISCOVERY_ERRORS[@]}" == 1 ]] || failures=$((failures + 1))
[[ "${#ITHACA_CHECK_IDS[@]}" == 0 ]] || failures=$((failures + 1))

if (( failures == 0 )); then
    printf 'ok 1 - carica un plugin valido in modo deterministico\n'
    printf 'ok 2 - rifiuta check fuori dal namespace del plugin\n'
    printf 'ok 3 - rifiuta file scrivibili da group o others\n'
    printf '3 test superati\n'
    exit 0
fi

printf 'not ok 1 - discovery plugin non conforme (%s errori)\n' "$failures" >&2
exit 1
