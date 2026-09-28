#!/usr/bin/env bash
set -u

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ITHACA_BASE_DIR="$(cd "$TEST_DIR/../.." && pwd -P)"
export ITHACA_BASE_DIR

source "$ITHACA_BASE_DIR/core/bootstrap.sh"
source "$ITHACA_BASE_DIR/core/runner.sh"

ITHACA_CONFIG_VALUES[WEB_SERVER]=""
ITHACA_CONFIG_VALUES[DATABASE]=""
ITHACA_CONFIG_VALUES[GEOSERVER]="no"
ITHACA_CONFIG_VALUES[AZURE_ARC]="no"
ITHACA_CONFIG_VALUES[FAIL2BAN]="no"

ithaca_core_init
source "$ITHACA_BASE_DIR/modules-v12/apache.sh"
source "$ITHACA_BASE_DIR/modules-v12/tls.sh"
source "$ITHACA_BASE_DIR/modules-v12/postgres.sh"
source "$ITHACA_BASE_DIR/modules-v12/geoserver.sh"
source "$ITHACA_BASE_DIR/modules-v12/azurearc.sh"
source "$ITHACA_BASE_DIR/modules-v12/fail2ban.sh"
_ithaca_registry_lock

for check_id in \
    apache.config apache.service tls.protocols \
    postgres.service postgres.listener \
    geoserver.port geoserver.java azurearc.status fail2ban.status
do
    _ithaca_run_registered_check_id "$check_id"
done

failures=0
[[ "${#ITHACA_RESULT_STATUSES[@]}" == 9 ]] || failures=$((failures + 1))
for status in "${ITHACA_RESULT_STATUSES[@]}"; do
    [[ "$status" == SKIP ]] || failures=$((failures + 1))
done
[[ "$(_ithaca_legacy_score)" == 100 ]] || failures=$((failures + 1))

if (( failures == 0 )); then
    printf 'ok 1 - il profilo Wazuh ignora i componenti non applicabili\n'
    printf 'ok 2 - gli SKIP non riducono lo score\n'
    printf '2 test superati\n'
    exit 0
fi

printf 'not ok 1 - applicabilita v1.2 non conforme (%s errori)\n' "$failures" >&2
exit 1
