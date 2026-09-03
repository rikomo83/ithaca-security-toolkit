#!/usr/bin/env bash

check_system() {
  section "SYSTEM"

  FAILED_SERVICES=$(systemctl --failed --plain --no-legend --no-pager | awk '{print $1}')
  FAILED_COUNT=$(echo "$FAILED_SERVICES" | sed '/^$/d' | wc -l)

  if [ "$FAILED_COUNT" -eq 0 ]; then
    ok "Nessun servizio systemd in errore"
  else
    warn "$FAILED_COUNT servizi systemd in errore:"
    echo "$FAILED_SERVICES" | sed '/^$/d' | sed 's/^/  - /'
  fi

  DISK_WARN=$(df -h --output=pcent,target | awk 'NR>1 {gsub("%","",$1); if ($1 >= 85) print $0}')
  if [ -z "$DISK_WARN" ]; then
    ok "Spazio disco OK"
  else
    warn "Partizioni oltre 85%:"
    echo "$DISK_WARN"
  fi
}
