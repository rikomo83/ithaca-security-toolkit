#!/usr/bin/env bash
set -u

TEST_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
status=0
test_file=""

while IFS= read -r test_file; do
    bash "$test_file" || status=1
done < <(find "$TEST_ROOT/unit" -maxdepth 1 -type f -name 'test-*.sh' -print | LC_ALL=C sort)

exit "$status"
