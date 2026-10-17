#!/bin/bash
set -euo pipefail
module_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
fixture_root=$(mktemp -d "${TMPDIR:-/tmp}/rules-sbom-fetch.XXXXXXXX")
cleanup() {
    aspect shutdown --bazel-startup-flag="--output_base=$fixture_root/output" >/dev/null 2>&1 || true
    rm -rf "$fixture_root"
}
trap cleanup EXIT
assert_log() {
    if ! rg -i "$1" "$2" >/dev/null; then
        cat "$2" >&2
        exit 1
    fi
}
cd "$fixture_root"
mkdir -p archive/registry-fixture-1.0.0 git/member git/second
cat > archive/registry-fixture-1.0.0/Cargo.toml <<'EOF'
[package]
name = "registry-fixture"
version = "1.0.0"
license = "MIT"
EOF
tar -czf fixture.crate -C archive registry-fixture-1.0.0
checksum=$(shasum -a 256 fixture.crate)
checksum=${checksum%% *}
cat > git/Cargo.toml <<'EOF'
[workspace]
members = ["member", "second"]
[workspace.package]
version = "1.0.0"
license = "Apache-2.0"
EOF
for package in member second; do
    cat > "git/$package/Cargo.toml" <<EOF
[package]
name = "git-$package"
version.workspace = true
license.workspace = true
EOF
done
git -C git init -q
git -C git add .
git -C git -c user.name=Fixture -c user.email=fixture@example.invalid -c commit.gpgsign=false commit -qm locked
revision=$(git -C git rev-parse HEAD)
sed 's/Apache-2.0/BSD-3-Clause/' git/Cargo.toml > git/changed.toml
mv git/changed.toml git/Cargo.toml
git -C git add .
git -C git -c user.name=Fixture -c user.email=fixture@example.invalid -c commit.gpgsign=false commit -qm later
cat > Cargo.lock <<EOF
version = 4
[[package]]
name = "registry-fixture"
version = "1.0.0"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "$checksum"
[[package]]
name = "git-member"
version = "1.0.0"
source = "git+https://example.invalid/fixture?branch=main#$revision"
[[package]]
name = "git-second"
version = "1.0.0"
source = "git+https://example.invalid/fixture?branch=main#$revision"
EOF
cp "$module_root/tests/fetch_fixtures.bzl" fixtures.bzl
printf 'module(name = "cargo_fetch_fixture")\nbazel_dep(name = "rules_sbom", version = "0.1.0")\nlocal_path_override(module_name = "rules_sbom", path = %s)\n' \
    "$(jq -nr --arg path "$module_root" '$path | tojson')" > MODULE.bazel
cat >> MODULE.bazel <<'EOF'
fixture = use_extension("//:fixtures.bzl", "fixtures")
fixture.from_lockfiles(name = "licenses", lockfiles = ["//:Cargo.lock"])
use_repo(fixture, "licenses")
EOF
printf 'exports_files(["Cargo.lock"])\n' > BUILD.bazel
cp "$module_root/.bazelversion" .bazelversion
mkdir -p .aspect
cp "$module_root/examples/basic/.aspect/"*.axl .aspect/
aspect build --bazel-startup-flag="--output_base=$fixture_root/output" @licenses//:licenses --jobs=4 "$@"
output=$(aspect cquery --bazel-startup-flag="--output_base=$fixture_root/output" -- @licenses//:licenses --output=files "$@" 2>/dev/null)
jq -e --arg revision "$revision" '
  (.packages | length == 3) and
  ([.packages[] | select(.name | startswith("git-")) | .license.spdxExpression] == ["Apache-2.0", "Apache-2.0"]) and
  ([.packages[] | select(.name == "registry-fixture") | .license.spdxExpression] == ["MIT"]) and
  ([.packages[] | select(.name | startswith("git-")) | .source | endswith($revision)] | all)
' "$output"

sed "s/$checksum/$(printf '%064d' 0)/" Cargo.lock > changed.lock
mv changed.lock Cargo.lock
if aspect build --bazel-startup-flag="--output_base=$fixture_root/output" @licenses//:licenses --jobs=4 "$@" > checksum.log 2>&1; then
    echo 'An archive checksum mismatch must fail.' >&2
    exit 1
fi
assert_log 'checksum|sha256' checksum.log

sed "s/$(printf '%064d' 0)/$(printf '%064d' 1)/" Cargo.lock > changed.lock
mv changed.lock Cargo.lock
mv fixture.crate unavailable.crate
if aspect build --bazel-startup-flag="--output_base=$fixture_root/output" @licenses//:licenses --jobs=4 "$@" > unavailable.log 2>&1; then
    echo 'An unavailable source archive must fail.' >&2
    exit 1
fi
assert_log 'no such file|not found|FileNotFoundException|Error downloading' unavailable.log

mv unavailable.crate fixture.crate
sed "s/$(printf '%064d' 1)/$checksum/" Cargo.lock > changed.lock
mv changed.lock Cargo.lock
sed "s/$revision/cccccccccccccccccccccccccccccccccccccccc/g" Cargo.lock > changed.lock
mv changed.lock Cargo.lock
if aspect build --bazel-startup-flag="--output_base=$fixture_root/output" @licenses//:licenses --jobs=4 "$@" > missing-commit.log 2>&1; then
    echo 'An unavailable locked Git commit must fail.' >&2
    exit 1
fi
assert_log 'git fetch|not our ref|couldn.t find remote ref|Could not parse object' missing-commit.log
