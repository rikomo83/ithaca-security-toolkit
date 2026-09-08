#!/usr/bin/env bash

# Renders Core API 1 results through the Sentinel output/scoring functions.
_ithaca_render_results_legacy() {
    local start_index="${1:-0}"
    local index=0
    local status=""
    local message=""
    local details=""

    for ((index = start_index; index < ${#ITHACA_RESULT_STATUSES[@]}; index += 1)); do
        status="${ITHACA_RESULT_STATUSES[$index]}"
        message="${ITHACA_RESULT_MESSAGES[$index]}"
        details="${ITHACA_RESULT_DETAILS[$index]}"

        case "$status" in
            OK)       ok "$message" ;;
            WARN)     warn "$message" ;;
            CRITICAL) crit "$message" ;;
            SKIP)     info "SKIP: $message" ;;
            ERROR)    crit "Errore check: $message" ;;
            *)        return 1 ;;
        esac

        [[ -n "$details" ]] && printf '%s\n' "$details"
    done

    return 0
}

# Preserves the Sentinel TLS grouping while rendering Core API 1 results.
_ithaca_render_tls_results_legacy() {
    local start_index="${1:-0}"
    local index=0
    local status=""
    local message=""
    local host=""
    local next_host=""
    local current_host=""

    for ((index = start_index; index < ${#ITHACA_RESULT_STATUSES[@]}; index += 1)); do
        status="${ITHACA_RESULT_STATUSES[$index]}"
        message="${ITHACA_RESULT_MESSAGES[$index]}"

        if [[ "$message" != "Nessun VirtualHost HTTPS rilevato" ]]; then
            host="${message%% *}"
            if [[ "$host" != "$current_host" ]]; then
                printf 'Host: %s\n' "$host"
                current_host="$host"
            fi
        fi

        case "$status" in
            OK)       ok "$message" ;;
            WARN)     warn "$message" ;;
            CRITICAL) crit "$message" ;;
            SKIP)     info "SKIP: $message" ;;
            ERROR)    crit "Errore check: $message" ;;
            *)        return 1 ;;
        esac

        if [[ -n "$current_host" ]]; then
            next_host=""
            if (( index + 1 < ${#ITHACA_RESULT_STATUSES[@]} )); then
                next_host="${ITHACA_RESULT_MESSAGES[$((index + 1))]%% *}"
            fi
            [[ "$next_host" == "$current_host" ]] || printf '\n'
        fi
    done

    return 0
}
