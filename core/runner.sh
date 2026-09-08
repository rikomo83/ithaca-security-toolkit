#!/usr/bin/env bash

# Executes registered Core API 1 checks. Timeout isolation is introduced later.
_ithaca_run_registered_checks() {
    local wanted_category="${1:-}"
    local check_id=""
    local function_name=""
    local before_count=0
    local after_count=0
    local function_rc=0

    for check_id in "${ITHACA_CHECK_IDS[@]}"; do
        if [[ -n "$wanted_category" &&
              "${ITHACA_CHECK_CATEGORIES[$check_id]}" != "$wanted_category" ]]; then
            continue
        fi

        function_name="${ITHACA_CHECK_FUNCTIONS[$check_id]}"
        before_count="${#ITHACA_RESULT_STATUSES[@]}"
        "$function_name"
        function_rc=$?
        after_count="${#ITHACA_RESULT_STATUSES[@]}"

        if (( function_rc != 0 )); then
            result_error "$check_id" "Check terminato con codice $function_rc"
        elif (( after_count == before_count )); then
            result_error "$check_id" "Check terminato senza produrre un risultato"
        fi
    done
}
