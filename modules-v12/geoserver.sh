#!/usr/bin/env bash

check_geoserver_port() {
    if ! config_is_enabled GEOSERVER no; then
        result_skip "geoserver.port" "GeoServer non previsto dal profilo"
        return
    fi

    if ss -tulpn | grep -q ":8080"; then
        result_ok "geoserver.port" "GeoServer/Java porta 8080 attiva"
    else
        result_warn "geoserver.port" "Porta 8080 non rilevata"
    fi
}

check_geoserver_java() {
    if ! config_is_enabled GEOSERVER no; then
        result_skip "geoserver.java" "GeoServer non previsto dal profilo"
        return
    fi

    if pgrep -f java >/dev/null 2>&1; then
        result_ok "geoserver.java" "Processo Java rilevato"
    else
        result_warn "geoserver.java" "Processo Java non rilevato"
    fi
}

register_check \
    "geoserver.port" \
    "check_geoserver_port" \
    "application" \
    "Verifica che la porta GeoServer sia attiva" \
    "yes" \
    "10"

register_check \
    "geoserver.java" \
    "check_geoserver_java" \
    "application" \
    "Verifica che il processo Java sia presente" \
    "yes" \
    "10"
