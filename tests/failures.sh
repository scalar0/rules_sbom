#!/bin/bash
set -euo pipefail

test_scratch=$(mktemp -d "${TMPDIR:-/tmp}/sbom-failures.XXXXXXXX")
trap 'rm -rf "$test_scratch"' EXIT

if bazel build //tests:unsupported_format "$@" > "$test_scratch/format.log" 2>&1; then
    echo 'The unsupported format must fail.' >&2
    exit 1
fi
if ! rg -q 'unsupported output format "not-a-syft-format"' "$test_scratch/format.log"; then
    cat "$test_scratch/format.log" >&2
    exit 1
fi

if bazel build --extra_toolchains=//tests:fake_toolchain //tests:failure "$@" > "$test_scratch/exit.log" 2>&1; then
    echo 'The custom tool failure must reach Bazel.' >&2
    exit 1
fi
if ! rg -q 'Exit 23' "$test_scratch/exit.log" || ! rg -q 'The test tool failed.' "$test_scratch/exit.log"; then
    cat "$test_scratch/exit.log" >&2
    exit 1
fi
