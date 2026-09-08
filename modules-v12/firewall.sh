#!/usr/bin/env bash

check_firewall_status() {
    if ufw status | grep -q "Status: active"; then
        result_ok "firewall.status" "UFW attivo"
    else
        result_critical "firewall.status" "UFW non attivo"
    fi
}

register_check \
    "firewall.status" \
    "check_firewall_status" \
    "security" \
    "Verifica che UFW sia attivo" \
    "yes" \
    "10"
