#!/usr/bin/env bash

_ithaca_load_ssh_effective_config() {
    if [[ -z "${ITHACA_SSHD_EFFECTIVE_CONFIG+x}" ]]; then
        ITHACA_SSHD_EFFECTIVE_CONFIG="$(sshd -T 2>/dev/null || true)"
    fi
}

check_ssh_password_authentication() {
    local sshd_config=""
    _ithaca_load_ssh_effective_config
    sshd_config="$ITHACA_SSHD_EFFECTIVE_CONFIG"

    if printf '%s\n' "$sshd_config" | grep -q '^passwordauthentication no'; then
        result_ok "ssh.password_authentication" "SSH password disabilitata"
    else
        result_critical "ssh.password_authentication" "SSH password abilitata"
    fi
}

check_ssh_root_login() {
    local sshd_config=""
    _ithaca_load_ssh_effective_config
    sshd_config="$ITHACA_SSHD_EFFECTIVE_CONFIG"

    if printf '%s\n' "$sshd_config" | grep -q '^permitrootlogin no'; then
        result_ok "ssh.root_login" "Root login SSH disabilitato"
    else
        result_critical "ssh.root_login" "Root login SSH abilitato"
    fi
}

register_check \
    "ssh.password_authentication" \
    "check_ssh_password_authentication" \
    "security" \
    "Verifica che l'autenticazione SSH tramite password sia disabilitata" \
    "yes" \
    "10"

register_check \
    "ssh.root_login" \
    "check_ssh_root_login" \
    "security" \
    "Verifica che il login SSH diretto di root sia disabilitato" \
    "yes" \
    "10"
