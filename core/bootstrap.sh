#!/usr/bin/env bash

# Passive Core API 1 bootstrap. Sourcing this file does not run any check.
if [[ -z "${ITHACA_BASE_DIR:-}" ]]; then
    ITHACA_BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
fi

# shellcheck source=core/errors.sh
source "$ITHACA_BASE_DIR/core/errors.sh"
# shellcheck source=core/logger.sh
source "$ITHACA_BASE_DIR/core/logger.sh"
# shellcheck source=core/registry.sh
source "$ITHACA_BASE_DIR/core/registry.sh"
# shellcheck source=core/result.sh
source "$ITHACA_BASE_DIR/core/result.sh"

ITHACA_CORE_API="1"

ithaca_core_init() {
    _ithaca_registry_reset
    _ithaca_results_reset
}
