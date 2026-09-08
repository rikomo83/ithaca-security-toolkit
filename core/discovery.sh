#!/usr/bin/env bash

declare -ag ITHACA_PLUGIN_IDS=()
declare -ag ITHACA_DISCOVERY_ERRORS=()

_ithaca_discovery_error() {
    ITHACA_DISCOVERY_ERRORS+=("${1:-Errore discovery plugin}")
    return 1
}

_ithaca_trim() {
    local value="${1:-}"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s' "$value"
}

_ithaca_plugin_path_is_secure() {
    local path="${1:-}"
    local expected_type="${2:-file}"
    local allowed_root="${3:-}"
    local canonical_path=""
    local canonical_root=""
    local owner=""
    local mode=""
    local mode_value=0
    local trusted_uid="${ITHACA_TRUSTED_UID:-0}"

    [[ -n "$path" && -n "$allowed_root" ]] || return 1
    [[ ! -L "$path" ]] || return 1

    case "$expected_type" in
        file) [[ -f "$path" ]] || return 1 ;;
        dir)  [[ -d "$path" ]] || return 1 ;;
        *)    return 1 ;;
    esac

    canonical_path="$(readlink -f -- "$path")" || return 1
    canonical_root="$(readlink -f -- "$allowed_root")" || return 1
    [[ "$canonical_path" == "$canonical_root" ||
       "$canonical_path" == "$canonical_root"/* ]] || return 1

    owner="$(stat -c '%u' -- "$path")" || return 1
    [[ "$owner" == 0 || "$owner" == "$trusted_uid" ]] || return 1

    mode="$(stat -c '%a' -- "$path")" || return 1
    [[ "$mode" =~ ^[0-7]{3,4}$ ]] || return 1
    mode_value=$((8#$mode))
    (( (mode_value & 022) == 0 ))
}

_ithaca_plugin_conf_read() {
    local conf_file="${1:-}"
    local line=""
    local key=""
    local value=""

    ITHACA_PLUGIN_CONF_ID=""
    ITHACA_PLUGIN_CONF_NAME=""
    ITHACA_PLUGIN_CONF_VERSION=""
    ITHACA_PLUGIN_CONF_API=""
    ITHACA_PLUGIN_CONF_VENDOR=""
    ITHACA_PLUGIN_CONF_DESCRIPTION=""
    ITHACA_PLUGIN_CONF_ENABLED=""

    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%$'\r'}"
        line="$(_ithaca_trim "$line")"
        [[ -z "$line" || "$line" == \#* ]] && continue
        [[ "$line" == *=* ]] || return 1

        key="$(_ithaca_trim "${line%%=*}")"
        value="$(_ithaca_trim "${line#*=}")"
        [[ "$value" != *'`'* && "$value" != *'$('* ]] || return 1

        if [[ "$value" == \"*\" && ${#value} -ge 2 ]]; then
            value="${value:1:${#value}-2}"
        elif [[ "$value" == \'*\' && ${#value} -ge 2 ]]; then
            value="${value:1:${#value}-2}"
        fi

        case "$key" in
            PLUGIN_ID)          ITHACA_PLUGIN_CONF_ID="$value" ;;
            PLUGIN_NAME)        ITHACA_PLUGIN_CONF_NAME="$value" ;;
            PLUGIN_VERSION)     ITHACA_PLUGIN_CONF_VERSION="$value" ;;
            PLUGIN_API)         ITHACA_PLUGIN_CONF_API="$value" ;;
            PLUGIN_VENDOR)      ITHACA_PLUGIN_CONF_VENDOR="$value" ;;
            PLUGIN_DESCRIPTION) ITHACA_PLUGIN_CONF_DESCRIPTION="$value" ;;
            PLUGIN_ENABLED)     ITHACA_PLUGIN_CONF_ENABLED="$value" ;;
            *) return 1 ;;
        esac
    done < "$conf_file"

    [[ "$ITHACA_PLUGIN_CONF_ID" =~ ^[a-z][a-z0-9_-]*$ ]] || return 1
    [[ -n "$ITHACA_PLUGIN_CONF_NAME" ]] || return 1
    [[ "$ITHACA_PLUGIN_CONF_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$ ]] || return 1
    [[ "$ITHACA_PLUGIN_CONF_API" == 1 ]] || return 1
    [[ -n "$ITHACA_PLUGIN_CONF_VENDOR" ]] || return 1
    [[ -n "$ITHACA_PLUGIN_CONF_DESCRIPTION" ]] || return 1
    [[ "$ITHACA_PLUGIN_CONF_ENABLED" == yes || "$ITHACA_PLUGIN_CONF_ENABLED" == no ]] || return 1
}

_ithaca_plugin_public_api_snapshot() {
    local function_name=""

    for function_name in \
        register_check result_ok result_warn result_critical result_skip result_error \
        config_get config_is_enabled log_debug log_info log_warn log_error \
        command_exists require_command; do
        declare -f "$function_name" 2>/dev/null || true
    done
}

_ithaca_plugin_validate_checks() {
    local plugin_id="${1:-}"
    shift
    local check_file=""
    local api_before=""
    local api_after=""
    local load_output=""
    local load_rc=0

    api_before="$(_ithaca_plugin_public_api_snapshot)"
    load_output="$({
        ITHACA_PLUGIN_LOADING_ID="$plugin_id"
        for check_file in "$@"; do
            source "$check_file" || exit 1
        done
        api_after="$(_ithaca_plugin_public_api_snapshot)"
        [[ "$api_after" == "$api_before" ]] || exit 1
    } 2>&1)" || load_rc=$?

    (( load_rc == 0 )) || return 1
    [[ -z "$load_output" ]]
}

_ithaca_load_plugin() {
    local plugin_dir="${1:-}"
    local plugin_root="${2:-}"
    local plugin_id="${plugin_dir##*/}"
    local conf_file="$plugin_dir/plugin.conf"
    local checks_dir="$plugin_dir/checks"
    local check_file=""
    local -a check_files=()

    _ithaca_plugin_path_is_secure "$plugin_dir" dir "$plugin_root" ||
        _ithaca_discovery_error "Directory plugin non sicura: $plugin_id" || return 1
    _ithaca_plugin_path_is_secure "$conf_file" file "$plugin_root" ||
        _ithaca_discovery_error "Configurazione plugin non sicura: $plugin_id" || return 1
    _ithaca_plugin_path_is_secure "$checks_dir" dir "$plugin_root" ||
        _ithaca_discovery_error "Directory check non sicura: $plugin_id" || return 1
    _ithaca_plugin_conf_read "$conf_file" ||
        _ithaca_discovery_error "Metadati plugin non validi: $plugin_id" || return 1

    [[ "$ITHACA_PLUGIN_CONF_ID" == "$plugin_id" ]] ||
        _ithaca_discovery_error "PLUGIN_ID non coincide con la directory: $plugin_id" || return 1
    [[ "$ITHACA_PLUGIN_CONF_ENABLED" == yes ]] || return 0

    while IFS= read -r -d '' check_file; do
        _ithaca_plugin_path_is_secure "$check_file" file "$plugin_root" ||
            _ithaca_discovery_error "File check plugin non sicuro: $check_file" || return 1
        check_files+=("$check_file")
    done < <(find "$checks_dir" -maxdepth 1 -type f -name '*.sh' -print0 | LC_ALL=C sort -z)

    (( ${#check_files[@]} > 0 )) ||
        _ithaca_discovery_error "Plugin senza check: $plugin_id" || return 1
    _ithaca_plugin_validate_checks "$plugin_id" "${check_files[@]}" ||
        _ithaca_discovery_error "Contratto check plugin non valido: $plugin_id" || return 1

    ITHACA_PLUGIN_LOADING_ID="$plugin_id"
    for check_file in "${check_files[@]}"; do
        source "$check_file" || {
            unset ITHACA_PLUGIN_LOADING_ID
            _ithaca_discovery_error "Caricamento plugin fallito: $plugin_id"
            return 1
        }
    done
    unset ITHACA_PLUGIN_LOADING_ID
    ITHACA_PLUGIN_IDS+=("$plugin_id")
}

discover_plugins() {
    local plugin_root="${ITHACA_PLUGIN_DIR:-${ITHACA_BASE_DIR}/plugins.d}"
    local plugin_dir=""

    ITHACA_PLUGIN_IDS=()
    ITHACA_DISCOVERY_ERRORS=()
    [[ -e "$plugin_root" ]] || return 0
    _ithaca_plugin_path_is_secure "$plugin_root" dir "$plugin_root" ||
        _ithaca_discovery_error "Directory plugin principale non sicura" || return 1

    while IFS= read -r -d '' plugin_dir; do
        _ithaca_load_plugin "$plugin_dir" "$plugin_root" || true
    done < <(find "$plugin_root" -mindepth 1 -maxdepth 1 -type d -print0 | LC_ALL=C sort -z)

    return 0
}
