#!/usr/bin/env bash

_ithaca_prepare_text_report() {
    local target="${1:-}"
    local target_dir=""

    [[ -n "$target" ]] || return 1
    [[ ! -L "$target" ]] || return 1
    target_dir="$(dirname -- "$target")" || return 1
    [[ -d "$target_dir" ]] || return 1

    (umask 0027; : > "$target") || return 1
    chmod 0640 "$target"
}
