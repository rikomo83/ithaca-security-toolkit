#!/usr/bin/env bash

check_certs_expiry() {
    local cert_warn=""
    local cert_output=""

    if ! command -v certbot >/dev/null 2>&1; then
        result_skip "certs.expiry" "Certbot non installato"
        return
    fi

    cert_output="$(certbot certificates 2>/dev/null || true)"
    if ! grep -q 'Certificate Name:' <<< "$cert_output"; then
        result_skip "certs.expiry" "Nessun certificato gestito da Certbot"
        return
    fi

    cert_warn="$(printf '%s\n' "$cert_output" |
        awk '/Expiry Date:/ {for(i=1;i<=NF;i++) if($i=="VALID:") {gsub("[()]","",$(i+1)); if($(i+1)+0 < 30) print $0}}')"

    if [[ -z "$cert_warn" ]]; then
        result_ok "certs.expiry" "Certificati validi oltre 30 giorni"
    else
        result_warn \
            "certs.expiry" \
            "Certificati in scadenza entro 30 giorni" \
            "$cert_warn"
    fi
}

register_check \
    "certs.expiry" \
    "check_certs_expiry" \
    "security" \
    "Verifica i certificati con meno di 30 giorni residui" \
    "yes" \
    "30"
