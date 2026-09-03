#!/usr/bin/env bash

check_firewall() {
  section "FIREWALL"

  if ufw status | grep -q "Status: active"; then
    ok "UFW attivo"
  else
    crit "UFW non attivo"
  fi
}
