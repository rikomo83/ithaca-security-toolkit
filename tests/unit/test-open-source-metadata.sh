#!/usr/bin/env bash
set -u

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ITHACA_BASE_DIR="$(cd "$TEST_DIR/../.." && pwd -P)"

failures=0

for required_file in LICENSE README.md SECURITY.md CONTRIBUTING.md; do
    [[ -s "$ITHACA_BASE_DIR/$required_file" ]] || failures=$((failures + 1))
done

grep -Fq 'Apache License' "$ITHACA_BASE_DIR/LICENSE" ||
    failures=$((failures + 1))
grep -Fq 'Version 2.0, January 2004' "$ITHACA_BASE_DIR/LICENSE" ||
    failures=$((failures + 1))
grep -Fq 'Apache License 2.0' "$ITHACA_BASE_DIR/README.md" ||
    failures=$((failures + 1))
grep -Fq "private vulnerability reporting" "$ITHACA_BASE_DIR/SECURITY.md" ||
    failures=$((failures + 1))
grep -Fq 'config/ithaca.conf' "$ITHACA_BASE_DIR/CONTRIBUTING.md" ||
    failures=$((failures + 1))

if (( failures == 0 )); then
    printf 'ok 1 - metadati open source Apache 2.0 presenti\n'
    printf 'ok 2 - policy sicurezza e contributi documentate\n'
    printf '2 test superati\n'
    exit 0
fi

printf 'not ok 1 - metadati open source incompleti (%s errori)\n' \
    "$failures" >&2
exit 1
