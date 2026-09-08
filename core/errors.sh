#!/usr/bin/env bash

# Internal error state for Core API 1. This file is passive until sourced.
ITHACA_ERROR_CODE=""
ITHACA_ERROR_MESSAGE=""

_ithaca_set_error() {
    ITHACA_ERROR_CODE="${1:-internal}"
    ITHACA_ERROR_MESSAGE="${2:-Errore interno}"
    return 1
}

_ithaca_clear_error() {
    ITHACA_ERROR_CODE=""
    ITHACA_ERROR_MESSAGE=""
}
