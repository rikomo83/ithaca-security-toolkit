#!/usr/bin/env bash

if [[ "${ITHACA_CONFIG_API_LOADED:-no}" == yes ]]; then
    return 0
fi
ITHACA_CONFIG_API_LOADED=yes

declare -Ag ITHACA_CONFIG_VALUES=()

config_load() {
    local config_file="${1:-}"
    local line=""
    local key=""
    local value=""

    ITHACA_CONFIG_VALUES=()
    [[ -f "$config_file" ]] || return 0

    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%$'\r'}"
        [[ "$line" =~ ^[[:space:]]*$ ]] && continue
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ "$line" =~ ^[[:space:]]*([A-Z][A-Z0-9_]*)[[:space:]]*=(.*)$ ]] || continue

        key="${BASH_REMATCH[1]}"
        value="${BASH_REMATCH[2]}"
        value="${value#"${value%%[![:space:]]*}"}"
        value="${value%"${value##*[![:space:]]}"}"

        if [[ "$value" =~ ^\"(.*)\"$ ]]; then
            value="${BASH_REMATCH[1]}"
        elif [[ "$value" =~ ^\'(.*)\'$ ]]; then
            value="${BASH_REMATCH[1]}"
        fi

        if [[ "$value" == *'$('* || "$value" == *'`'* || "$value" == *';'* ]]; then
            printf 'Valore di configurazione non sicuro ignorato: %s\n' "$key" >&2
            continue
        fi

        ITHACA_CONFIG_VALUES["$key"]="$value"
    done < "$config_file"
}

config_get() {
    local key="${1:-}"
    local default_value="${2:-}"
    printf '%s' "${ITHACA_CONFIG_VALUES[$key]:-$default_value}"
}

config_is_enabled() {
    local value=""
    value="$(config_get "${1:-}" "${2:-no}")"
    value="${value,,}"
    [[ "$value" == "yes" || "$value" == "true" || "$value" == "1" || "$value" == "on" ]]
}

config_equals() {
    local actual=""
    actual="$(config_get "${1:-}" "${3:-}")"
    [[ "${actual,,}" == "${2:-}" ]]
}
