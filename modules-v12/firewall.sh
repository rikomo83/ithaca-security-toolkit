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
