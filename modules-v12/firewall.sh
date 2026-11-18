#!/usr/bin/env bash

check_firewall_status() {
    local backend_output=""
    local probe_errors=""

    if command -v ufw >/dev/null 2>&1; then
        if backend_output="$(ufw status 2>&1)"; then
            if grep -q "Status: active" <<< "$backend_output"; then
                result_ok "firewall.status" "UFW attivo"
                return
            fi
        else
            probe_errors="ufw: $backend_output"
        fi
    fi

    if command -v nft >/dev/null 2>&1; then
        if backend_output="$(nft list ruleset 2>&1)"; then
            if awk '
                /hook[[:space:]]+input([[:space:];]|$)/ &&
                /policy[[:space:]]+(drop|reject)([[:space:];]|$)/ {
                    protected = 1
                }
                END { exit protected ? 0 : 1 }
            ' <<< "$backend_output"; then
                result_ok \
                    "firewall.status" \
                    "nftables attivo con policy input restrittiva"
                return
            fi
        else
            [[ -z "$probe_errors" ]] || probe_errors+=$'\n'
            probe_errors+="nft: $backend_output"
        fi
    fi

    if command -v iptables >/dev/null 2>&1; then
        if backend_output="$(iptables -S 2>&1)"; then
            if awk '
                $1 == "-P" && $2 == "INPUT" &&
                ($3 == "DROP" || $3 == "REJECT") {
                    protected = 1
                }
                END { exit protected ? 0 : 1 }
            ' <<< "$backend_output"; then
                result_ok \
                    "firewall.status" \
                    "iptables attivo con policy INPUT restrittiva"
                return
            fi
        else
            [[ -z "$probe_errors" ]] || probe_errors+=$'\n'
            probe_errors+="iptables: $backend_output"
        fi
    fi

    result_critical \
        "firewall.status" \
        "Nessun firewall attivo con policy input restrittiva" \
        "$probe_errors"
}

register_check \
    "firewall.status" \
    "check_firewall_status" \
    "security" \
    "Verifica che UFW sia attivo" \
    "yes" \
    "10"

# ---------------------------------------------------------------------------
# v1.3: controlli consapevoli di Docker e del firewall del provider.
#
# Su un host Docker UFW non filtra le porte pubblicate dai container: Docker
# inserisce le proprie regole nelle catene nat/FORWARD prima di quelle di UFW.
# Per questo "UFW attivo" non basta a dire che il perimetro e chiuso.
# ---------------------------------------------------------------------------

# Porte di database/servizi interni: se esposte su tutte le interfacce il
# risultato e CRITICAL invece di WARN.
ITHACA_SENSITIVE_PORTS="${ITHACA_SENSITIVE_PORTS:-3306,5432-5439,6379,9200,9300,11211,27017,2375,2376}"
ITHACA_SWARM_PORTS="2377,7946,4789"
ITHACA_UFW_DEFAULTS="${ITHACA_UFW_DEFAULTS:-/etc/default/ufw}"

# Restituisce 0 se la porta $1 appartiene alla lista $2 ("22,80,8000-8010").
_ithaca_port_in_list() {
    local port="${1:-}"
    local list="${2:-}"
    local item=""
    local low=""
    local high=""

    [[ "$port" =~ ^[0-9]+$ ]] || return 1
    list="${list// /}"
    IFS=',' read -r -a _ithaca_port_items <<< "$list"
    for item in "${_ithaca_port_items[@]}"; do
        [[ -n "$item" ]] || continue
        if [[ "$item" =~ ^([0-9]+)-([0-9]+)$ ]]; then
            low="${BASH_REMATCH[1]}"
            high="${BASH_REMATCH[2]}"
            (( port >= low && port <= high )) && return 0
        elif [[ "$item" =~ ^[0-9]+$ ]]; then
            (( port == item )) && return 0
        fi
    done
    return 1
}

