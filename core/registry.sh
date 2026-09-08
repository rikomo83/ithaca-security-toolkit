#!/usr/bin/env bash

declare -ag ITHACA_CHECK_IDS=()
declare -Ag ITHACA_CHECK_FUNCTIONS=()
declare -Ag ITHACA_CHECK_CATEGORIES=()
declare -Ag ITHACA_CHECK_DESCRIPTIONS=()
declare -Ag ITHACA_CHECK_DEFAULTS=()
declare -Ag ITHACA_CHECK_TIMEOUTS=()
ITHACA_REGISTRY_LOCKED=0

_ithaca_registry_reset() {
    ITHACA_CHECK_IDS=()
    ITHACA_CHECK_FUNCTIONS=()
    ITHACA_CHECK_CATEGORIES=()
    ITHACA_CHECK_DESCRIPTIONS=()
    ITHACA_CHECK_DEFAULTS=()
    ITHACA_CHECK_TIMEOUTS=()
    ITHACA_REGISTRY_LOCKED=0
    _ithaca_clear_error
}

_ithaca_registry_lock() {
    ITHACA_REGISTRY_LOCKED=1
}

register_check() {
    local check_id="${1:-}"
    local function_name="${2:-}"
    local category="${3:-}"
    local description="${4:-}"
    local default_enabled="${5:-yes}"
    local timeout_seconds="${6:-30}"

    _ithaca_clear_error

    (( ITHACA_REGISTRY_LOCKED == 0 )) ||
        _ithaca_set_error registry_locked "Il registro dei check e chiuso" || return 1

    [[ "$check_id" =~ ^[a-z][a-z0-9_-]*(\.[a-z][a-z0-9_-]*)+$ ]] ||
        _ithaca_set_error invalid_check_id "ID check non valido: $check_id" || return 1

    [[ "$function_name" =~ ^check_[a-z][a-z0-9_]*$ ]] ||
        _ithaca_set_error invalid_function_name "Funzione check non valida: $function_name" || return 1

    declare -F "$function_name" >/dev/null ||
        _ithaca_set_error undefined_function "Funzione non definita: $function_name" || return 1

    [[ "$category" =~ ^[a-z][a-z0-9_-]*$ ]] ||
        _ithaca_set_error invalid_category "Categoria non valida: $category" || return 1

    [[ -n "$description" ]] ||
        _ithaca_set_error empty_description "Descrizione check obbligatoria" || return 1

    [[ "$default_enabled" == "yes" || "$default_enabled" == "no" ]] ||
        _ithaca_set_error invalid_default "DEFAULT_ENABLED deve essere yes o no" || return 1

    [[ "$timeout_seconds" =~ ^[0-9]+$ ]] &&
        (( timeout_seconds >= 1 && timeout_seconds <= 3600 )) ||
        _ithaca_set_error invalid_timeout "Timeout non valido: $timeout_seconds" || return 1

    [[ ! -v "ITHACA_CHECK_FUNCTIONS[$check_id]" ]] ||
        _ithaca_set_error duplicate_check_id "ID check duplicato: $check_id" || return 1

    ITHACA_CHECK_IDS+=("$check_id")
    ITHACA_CHECK_FUNCTIONS["$check_id"]="$function_name"
    ITHACA_CHECK_CATEGORIES["$check_id"]="$category"
    ITHACA_CHECK_DESCRIPTIONS["$check_id"]="$description"
    ITHACA_CHECK_DEFAULTS["$check_id"]="$default_enabled"
    ITHACA_CHECK_TIMEOUTS["$check_id"]="$timeout_seconds"
}
