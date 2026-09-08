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
