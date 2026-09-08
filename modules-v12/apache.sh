#!/usr/bin/env bash

check_apache_config() {
    local config_output=""

    if config_output="$(apache2ctl configtest 2>&1)"; then
        result_ok "apache.config" "Apache config Syntax OK"
    else
        result_critical "apache.config" "Apache config ERROR" "$config_output"
    fi
}

check_apache_service() {
    if systemctl is-active --quiet apache2; then
        result_ok "apache.service" "Apache attivo"
    else
        result_critical "apache.service" "Apache non attivo"
    fi
}

register_check \
    "apache.config" \
    "check_apache_config" \
    "web" \
    "Verifica la validita della configurazione Apache" \
    "yes" \
    "15"

register_check \
    "apache.service" \
    "check_apache_service" \
    "web" \
    "Verifica che Apache sia attivo" \
    "yes" \
    "10"
