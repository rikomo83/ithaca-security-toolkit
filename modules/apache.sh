#!/usr/bin/env bash

check_apache() {
  section "APACHE"

  TMP_APACHE_LOG="$(mktemp)"

  if apache2ctl configtest >"$TMP_APACHE_LOG" 2>&1; then
    ok "Apache config Syntax OK"
  else
    crit "Apache config ERROR"
    cat "$TMP_APACHE_LOG"
  fi

  rm -f "$TMP_APACHE_LOG"

  if systemctl is-active --quiet apache2; then
    ok "Apache attivo"
  else
    crit "Apache non attivo"
  fi
}
