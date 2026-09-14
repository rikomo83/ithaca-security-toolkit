#!/usr/bin/env bash

_ithaca_json_escape() {
    local value="${1:-}"

    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    value="${value//$'\b'/\\b}"
    value="${value//$'\f'/\\f}"
    value="${value//$'\n'/\\n}"
    value="${value//$'\r'/\\r}"
    value="${value//$'\t'/\\t}"
    printf '%s' "$value"
}

_ithaca_toolkit_version() {
    local version_file="${ITHACA_BASE_DIR}/VERSION"
    local version="${ITHACA_TOOLKIT_VERSION:-}"

    if [[ -z "$version" && -f "$version_file" ]]; then
        version="$(awk -F= '$1 == "VERSION" {gsub(/["[:space:]]/, "", $2); print $2; exit}' "$version_file")"
    fi
    printf '%s' "${version:-unknown}"
}

_ithaca_result_module_version() {
    local check_id="${1:-}"
    local namespace="${check_id%%.*}"
    local toolkit_version="${2:-unknown}"

    if declare -p ITHACA_PLUGIN_VERSIONS >/dev/null 2>&1 &&
       [[ -v "ITHACA_PLUGIN_VERSIONS[$namespace]" ]]; then
        printf '%s' "${ITHACA_PLUGIN_VERSIONS[$namespace]}"
    else
        printf '%s' "$toolkit_version"
    fi
}

write_json_report() {
    local target="${1:-}"
    local target_dir=""
    local temporary=""
    local toolkit_version=""
    local host="${ITHACA_REPORT_HOST:-}"
    local generated_at="${ITHACA_REPORT_TIMESTAMP:-}"
    local run_id="${ITHACA_RUN_ID:-}"
    local index=0
    local check_id=""
    local category=""
    local duration_ms=0
    local module_version=""

    [[ -n "$target" ]] || return 1
    target_dir="$(dirname -- "$target")"
    [[ -d "$target_dir" ]] || return 1
    temporary="$(mktemp "${target}.tmp.XXXXXX")" || return 1
    toolkit_version="$(_ithaca_toolkit_version)"
    [[ -n "$host" ]] || host="$(hostname -f 2>/dev/null || hostname)"
    [[ -n "$generated_at" ]] || generated_at="$(_ithaca_result_timestamp)"
    [[ -n "$run_id" ]] || run_id="${generated_at}-$$"

    {
        printf '{\n'
        printf '  "schema_version": 1,\n'
        printf '  "run_id": "%s",\n' "$(_ithaca_json_escape "$run_id")"
        printf '  "generated_at": "%s",\n' "$(_ithaca_json_escape "$generated_at")"
        printf '  "host": "%s",\n' "$(_ithaca_json_escape "$host")"
        printf '  "toolkit_version": "%s",\n' "$(_ithaca_json_escape "$toolkit_version")"
        printf '  "core_api": "%s",\n' "$(_ithaca_json_escape "${ITHACA_CORE_API:-1}")"
        printf '  "summary": {"warnings": %s, "critical": %s, "score": %s},\n' \
            "${WARN:-0}" "${CRIT:-0}" "${SCORE:-100}"
        printf '  "results": [\n'

        for ((index = 0; index < ${#ITHACA_RESULT_STATUSES[@]}; index += 1)); do
            check_id="${ITHACA_RESULT_CHECK_IDS[$index]}"
            category="unknown"
            [[ -v "ITHACA_CHECK_CATEGORIES[$check_id]" ]] &&
                category="${ITHACA_CHECK_CATEGORIES[$check_id]}"
            duration_ms="${ITHACA_RESULT_DURATIONS_MS[$index]:-0}"
            [[ "$duration_ms" =~ ^[0-9]+$ ]] || duration_ms=0
            module_version="$(_ithaca_result_module_version "$check_id" "$toolkit_version")"

            printf '    {'
            printf '"check_id":"%s",' "$(_ithaca_json_escape "$check_id")"
            printf '"category":"%s",' "$(_ithaca_json_escape "$category")"
            printf '"status":"%s",' "$(_ithaca_json_escape "${ITHACA_RESULT_STATUSES[$index]}")"
            printf '"message":"%s",' "$(_ithaca_json_escape "${ITHACA_RESULT_MESSAGES[$index]}")"
            printf '"details":"%s",' "$(_ithaca_json_escape "${ITHACA_RESULT_DETAILS[$index]}")"
            printf '"timestamp":"%s",' "$(_ithaca_json_escape "${ITHACA_RESULT_TIMESTAMPS[$index]}")"
            printf '"duration_ms":%s,' "$duration_ms"
            printf '"module_version":"%s"}' "$(_ithaca_json_escape "$module_version")"
            (( index + 1 < ${#ITHACA_RESULT_STATUSES[@]} )) && printf ','
            printf '\n'
        done

        printf '  ]\n'
        printf '}\n'
    } > "$temporary" || {
        rm -f -- "$temporary"
        return 1
    }

    chmod 0640 "$temporary" || {
        rm -f -- "$temporary"
        return 1
    }
    mv -f -- "$temporary" "$target"
}
