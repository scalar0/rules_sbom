#!/usr/bin/env bash
# Check local configuration setup in temporary directories.
set -euo pipefail
project=$(cd -- "${BASH_SOURCE[0]%/*}/.." && pwd -P)
scratch=$(mktemp -d "${TMPDIR:-/tmp}/aspect-local-test-XXXXXXXX")
trap 'rm -rf -- "$scratch"' EXIT
original="$scratch/original checkout"
slot="$scratch/slot checkout"
mkdir -p "$original" "$slot" "$scratch/bin"
export LOCAL_TEST_ORIGINAL="$original" LOCAL_TEST_SLOT="$slot"
cat > "$scratch/bin/git" <<'SH'
#!/usr/bin/env bash
if [[ $1 == rev-parse ]]; then
    printf '%s\n' "$LOCAL_TEST_SLOT"
elif [[ $1 == worktree ]]; then
    printf 'worktree %s\0HEAD fixture\0\0' "$LOCAL_TEST_ORIGINAL"
else
    exit 99
fi
SH
chmod +x "$scratch/bin/git"
run_setup() { PATH="$scratch/bin:$PATH" bash "$project/tools/worktree-setup.bash"; }
expect_failure() {
    if "$@" > "$scratch/failure.log" 2>&1; then
        printf 'Expected a command failure: %s\n' "$*" >&2
        exit 1
    fi
}
# Optional source configuration can appear after setup.
run_setup
expected="try-import \"$original/user.bazelrc\""
[[ $(cat "$slot/user.bazelrc") == "$expected" ]]
run_setup
printf 'common --define=local=first\n' > "$original/user.bazelrc"
run_setup
printf 'common --define=local=second\n' > "$original/user.bazelrc"
[[ $(cat "$slot/user.bazelrc") == "$expected" ]]
printf 'custom configuration\n' > "$slot/user.bazelrc"
expect_failure run_setup
[[ $(cat "$slot/user.bazelrc") == 'custom configuration' ]]
rm "$slot/user.bazelrc"
printf 'common --override_module=fixture=../relative\n' > "$original/user.bazelrc"
expect_failure run_setup
[[ ! -e "$slot/user.bazelrc" ]]
printf 'common --override_module=fixture="%s"\n' "$original/module checkout" > "$original/user.bazelrc"
run_setup
LOCAL_TEST_SLOT="$original" run_setup

printf 'PASS: local setup.\n'
