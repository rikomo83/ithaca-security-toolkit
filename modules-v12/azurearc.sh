#!/usr/bin/env bash

check_azurearc_status() {
    if systemctl is-active --quiet himdsd ||
       systemctl is-active --quiet gcad ||
       systemctl is-active --quiet arcproxyd; then
        result_ok "azurearc.status" "Azure Arc servizi attivi"
    else
        result_warn "azurearc.status" "Azure Arc non rilevato"
    fi

    if systemctl is-failed --quiet MsftLinuxPatchAutoAssess.service; then
        result_warn "azurearc.status" "Azure Patch Assessment extension in errore"
    fi
}

register_check \
    "azurearc.status" \
    "check_azurearc_status" \
    "management" \
    "Verifica i servizi Azure Arc e lo stato di Patch Assessment" \
    "yes" \
    "15"
