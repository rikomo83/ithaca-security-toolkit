#!/usr/bin/env bash

log_info() {
    printf "%s INFO  %s\n" "$(date '+%F %T')" "$1"
}

log_warn() {
    printf "%s WARN  %s\n" "$(date '+%F %T')" "$1"
}

log_error() {
    printf "%s ERROR %s\n" "$(date '+%F %T')" "$1"
}
