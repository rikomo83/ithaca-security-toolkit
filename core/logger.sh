#!/usr/bin/env bash

# Structured, colour-free Core logger. ITHACA_LOG_FILE is optional.
ITHACA_LOG_LEVEL="${ITHACA_LOG_LEVEL:-INFO}"
ITHACA_LOG_FILE="${ITHACA_LOG_FILE:-}"

_ithaca_log_level_value() {
    case "${1^^}" in
        DEBUG) printf '%s' 10 ;;
        INFO)  printf '%s' 20 ;;
        WARN)  printf '%s' 30 ;;
        ERROR) printf '%s' 40 ;;
        *)     return 1 ;;
    esac
}

_ithaca_log_timestamp() {
    date '+%Y-%m-%dT%H:%M:%S%z'
}

_ithaca_log() {
    local level="${1:-INFO}"
    local message="${2:-}"
    local configured_value
    local message_value
    local record

    configured_value="$(_ithaca_log_level_value "$ITHACA_LOG_LEVEL")" || configured_value=20
    message_value="$(_ithaca_log_level_value "$level")" || return 1
    (( message_value < configured_value )) && return 0

    record="$(printf '%s %-5s %s' "$(_ithaca_log_timestamp)" "${level^^}" "$message")"
    printf '%s\n' "$record"

    if [[ -n "$ITHACA_LOG_FILE" ]]; then
        printf '%s\n' "$record" >> "$ITHACA_LOG_FILE" || return 1
    fi
}

log_debug() { _ithaca_log DEBUG "${1:-}"; }
log_info()  { _ithaca_log INFO  "${1:-}"; }
log_warn()  { _ithaca_log WARN  "${1:-}"; }
log_error() { _ithaca_log ERROR "${1:-}"; }
