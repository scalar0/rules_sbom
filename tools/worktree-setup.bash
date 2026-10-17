#!/usr/bin/env bash
# Import the original checkout's local configuration into this worktree.
set -euo pipefail
root=$(git rev-parse --show-toplevel)
IFS= read -r -d '' first < <(git worktree list --porcelain -z)
original=${first#worktree }
[[ "$root" != "$original" ]] || exit 0
source_rc="$original/user.bazelrc"
if [[ -f "$source_rc" ]]; then
    while IFS= read -r line; do
        [[ "$line" == *--override_module=* ]] || continue
        value=${line#*--override_module=}
        path=${value#*=}
        path=${path#\"}
        path=${path%\"}
        if [[ "$path" != /* ]]; then
            printf 'Use an absolute module path in %s: %s\n' "$source_rc" "$line" >&2
            exit 1
        fi
    done < "$source_rc"
fi
expected="try-import \"$source_rc\""
destination="$root/user.bazelrc"
if [[ -e "$destination" || -L "$destination" ]]; then
    if [[ ! -L "$destination" ]] && [[ $(cat "$destination") == "$expected" ]]; then
        exit 0
    fi
    printf 'Local configuration already exists: %s\n' "$destination" >&2
    exit 1
fi
# Noclobber preserves a configuration another process creates during setup.
(set -o noclobber; printf '%s\n' "$expected" > "$destination")
printf 'Imported local configuration from %s.\n' "$source_rc"
