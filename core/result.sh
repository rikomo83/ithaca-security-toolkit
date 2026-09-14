#!/usr/bin/env bash

declare -ag ITHACA_RESULT_CHECK_IDS=()
declare -ag ITHACA_RESULT_STATUSES=()
declare -ag ITHACA_RESULT_MESSAGES=()
declare -ag ITHACA_RESULT_DETAILS=()
declare -ag ITHACA_RESULT_TIMESTAMPS=()
declare -ag ITHACA_RESULT_DURATIONS_MS=()

_ithaca_results_reset() {
    ITHACA_RESULT_CHECK_IDS=()
    ITHACA_RESULT_STATUSES=()
    ITHACA_RESULT_MESSAGES=()
    ITHACA_RESULT_DETAILS=()
    ITHACA_RESULT_TIMESTAMPS=()
    ITHACA_RESULT_DURATIONS_MS=()
}

_ithaca_result_timestamp() {
    date '+%Y-%m-%dT%H:%M:%S%z'
}

_ithaca_add_result() {
    local status="${1:-}"
    local check_id="${2:-}"
    local message="${3:-}"
    local details="${4:-}"

    [[ "$status" =~ ^(OK|WARN|CRITICAL|SKIP|ERROR)$ ]] ||
        _ithaca_set_error invalid_result_status "Stato risultato non valido: $status" || return 1

    [[ "$check_id" =~ ^[a-z][a-z0-9_-]*(\.[a-z][a-z0-9_-]*)+$ ]] ||
        _ithaca_set_error invalid_result_check_id "ID risultato non valido: $check_id" || return 1

    [[ -n "$message" ]] ||
        _ithaca_set_error empty_result_message "Messaggio risultato obbligatorio" || return 1

    ITHACA_RESULT_CHECK_IDS+=("$check_id")
    ITHACA_RESULT_STATUSES+=("$status")
    ITHACA_RESULT_MESSAGES+=("$message")
    ITHACA_RESULT_DETAILS+=("$details")
    ITHACA_RESULT_TIMESTAMPS+=("$(_ithaca_result_timestamp)")
    ITHACA_RESULT_DURATIONS_MS+=("0")
}

result_ok()       { _ithaca_add_result OK       "${1:-}" "${2:-}" "${3:-}"; }
result_warn()     { _ithaca_add_result WARN     "${1:-}" "${2:-}" "${3:-}"; }
result_critical() { _ithaca_add_result CRITICAL "${1:-}" "${2:-}" "${3:-}"; }
result_skip()     { _ithaca_add_result SKIP     "${1:-}" "${2:-}" "${3:-}"; }
result_error()    { _ithaca_add_result ERROR    "${1:-}" "${2:-}" "${3:-}"; }

_ithaca_result_count() {
    local wanted="${1:-}"
    local status
    local count=0

    for status in "${ITHACA_RESULT_STATUSES[@]}"; do
        [[ "$status" == "$wanted" ]] && ((count += 1))
    done
    printf '%s' "$count"
}

_ithaca_legacy_score() {
    local warnings
    local critical
    local errors
    local score

    warnings="$(_ithaca_result_count WARN)"
    critical="$(_ithaca_result_count CRITICAL)"
    errors="$(_ithaca_result_count ERROR)"
    score=$((100 - (warnings * 3) - (critical * 10) - (errors * 10)))
    (( score < 0 )) && score=0
    printf '%s' "$score"
}
