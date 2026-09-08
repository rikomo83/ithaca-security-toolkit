#!/usr/bin/env bash

check_fail2ban_status() {
    local jails=""

    if systemctl is-active --quiet fail2ban; then
        jails="$(fail2ban-client status 2>/dev/null | awk -F: '/Number of jail/ {gsub(/ /,"",$2); print $2}')"
        result_ok "fail2ban.status" "Fail2Ban attivo (${jails:-?} jail)"
    else
        result_critical "fail2ban.status" "Fail2Ban non attivo"
    fi
}

register_check \
    "fail2ban.status" \
    "check_fail2ban_status" \
    "security" \
    "Verifica che Fail2Ban sia attivo e rileva il numero di jail" \
    "yes" \
    "10"
