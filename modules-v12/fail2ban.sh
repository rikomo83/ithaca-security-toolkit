#!/usr/bin/env bash

check_fail2ban_status() {
    local jails=""

    if ! config_is_enabled FAIL2BAN no; then
        result_skip "fail2ban.status" "Fail2Ban non previsto dal profilo"
        return
    fi


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

# ---------------------------------------------------------------------------
# v1.3: verifica che la jail sshd esista e legga davvero i log.
# Su Ubuntu l'unit reale e ssh.service (sshd.service e solo un alias): una jail
# con backend systemd e journalmatch _SYSTEMD_UNIT=sshd.service non vede nulla.
# ---------------------------------------------------------------------------

check_fail2ban_sshd_jail() {
    local status=""
    local match=""
    local unit=""
    local real_unit=""
    local failed=""
    local banned=""

    if ! config_is_enabled FAIL2BAN no; then
        result_skip "fail2ban.sshd_jail" "Fail2Ban non previsto dal profilo"
        return
    fi

    if ! status="$(fail2ban-client status sshd 2>&1)"; then
        result_critical "fail2ban.sshd_jail" "Jail sshd non attiva" "$status"
        return
    fi

    failed="$(awk -F: '/Total failed/ {gsub(/[[:space:]]/, "", $2); print $2}' <<< "$status")"
    banned="$(awk -F: '/Total banned/ {gsub(/[[:space:]]/, "", $2); print $2}' <<< "$status")"
    match="$(awk -F: '/Journal matches/ {sub(/^[^:]*:[[:space:]]*/, ""); print}' <<< "$status")"

    if [[ -n "$match" ]]; then
        unit="$(grep -o '_SYSTEMD_UNIT=[^ +]*' <<< "$match" | head -n 1)"
        unit="${unit#_SYSTEMD_UNIT=}"
        if [[ -n "$unit" ]]; then
            real_unit="$(systemctl show -p Id --value "$unit" 2>/dev/null || true)"
            if [[ -n "$real_unit" && "$real_unit" != "$unit" ]]; then
                result_critical "fail2ban.sshd_jail" \
                    "Jail sshd cieca: journalmatch su $unit, unit reale $real_unit" \
                    "Impostare journalmatch = _SYSTEMD_UNIT=$real_unit + _COMM=sshd"
                return
            fi
        fi
    fi

    result_ok "fail2ban.sshd_jail" \
        "Jail sshd attiva (falliti totali ${failed:-?}, ban totali ${banned:-?})"
}

register_check \
    "fail2ban.sshd_jail" \
    "check_fail2ban_sshd_jail" \
    "security" \
    "Verifica che la jail sshd sia attiva e legga la sorgente di log corretta" \
    "yes" \
    "10"
