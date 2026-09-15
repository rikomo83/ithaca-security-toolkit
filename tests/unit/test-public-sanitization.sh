#!/usr/bin/env bash
set -u

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
BASE_DIR="$(cd "$TEST_DIR/../.." && pwd -P)"
failures=0
unexpected_ipv4=""

[[ -f "$BASE_DIR/config/ithaca.conf.example" ]] || failures=$((failures + 1))
grep -Fxq 'config/ithaca.conf' "$BASE_DIR/.gitignore" || failures=$((failures + 1))

if git -C "$BASE_DIR" ls-files --error-unmatch config/ithaca.conf >/dev/null 2>&1; then
    failures=$((failures + 1))
fi

unexpected_ipv4="$(
    git -C "$BASE_DIR" grep -IE \
        '(^|[^0-9])([0-9]{1,3}\.){3}[0-9]{1,3}([^0-9]|$)' \
        -- . ':(exclude)tests/unit/test-public-sanitization.sh' 2>/dev/null |
        grep -Ev '127\.0\.0\.1|0\.0\.0\.0' || true
)"

if [[ -n "$unexpected_ipv4" ]]; then
    failures=$((failures + 1))
fi

if (( failures == 0 )); then
    printf 'ok 1 - repository privo di configurazione produttiva\n'
    printf '1 test superato\n'
    exit 0
fi

printf 'not ok 1 - riferimenti produttivi presenti nel repository\n' >&2
exit 1
