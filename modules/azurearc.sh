#!/usr/bin/env bash

check_azurearc() {
  section "AZURE ARC"

  if systemctl is-active --quiet himdsd || systemctl is-active --quiet gcad || systemctl is-active --quiet arcproxyd; then
    ok "Azure Arc servizi attivi"
  else
    warn "Azure Arc non rilevato"
  fi

  if systemctl is-failed --quiet MsftLinuxPatchAutoAssess.service; then
    warn "Azure Patch Assessment extension in errore"
  fi
}
