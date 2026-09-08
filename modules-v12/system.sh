#!/usr/bin/env bash

check_system_services() {
    local failed_services=""
    local failed_count=0
    local details=""

    failed_services="$(systemctl --failed --plain --no-legend --no-pager 2>/dev/null | awk '{print $1}')"
    failed_count="$(printf '%s\n' "$failed_services" | sed '/^$/d' | wc -l)"

    if (( failed_count == 0 )); then
        result_ok "system.services" "Nessun servizio systemd in errore"
    else
        details="$(printf '%s\n' "$failed_services" | sed '/^$/d' | sed 's/^/  - /')"
        result_warn "system.services" "$failed_count servizi systemd in errore:" "$details"
    fi
}

check_system_disk() {
    local disk_warn=""

    disk_warn="$(df -h --output=pcent,target | awk 'NR>1 {gsub("%","",$1); if ($1 >= 85) print $0}')"
    if [[ -z "$disk_warn" ]]; then
        result_ok "system.disk" "Spazio disco OK"
    else
        result_warn "system.disk" "Partizioni oltre 85%:" "$disk_warn"
    fi
}

register_check \
    "system.services" \
    "check_system_services" \
    "system" \
    "Verifica i servizi systemd in errore" \
    "yes" \
    "10"

register_check \
    "system.disk" \
    "check_system_disk" \
    "system" \
    "Verifica le partizioni con utilizzo almeno all'85%" \
    "yes" \
    "10"
