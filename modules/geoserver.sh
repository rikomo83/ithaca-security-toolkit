#!/usr/bin/env bash

check_geoserver() {
  section "GEOSERVER"

  if ss -tulpn | grep -q ":8080"; then
    ok "GeoServer/Java porta 8080 attiva"
  else
    warn "Porta 8080 non rilevata"
  fi

  if pgrep -f java >/dev/null 2>&1; then
    ok "Processo Java rilevato"
  else
    warn "Processo Java non rilevato"
  fi
}
