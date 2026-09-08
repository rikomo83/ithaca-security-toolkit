#!/usr/bin/env bash

check_postgres_service() {
    if systemctl is-active --quiet postgresql; then
        result_ok "postgres.service" "PostgreSQL attivo"
    else
        result_warn "postgres.service" "PostgreSQL non attivo"
    fi
}

check_postgres_listener() {
    local sockets=""

    sockets="$(ss -tulpn 2>/dev/null || true)"
    if grep -q "127.0.0.1:5432" <<< "$sockets"; then
        result_ok "postgres.listener" "PostgreSQL ascolta solo localmente"
    elif grep -q ":5432" <<< "$sockets"; then
        result_critical "postgres.listener" "PostgreSQL esposto su rete"
    else
        result_warn "postgres.listener" "PostgreSQL porta 5432 non rilevata"
    fi
}

register_check \
    "postgres.service" \
    "check_postgres_service" \
    "database" \
    "Verifica che PostgreSQL sia attivo" \
    "yes" \
    "10"

register_check \
    "postgres.listener" \
    "check_postgres_listener" \
    "database" \
    "Verifica l'esposizione della porta PostgreSQL" \
    "yes" \
    "10"
