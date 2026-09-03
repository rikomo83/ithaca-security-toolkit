#!/usr/bin/env bash

check_certs() {
  section "CERTIFICATI"

  CERT_WARN=$(certbot certificates 2>/dev/null | awk '/Expiry Date:/ {for(i=1;i<=NF;i++) if($i=="VALID:") {gsub("[()]","",$(i+1)); if($(i+1)+0 < 30) print $0}}')

  if [ -z "$CERT_WARN" ]; then
    ok "Certificati validi oltre 30 giorni"
  else
    warn "Certificati in scadenza entro 30 giorni"
    echo "$CERT_WARN"
  fi
}
