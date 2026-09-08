#!/usr/bin/env bash

check_certs_expiry() {
    local cert_warn=""

    cert_warn="$(certbot certificates 2>/dev/null |
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
