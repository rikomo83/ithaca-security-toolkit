#!/usr/bin/env bash

check_tls_protocols() {
    local tls_ip="${TLS_IP:-127.0.0.1}"
    local hosts=""
    local host=""
    local tls1_output=""

    hosts="$(apache2ctl -S 2>/dev/null |
        awk '/port 443 namevhost/ {print $4}' |
        sort -u)"

    if [[ -z "$hosts" ]]; then
        result_warn "tls.protocols" "Nessun VirtualHost HTTPS rilevato"
        return
    fi

    for host in $hosts; do
        if echo | openssl s_client -connect "$tls_ip:443" -servername "$host" -tls1_2 >/dev/null 2>&1; then
            result_ok "tls.protocols" "$host TLS 1.2 attivo"
        else
            result_warn "tls.protocols" "$host TLS 1.2 non verificato"
        fi

        if echo | openssl s_client -connect "$tls_ip:443" -servername "$host" -tls1_3 >/dev/null 2>&1; then
            result_ok "tls.protocols" "$host TLS 1.3 attivo"
        else
            result_warn "tls.protocols" "$host TLS 1.3 non verificato"
        fi

        tls1_output="$(echo | openssl s_client -connect "$tls_ip:443" -servername "$host" -tls1 2>&1 || true)"
        if grep -q "Cipher is (NONE)" <<< "$tls1_output"; then
            result_ok "tls.protocols" "$host TLS 1.0 bloccato"
        else
            result_warn "tls.protocols" "$host TLS 1.0 potrebbe essere attivo"
        fi
    done
}

register_check \
    "tls.protocols" \
    "check_tls_protocols" \
    "network" \
    "Verifica i protocolli TLS dei VirtualHost HTTPS" \
    "yes" \
    "60"
