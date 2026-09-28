#!/usr/bin/env bash
set -u

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ITHACA_BASE_DIR="$(cd "$TEST_DIR/../.." && pwd -P)"
export ITHACA_BASE_DIR

source "$ITHACA_BASE_DIR/bin/ithaca-setup"

package_installed() { return 1; }
service_active() { return 1; }
geoserver_active() { return 1; }
azurearc_active() { return 1; }

ITHACA_CONFIG_VALUES[WEB_SERVER]="apache"
ITHACA_CONFIG_VALUES[DATABASE]="postgresql"
ITHACA_CONFIG_VALUES[GEOSERVER]="yes"
ITHACA_CONFIG_VALUES[AZURE_ARC]="yes"
ITHACA_CONFIG_VALUES[FAIL2BAN]="yes"
ITHACA_CONFIG_VALUES[UFW]="yes"

# Evita il caricamento da disco: il test verifica esclusivamente la costruzione del piano.
config_load() { :; }
PLAN_OUTPUT="$(mktemp)"
trap 'rm -f "$PLAN_OUTPUT"' EXIT
setup_build_plan > "$PLAN_OUTPUT"
output="$(cat "$PLAN_OUTPUT")"

failures=0
[[ " ${SETUP_PACKAGES[*]} " == *" apache2 "* ]] || failures=$((failures + 1))
[[ " ${SETUP_PACKAGES[*]} " == *" postgresql "* ]] || failures=$((failures + 1))
[[ " ${SETUP_PACKAGES[*]} " == *" fail2ban "* ]] || failures=$((failures + 1))
[[ " ${SETUP_PACKAGES[*]} " == *" ufw "* ]] || failures=$((failures + 1))
[[ "$output" == *"GeoServer: installazione manuale"* ]] || failures=$((failures + 1))
[[ "$output" == *"Azure Arc: onboarding manuale"* ]] || failures=$((failures + 1))
[[ "$output" == *"UFW: verificare accesso SSH"* ]] || failures=$((failures + 1))

package_installed() { return 0; }
service_active() { return 0; }
geoserver_active() { return 0; }
azurearc_active() { return 0; }
setup_build_plan > "$PLAN_OUTPUT"
production_output="$(cat "$PLAN_OUTPUT")"
[[ "$production_output" == *"GeoServer      processo Java e porta 8080 rilevati"* ]] || failures=$((failures + 1))
[[ "$production_output" == *"Azure Arc      almeno un servizio Arc attivo"* ]] || failures=$((failures + 1))
[[ "$production_output" != *"Interventi manuali:"* ]] || failures=$((failures + 1))

if (( failures == 0 )); then
    printf 'ok 1 - SETUP pianifica i pacchetti previsti dal profilo\n'
    printf 'ok 2 - SETUP lascia manuali i passaggi ad alto rischio\n'
    printf 'ok 3 - SETUP riconosce i componenti di produzione gia attivi\n'
    printf '3 test superati\n'
    exit 0
fi

printf 'not ok 1 - piano SETUP non conforme (%s errori)\n' "$failures" >&2
exit 1
