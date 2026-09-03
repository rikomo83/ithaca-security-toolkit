#!/usr/bin/env bash

check_fail2ban() {
  section "FAIL2BAN"

  if systemctl is-active --quiet fail2ban; then
    JAILS=$(fail2ban-client status 2>/dev/null | awk -F: '/Number of jail/ {gsub(/ /,"",$2); print $2}')
    ok "Fail2Ban attivo (${JAILS:-?} jail)"
  else
    crit "Fail2Ban non attivo"
  fi
}
