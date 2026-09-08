#!/usr/bin/env bash

# Converts the human-readable Sentinel report into Core API 1 results.
ITHACA_LEGACY_SUMMARY_WARN=""
ITHACA_LEGACY_SUMMARY_CRIT=""
ITHACA_LEGACY_SUMMARY_SCORE=""
ITHACA_LEGACY_ADAPTER_MATCH=0

_ithaca_legacy_section_slug() {
    case "${1:-}" in
        SYSTEM)      printf '%s' system ;;
        FIREWALL)    printf '%s' firewall ;;
        FAIL2BAN)    printf '%s' fail2ban ;;
        SSH)         printf '%s' ssh ;;
        APACHE)      printf '%s' apache ;;
        TLS)         printf '%s' tls ;;
        POSTGRESQL)  printf '%s' postgres ;;
        GEOSERVER)   printf '%s' geoserver ;;
        "AZURE ARC") printf '%s' azurearc ;;
        CERTIFICATI) printf '%s' certs ;;
        *)           return 1 ;;
    esac
}

legacy_parse_report() {
    local report_file="${1:-}"
    local line=""
    local section="general"
    local next_section=""
    local message=""
    local status=""
    local check_id=""
    local sequence=0
    local parsed_warn=0
    local parsed_crit=0

    [[ -f "$report_file" ]] ||
        _ithaca_set_error legacy_report_missing "Report legacy non trovato: $report_file" || return 1

    ITHACA_LEGACY_SUMMARY_WARN=""
    ITHACA_LEGACY_SUMMARY_CRIT=""
    ITHACA_LEGACY_SUMMARY_SCORE=""
    ITHACA_LEGACY_ADAPTER_MATCH=0

    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%$'\r'}"

        if next_section="$(_ithaca_legacy_section_slug "$line" 2>/dev/null)"; then
            section="$next_section"
            continue
        fi

        case "$line" in
            "Warnings : "*) ITHACA_LEGACY_SUMMARY_WARN="${line#Warnings : }" ;;
            "Critical : "*) ITHACA_LEGACY_SUMMARY_CRIT="${line#Critical : }" ;;
            "Score    : "*)
                ITHACA_LEGACY_SUMMARY_SCORE="${line#Score    : }"
                ITHACA_LEGACY_SUMMARY_SCORE="${ITHACA_LEGACY_SUMMARY_SCORE%/100}"
                ;;
            "✓ "*) status="OK";       message="${line#✓ }" ;;
            "⚠ "*) status="WARN";     message="${line#⚠ }" ;;
            "✗ "*) status="CRITICAL"; message="${line#✗ }" ;;
            *) continue ;;
        esac

        [[ "$line" == "✓ "* || "$line" == "⚠ "* || "$line" == "✗ "* ]] || continue
        sequence=$((sequence + 1))
        check_id="$(printf 'legacy.%s.check%03d' "$section" "$sequence")"
        _ithaca_add_result "$status" "$check_id" "$message" "Imported from Sentinel output" || return 1
    done < "$report_file"

    [[ "$ITHACA_LEGACY_SUMMARY_WARN" =~ ^[0-9]+$ ]] ||
        _ithaca_set_error legacy_summary_missing "Conteggio Warnings non trovato" || return 1
    [[ "$ITHACA_LEGACY_SUMMARY_CRIT" =~ ^[0-9]+$ ]] ||
        _ithaca_set_error legacy_summary_missing "Conteggio Critical non trovato" || return 1
    [[ "$ITHACA_LEGACY_SUMMARY_SCORE" =~ ^[0-9]+$ ]] ||
        _ithaca_set_error legacy_summary_missing "Score non trovato" || return 1

    parsed_warn="$(_ithaca_result_count WARN)"
    parsed_crit="$(_ithaca_result_count CRITICAL)"

    if [[ "$parsed_warn" == "$ITHACA_LEGACY_SUMMARY_WARN" &&
          "$parsed_crit" == "$ITHACA_LEGACY_SUMMARY_CRIT" &&
          "$(_ithaca_legacy_score)" == "$ITHACA_LEGACY_SUMMARY_SCORE" ]]; then
        ITHACA_LEGACY_ADAPTER_MATCH=1
        return 0
    fi

    _ithaca_set_error legacy_parity_mismatch \
        "Parita legacy fallita: risultati WARN=$parsed_warn CRITICAL=$parsed_crit SCORE=$(_ithaca_legacy_score); riepilogo WARN=$ITHACA_LEGACY_SUMMARY_WARN CRITICAL=$ITHACA_LEGACY_SUMMARY_CRIT SCORE=$ITHACA_LEGACY_SUMMARY_SCORE"
}
