#!/usr/bin/env bash
# Check the shell sources used by local validation.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
for file in private/*.sh tests/*.sh tools/*.bash; do
    bash -n "$file"
done
