#!/usr/bin/env bash

_ithaca_serialize_worker_results() {
    local output_file="${1:-}"
    local result_index=0

    : > "$output_file" || return 1
    for ((result_index = 0;
         result_index < ${#ITHACA_RESULT_STATUSES[@]};
         result_index += 1)); do
        printf '%s\0%s\0%s\0%s\0%s\0%s\0' \
            "${ITHACA_RESULT_CHECK_IDS[$result_index]}" \
            "${ITHACA_RESULT_STATUSES[$result_index]}" \
            "${ITHACA_RESULT_MESSAGES[$result_index]}" \
            "${ITHACA_RESULT_DETAILS[$result_index]}" \
            "${ITHACA_RESULT_TIMESTAMPS[$result_index]}" \
            "${ITHACA_RESULT_DURATIONS_MS[$result_index]}" \
            >> "$output_file" || return 1
    done
}

_ithaca_import_worker_results() {
    local input_file="${1:-}"
    local -a fields=()
    local field_index=0
    local imported_index=0
    local status=""
    local check_id=""
    local message=""

    [[ -f "$input_file" ]] || return 1
    mapfile -d '' -t fields < "$input_file"
    (( ${#fields[@]} % 6 == 0 )) || return 1

    for ((field_index = 0;
         field_index < ${#fields[@]};
         field_index += 6)); do
        check_id="${fields[$field_index]}"
        status="${fields[$((field_index + 1))]}"
        message="${fields[$((field_index + 2))]}"
        [[ "$check_id" =~ ^[a-z][a-z0-9_-]*(\.[a-z][a-z0-9_-]*)+$ ]] || return 1
        [[ "$status" =~ ^(OK|WARN|CRITICAL|SKIP|ERROR)$ ]] || return 1
        [[ -n "$message" ]] || return 1
    done

    for ((field_index = 0;
         field_index < ${#fields[@]};
         field_index += 6)); do
        _ithaca_add_result \
            "${fields[$((field_index + 1))]}" \
            "${fields[$field_index]}" \
            "${fields[$((field_index + 2))]}" \
            "${fields[$((field_index + 3))]}" || return 1
        imported_index=$((${#ITHACA_RESULT_STATUSES[@]} - 1))
        ITHACA_RESULT_TIMESTAMPS[$imported_index]="${fields[$((field_index + 4))]}"
        ITHACA_RESULT_DURATIONS_MS[$imported_index]="${fields[$((field_index + 5))]}"
    done
}

_ithaca_terminate_process_tree() {
    local process_id="${1:-}"
    local child_id=""
    local -a child_ids=()

    [[ "$process_id" =~ ^[0-9]+$ ]] || return 0
    mapfile -t child_ids < <(pgrep -P "$process_id" 2>/dev/null || true)
    for child_id in "${child_ids[@]}"; do
        _ithaca_terminate_process_tree "$child_id"
    done
    kill -TERM "$process_id" 2>/dev/null || true
    sleep 0.1
    kill -KILL "$process_id" 2>/dev/null || true
}

_ithaca_captured_output_details() {
    local stdout_file="${1:-}"
    local stderr_file="${2:-}"
    local output=""

    if [[ -s "$stdout_file" ]]; then
        output="stdout: $(head -c 4096 "$stdout_file" | tr '\000' '?')"
    fi
    if [[ -s "$stderr_file" ]]; then
        [[ -z "$output" ]] || output+=$'\n'
        output+="stderr: $(head -c 4096 "$stderr_file" | tr '\000' '?')"
    fi
    printf '%s' "$output"
}

# Execute one registered check in an isolated worker. Results are serialized as
# NUL-delimited data so check-controlled text is never evaluated as shell code.
_ithaca_run_registered_check_id() {
    local check_id="${1:-}"
    local function_name=""
    local timeout_seconds=0
    local before_count=0
    local after_count=0
    local worker_rc=0
    local worker_pid=0
    local watchdog_pid=0
    local timer_pid=0
    local start_ns=0
    local end_ns=0
    local duration_ms=0
    local result_index=0
    local run_dir=""
    local result_file=""
    local stdout_file=""
    local stderr_file=""
    local timeout_marker=""
    local captured_output=""
    local output_accounted_for=no

    [[ -v "ITHACA_CHECK_FUNCTIONS[$check_id]" ]] ||
        _ithaca_set_error unknown_check_id "Check non registrato: $check_id" || return 1

    function_name="${ITHACA_CHECK_FUNCTIONS[$check_id]}"
    timeout_seconds="${ITHACA_CHECK_TIMEOUTS[$check_id]}"
    before_count="${#ITHACA_RESULT_STATUSES[@]}"
    run_dir="$(mktemp -d "${TMPDIR:-/tmp}/ithaca-check.XXXXXXXX")" || {
        result_error "$check_id" "Impossibile creare l'ambiente isolato del check"
        return 0
    }
    result_file="$run_dir/results"
    stdout_file="$run_dir/stdout"
    stderr_file="$run_dir/stderr"
    timeout_marker="$run_dir/timed-out"
    start_ns="$(date '+%s%N' 2>/dev/null || printf '0')"

    (
        _ithaca_results_reset
        "$function_name"
        worker_rc=$?
        _ithaca_serialize_worker_results "$result_file" || exit 125
        exit "$worker_rc"
    ) > "$stdout_file" 2> "$stderr_file" &
    worker_pid=$!

    (
        timer_pid=0
        trap 'if (( timer_pid > 1 )); then kill -TERM "$timer_pid" 2>/dev/null || true; fi; exit 0' TERM INT
        sleep "$timeout_seconds" &
        timer_pid=$!
        wait "$timer_pid" 2>/dev/null || exit 0
        if kill -0 "$worker_pid" 2>/dev/null; then
            : > "$timeout_marker"
            _ithaca_terminate_process_tree "$worker_pid"
        fi
    ) &
    watchdog_pid=$!

    wait "$worker_pid" 2>/dev/null
    worker_rc=$?
    kill -TERM "$watchdog_pid" 2>/dev/null || true
    wait "$watchdog_pid" 2>/dev/null || true
    captured_output="$(_ithaca_captured_output_details "$stdout_file" "$stderr_file")"

    if [[ -f "$timeout_marker" ]]; then
        result_error "$check_id" "Timeout dopo ${timeout_seconds}s" "$captured_output"
        output_accounted_for=yes
    elif ! _ithaca_import_worker_results "$result_file"; then
        result_error "$check_id" "Risultati del check non validi" "$captured_output"
        output_accounted_for=yes
    else
        after_count="${#ITHACA_RESULT_STATUSES[@]}"
        if (( worker_rc != 0 )); then
            result_error "$check_id" "Check terminato con codice $worker_rc" "$captured_output"
            output_accounted_for=yes
        elif (( after_count == before_count )); then
            result_error "$check_id" "Check terminato senza produrre un risultato" "$captured_output"
            output_accounted_for=yes
        fi
    fi

    if [[ -n "$captured_output" && "$output_accounted_for" == no ]]; then
        result_error "$check_id" "Check ha prodotto output inatteso" "$captured_output"
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

    rm -rf -- "$run_dir"
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
