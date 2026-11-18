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

# ---------------------------------------------------------------------------
# v1.3: baseline di hardening oltre password e root login.
# Valori di riferimento allineati al drop-in /etc/ssh/sshd_config.d/10-ithaca.conf.
# ---------------------------------------------------------------------------

_ithaca_sshd_value() {
    local key="${1:-}"
    printf '%s\n' "$ITHACA_SSHD_EFFECTIVE_CONFIG" |
        awk -v k="$key" 'tolower($1) == k { $1 = ""; sub(/^ /, ""); print; exit }'
}

check_ssh_hardening() {
    local value=""
    local problems=()

    _ithaca_load_ssh_effective_config
    if [[ -z "$ITHACA_SSHD_EFFECTIVE_CONFIG" ]]; then
        result_error "ssh.hardening" "Impossibile leggere la configurazione effettiva (sshd -T)"
        return
    fi

    [[ "$(_ithaca_sshd_value kbdinteractiveauthentication)" == "no" ]] ||
        problems+=("kbdinteractiveauthentication non e 'no'")
    [[ "$(_ithaca_sshd_value x11forwarding)" == "no" ]] ||
        problems+=("x11forwarding non e 'no'")
    [[ "$(_ithaca_sshd_value allowagentforwarding)" == "no" ]] ||
        problems+=("allowagentforwarding non e 'no'")

    value="$(_ithaca_sshd_value maxauthtries)"
    [[ "$value" =~ ^[0-9]+$ ]] && (( value <= 4 )) ||
        problems+=("maxauthtries=${value:-?} (atteso <= 4)")

    value="$(_ithaca_sshd_value logingracetime)"
    [[ "$value" =~ ^[0-9]+$ ]] && (( value > 0 && value <= 60 )) ||
        problems+=("logingracetime=${value:-?} (atteso 1-60 s)")

    value="$(_ithaca_sshd_value clientaliveinterval)"
    [[ "$value" =~ ^[0-9]+$ ]] && (( value > 0 )) ||
        problems+=("clientaliveinterval=${value:-?} (atteso > 0)")

    if (( ${#problems[@]} == 0 )); then
        result_ok "ssh.hardening" "Baseline di hardening SSH applicata"
    else
        result_warn "ssh.hardening" "Baseline di hardening SSH incompleta" \
            "$(printf '%s\n' "${problems[@]}")"
    fi
}

check_ssh_allow_users() {
    local users=""
    local groups=""

    _ithaca_load_ssh_effective_config
    users="$(_ithaca_sshd_value allowusers)"
    groups="$(_ithaca_sshd_value allowgroups)"

    if [[ -n "$users" || -n "$groups" ]]; then
        result_ok "ssh.allow_users" "Accesso SSH limitato (AllowUsers/AllowGroups)" \
            "${users:+allowusers $users}${groups:+ allowgroups $groups}"
    else
        result_warn "ssh.allow_users" "Nessun AllowUsers/AllowGroups: ogni utente locale puo tentare l'accesso"
    fi
}

register_check \
    "ssh.hardening" \
    "check_ssh_hardening" \
    "security" \
    "Verifica forwarding, MaxAuthTries, LoginGraceTime e ClientAlive di sshd" \
    "yes" \
    "10"

register_check \
    "ssh.allow_users" \
    "check_ssh_allow_users" \
    "security" \
    "Verifica che l'accesso SSH sia limitato con AllowUsers o AllowGroups" \
    "yes" \
    "10"
