#!/usr/bin/env bash

ITHACA_SHADOW_ERROR=""

_ithaca_shadow_compare() {
    local expected_statuses_name="$1"
    local expected_messages_name="$2"
    local actual_statuses_name="$3"
    local actual_messages_name="$4"
    local -n expected_statuses="$expected_statuses_name"
    local -n expected_messages="$expected_messages_name"
    local -n actual_statuses="$actual_statuses_name"
    local -n actual_messages="$actual_messages_name"
    local index=0

    ITHACA_SHADOW_ERROR=""

    if (( ${#expected_statuses[@]} != ${#actual_statuses[@]} )); then
        ITHACA_SHADOW_ERROR="Numero risultati diverso: legacy=${#expected_statuses[@]} v12=${#actual_statuses[@]}"
        return 1
    fi

    for ((index = 0; index < ${#expected_statuses[@]}; index += 1)); do
        if [[ "${expected_statuses[$index]}" != "${actual_statuses[$index]}" ]]; then
            ITHACA_SHADOW_ERROR="Stato risultato $index diverso: legacy=${expected_statuses[$index]} v12=${actual_statuses[$index]}"
            return 1
        fi
        if [[ "${expected_messages[$index]}" != "${actual_messages[$index]}" ]]; then
            ITHACA_SHADOW_ERROR="Messaggio risultato $index diverso: legacy=${expected_messages[$index]} v12=${actual_messages[$index]}"
            return 1
        fi
    done
}