_ithaca_allowed_public_ports() {
    local ssh_port=""
    local allowed=""
    ssh_port="$(config_get SSH_PORT 22)"
    allowed="$(config_get ALLOWED_PUBLIC_PORTS "80,443")"
    printf '%s,%s' "$ssh_port" "$allowed"
}

_ithaca_docker_present() {
    if config_equals DOCKER no; then
        return 1
    fi
    command -v docker >/dev/null 2>&1 || return 1
    systemctl is-active --quiet docker 2>/dev/null
}

# Emette "proto porta processo" per ogni socket in ascolto su indirizzi non
# di loopback. Usa ss -H -tulpn (tcp+udp, numerico, con processo).
_ithaca_public_listeners() {
    local raw=""
    raw="$(ss -H -tulpn 2>/dev/null)" || return 1
    awk '
        {
            proto = $1
            local_addr = $5
            n = split(local_addr, parts, ":")
            port = parts[n]
            addr = substr(local_addr, 1, length(local_addr) - length(port) - 1)
            gsub(/%.*/, "", addr)
            if (addr ~ /^127\./ || addr == "[::1]" || addr == "::1") next
            if (port !~ /^[0-9]+$/) next
            # client DHCP/DHCPv6: non sono servizi esposti
            if (proto == "udp" && (port == 68 || port == 546)) next
            proc = "-"
            if (match($0, /users:\(\("[^"]+"/)) {
                proc = substr($0, RSTART + 9, RLENGTH - 10)
            }
            print proto, port, proc
        }
    ' <<< "$raw" | sort -u -k1,1 -k2,2n -k3,3
}

_ithaca_is_docker_process() {
    [[ "${1:-}" == "docker-proxy" || "${1:-}" == "dockerd" ]]
}

check_firewall_ufw_rules() {
    local status=""
    local ssh_port=""
    local problems=()

    if ! command -v ufw >/dev/null 2>&1; then
        result_skip "firewall.ufw_rules" "UFW non installato"
        return
    fi

    status="$(ufw status verbose 2>&1)" || {
        result_error "firewall.ufw_rules" "Impossibile leggere lo stato di UFW" "$status"
        return
    }

    if ! grep -q "Status: active" <<< "$status"; then
        result_skip "firewall.ufw_rules" "UFW non attivo"
        return
    fi

    ssh_port="$(config_get SSH_PORT 22)"
    grep -Eq 'Default:[[:space:]]+(deny|reject)[[:space:]]+\(incoming\)' <<< "$status" ||
        problems+=("policy incoming non restrittiva")
    grep -Eq "^(${ssh_port}(/tcp)?|OpenSSH)[[:space:]]+(ALLOW|LIMIT)" <<< "$status" ||
        problems+=("nessuna regola ALLOW/LIMIT per SSH (porta ${ssh_port})")

    if [[ -f "$ITHACA_UFW_DEFAULTS" ]] && ! grep -Eq '^IPV6=yes' "$ITHACA_UFW_DEFAULTS"; then
        problems+=("IPV6 non gestito da UFW ($ITHACA_UFW_DEFAULTS)")
    fi

    if (( ${#problems[@]} == 0 )); then
        result_ok "firewall.ufw_rules" "UFW: policy deny in ingresso e SSH consentito"
    else
        result_warn "firewall.ufw_rules" "UFW: regole da rivedere" \
            "$(printf '%s\n' "${problems[@]}")"
    fi
}

check_firewall_exposed_listeners() {
    local listeners=""
    local allowed=""
    local proto=""
    local port=""
    local proc=""
    local warn_items=()
    local crit_items=()

    listeners="$(_ithaca_public_listeners)" || {
        result_error "firewall.exposed_listeners" "Impossibile elencare i socket in ascolto (ss)"
        return
    }
    allowed="$(_ithaca_allowed_public_ports)"

    while read -r proto port proc; do
        [[ -n "${port:-}" ]] || continue
        _ithaca_is_docker_process "$proc" && continue
        _ithaca_port_in_list "$port" "$allowed" && continue
        if _ithaca_port_in_list "$port" "$ITHACA_SENSITIVE_PORTS"; then
            crit_items+=("$proto/$port ($proc)")
        else
            warn_items+=("$proto/$port ($proc)")
        fi
    done <<< "$listeners"

    if (( ${#crit_items[@]} > 0 )); then
        result_critical "firewall.exposed_listeners" \
            "Servizi sensibili in ascolto su interfacce pubbliche" \
            "$(printf '%s\n' "${crit_items[@]}" "${warn_items[@]}")"
    elif (( ${#warn_items[@]} > 0 )); then
        result_warn "firewall.exposed_listeners" \
            "Servizi host in ascolto fuori da ALLOWED_PUBLIC_PORTS" \
            "$(printf '%s\n' "${warn_items[@]}")"
    else
        result_ok "firewall.exposed_listeners" \
            "Nessun servizio host esposto oltre le porte consentite"
    fi
}

check_firewall_docker_bypass() {
    local listeners=""
    local allowed=""
    local proto=""
    local port=""
    local proc=""
    local docker_user=""
    local items=()
    local sensitive=0
    local note=""

    if ! _ithaca_docker_present; then
        result_skip "firewall.docker_bypass" "Docker non presente o non attivo"
        return
    fi

    listeners="$(_ithaca_public_listeners)" || {
        result_error "firewall.docker_bypass" "Impossibile elencare i socket in ascolto (ss)"
        return
    }
    allowed="$(_ithaca_allowed_public_ports)"

    while read -r proto port proc; do
        [[ -n "${port:-}" ]] || continue
        _ithaca_is_docker_process "$proc" || continue
        _ithaca_port_in_list "$port" "$allowed" && continue
        # le porte Swarm sono valutate da firewall.swarm_ports
        _ithaca_port_in_list "$port" "$ITHACA_SWARM_PORTS" && continue
        items+=("$proto/$port ($proc)")
        _ithaca_port_in_list "$port" "$ITHACA_SENSITIVE_PORTS" && sensitive=1
    done <<< "$listeners"

    if (( ${#items[@]} == 0 )); then
        result_ok "firewall.docker_bypass" \
            "Docker pubblica solo porte consentite (ALLOWED_PUBLIC_PORTS)"
        return
    fi

    # DOCKER-USER con sola RETURN = nessun filtro sul traffico verso i container.
    docker_user="$(iptables -S DOCKER-USER 2>/dev/null || true)"
    if grep -Evq '^-N DOCKER-USER$|^-A DOCKER-USER -j RETURN$' <<< "$docker_user"; then
        note="DOCKER-USER contiene regole: verificare che filtrino queste porte."
    else
        note="DOCKER-USER vuota: UFW non filtra queste porte."
    fi
    if config_is_enabled HETZNER no; then
        note+=" Bloccarle nel firewall Hetzner e verificare con scansione esterna."
    else
        note+=" Bloccarle nel firewall del provider o in DOCKER-USER."
    fi

    if (( sensitive == 1 )); then
        result_critical "firewall.docker_bypass" \
            "Porte Docker sensibili pubblicate su tutte le interfacce (UFW non le filtra)" \
            "$(printf '%s\n' "${items[@]}" "$note")"
    else
        result_warn "firewall.docker_bypass" \
            "Porte Docker pubblicate fuori da ALLOWED_PUBLIC_PORTS (UFW non le filtra)" \
            "$(printf '%s\n' "${items[@]}" "$note")"
    fi
}

check_firewall_swarm_ports() {
    local state=""
    local nodes=""
    local listeners=""
    local proto=""
    local port=""
    local proc=""
    local items=()

    if ! _ithaca_docker_present; then
        result_skip "firewall.swarm_ports" "Docker non presente o non attivo"
        return
    fi

    state="$(docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null || true)"
    if [[ "$state" != "active" ]]; then
        result_skip "firewall.swarm_ports" "Docker Swarm non attivo"
        return
    fi

    nodes="$(docker info --format '{{.Swarm.Nodes}}' 2>/dev/null || true)"
    listeners="$(_ithaca_public_listeners 2>/dev/null || true)"
    while read -r proto port proc; do
        [[ -n "${port:-}" ]] || continue
        _ithaca_port_in_list "$port" "$ITHACA_SWARM_PORTS" && items+=("$proto/$port ($proc)")
    done <<< "$listeners"

    if (( ${#items[@]} == 0 )); then
        result_ok "firewall.swarm_ports" "Porte di gestione Swarm non in ascolto su interfacce pubbliche"
    elif [[ "$nodes" == "1" ]]; then
        result_warn "firewall.swarm_ports" \
            "Swarm a nodo singolo con porte di gestione in ascolto pubblico" \
            "$(printf '%s\n' "${items[@]}" "Con un solo nodo non servono dall'esterno: bloccarle nel firewall del provider.")"
    else
        result_warn "firewall.swarm_ports" \
            "Porte Swarm in ascolto: limitarle ai soli nodi del cluster" \
            "$(printf '%s\n' "${items[@]}")"
    fi
}

check_firewall_ipv6() {
    local global_v6=""
    local problems=()

    global_v6="$(ip -6 -o addr show scope global 2>/dev/null | awk '{print $4}' | paste -sd' ' -)"
    if [[ -z "$global_v6" ]]; then
        result_ok "firewall.ipv6" "Nessun indirizzo IPv6 globale"
        return
    fi

    if command -v ufw >/dev/null 2>&1 &&
       ufw status 2>/dev/null | grep -q "Status: active" &&
       [[ -f "$ITHACA_UFW_DEFAULTS" ]] &&
       ! grep -Eq '^IPV6=yes' "$ITHACA_UFW_DEFAULTS"; then
        problems+=("UFW non filtra IPv6 (IPV6=yes mancante in $ITHACA_UFW_DEFAULTS)")
    fi

    if config_is_enabled HETZNER no && ! config_is_enabled HETZNER_FILTER_IPV6 no; then
        problems+=("Firewall Hetzner: 'Filter IPv6 packets' non dichiarato attivo (HETZNER_FILTER_IPV6)")
    fi

    if (( ${#problems[@]} == 0 )); then
        result_ok "firewall.ipv6" "IPv6 globale presente e filtrato ($global_v6)"
    else
        result_warn "firewall.ipv6" "IPv6 globale ($global_v6) potenzialmente non filtrato" \
            "$(printf '%s\n' "${problems[@]}")"
    fi
}

register_check \
    "firewall.ufw_rules" \
    "check_firewall_ufw_rules" \
    "security" \
    "Verifica policy di default e regola SSH di UFW" \
    "yes" \
    "10"

register_check \
    "firewall.exposed_listeners" \
    "check_firewall_exposed_listeners" \
    "security" \
    "Elenca i servizi host in ascolto su interfacce pubbliche fuori dalle porte consentite" \
    "yes" \
    "10"

register_check \
    "firewall.docker_bypass" \
    "check_firewall_docker_bypass" \
    "security" \
    "Rileva le porte pubblicate da Docker che UFW non filtra" \
    "yes" \
    "15"

register_check \
    "firewall.swarm_ports" \
    "check_firewall_swarm_ports" \
    "security" \
    "Verifica l'esposizione delle porte di gestione Docker Swarm" \
    "yes" \
    "15"

register_check \
    "firewall.ipv6" \
    "check_firewall_ipv6" \
    "security" \
    "Verifica che il traffico IPv6 sia filtrato quando l'host ha un IPv6 globale" \
    "yes" \
    "10"
