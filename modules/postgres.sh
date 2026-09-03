#!/usr/bin/env bash

check_postgres() {
  section "POSTGRESQL"

  if systemctl is-active --quiet postgresql; then
    ok "PostgreSQL attivo"
  else
    warn "PostgreSQL non attivo"
  fi

  if ss -tulpn | grep -q "127.0.0.1:5432"; then
    ok "PostgreSQL ascolta solo localmente"
  elif ss -tulpn | grep -q ":5432"; then
    crit "PostgreSQL esposto su rete"
  else
    warn "PostgreSQL porta 5432 non rilevata"
  fi
}
