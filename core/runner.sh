#!/usr/bin/env bash

# Executes registered Core API 1 checks. Timeout isolation is introduced later.
_ithaca_run_registered_check_id() {
    local check_id="${1:-}"
    local function_name=""
    local before_count=0
    local after_count=0
    local function_rc=0
    local start_ns=0
    local end_ns=0
    local duration_ms=0
    local result_index=0

    [[ -v "ITHACA_CHECK_FUNCTIONS[$check_id]" ]] ||
        _ithaca_set_error unknown_check_id "Check non registrato: $check_id" || return 1

    function_name="${ITHACA_CHECK_FUNCTIONS[$check_id]}"
    before_count="${#ITHACA_RESULT_STATUSES[@]}"
    start_ns="$(date '+%s%N' 2>/dev/null || printf '0')"
    "$function_name"
    function_rc=$?
    after_count="${#ITHACA_RESULT_STATUSES[@]}"

    if (( function_rc != 0 )); then
        result_error "$check_id" "Check terminato con codice $function_rc"
    elif (( after_count == before_count )); then
        result_error "$check_id" "Check terminato senza produrre un risultato"
    fi

    end_ns="$(date '+%s%N' 2>/dev/null || printf '0')"
    if [[ "$start_ns" =~ ^[0-9]+$ && "$end_ns" =~ ^[0-9]+$ &&
          "$end_ns" -ge "$start_ns" ]]; then
        duration_ms=$(( (end_ns - start_ns) / 1000000 ))
    fi
    for ((result_index = before_count;
         result_index < ${#ITHACA_RESULT_STATUSES[@]};
         result_index += 1)); do
        ITHACA_RESULT_DURATIONS_MS[$result_index]="$duration_ms"
    done
}

_ithaca_run_registered_checks() {
    local wanted_category="${1:-}"
    local check_id=""

    for check_id in "${ITHACA_CHECK_IDS[@]}"; do
        if [[ -n "$wanted_category" &&
              "${ITHACA_CHECK_CATEGORIES[$check_id]}" != "$wanted_category" ]]; then
            continue
        fi
        _ithaca_run_registered_check_id "$check_id" || return 1
    done
}
