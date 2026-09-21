#!/bin/bash
set -euo pipefail
jq=$1
filter=$2
metadata=$3
cd "$TEST_TMPDIR"

"$jq" -n --slurpfile metadata "$metadata" '
  $metadata[0].packages[0] as $package |
  {artifacts: [
    {id: "empty", name: $package.name, version: $package.version,
     type: "rust-crate", foundBy: "rust-cargo-lock-cataloger",
     metadataType: "rust-cargo-lock-entry", metadata: $package, licenses: []},
    {id: "existing", name: $package.name, version: $package.version,
     type: "rust-crate", foundBy: "rust-cargo-lock-cataloger",
     metadataType: "rust-cargo-lock-entry", metadata: $package,
     licenses: [{value: "BSD-2-Clause"}]},
    {id: "other", name: $package.name, version: $package.version,
     type: "npm", foundBy: "javascript-package-cataloger", licenses: []},
    {id: "missing", name: "missing", version: "1.0.0",
     type: "rust-crate", foundBy: "rust-cargo-lock-cataloger",
     metadataType: "rust-cargo-lock-entry",
     metadata: {name: "missing", version: "1.0.0", source: "git+https://missing#abc"}, licenses: []}
  ], artifactRelationships: [{parent: "existing", child: "empty", type: "dependency-of"}]}
' | "$jq" '.artifacts += [(.artifacts[3] | .id = "missing-copy")]' > input.json
"$jq" -s -f "$filter" input.json "$metadata" > output.json 2> warnings.txt
"$jq" -e -s '
  (.[0] | del(.artifacts[].licenses)) == (.[1] | del(.artifacts[].licenses)) and
  (.[1].artifacts[0].licenses[0].spdxExpression == "MIT OR Apache-2.0") and
  (.[1].artifacts[1].licenses == [{value: "BSD-2-Clause"}]) and
  (.[1].artifacts[2].licenses == []) and
  (.[1].artifacts[3].licenses == [])
' input.json output.json
"$jq" -e -R -s '(split("missing@1.0.0") | length == 2) and (contains("existing") | not)' warnings.txt

"$jq" -s -f "$filter" input.json "$metadata" "$metadata" > duplicate-output.json 2> /dev/null
"$jq" -e -s '.[0] == .[1]' output.json duplicate-output.json

"$jq" '.packages[0].license = null | .packages[0].reason = "Invalid declaration."' "$metadata" > invalid.json
"$jq" -s -f "$filter" input.json invalid.json > invalid-output.json 2> invalid-warnings.txt
"$jq" -e '.artifacts[0].licenses == []' invalid-output.json
"$jq" -e -R -s 'contains("Invalid declaration.")' invalid-warnings.txt

"$jq" '.packages[0].license.spdxExpression = "BSD-3-Clause"' "$metadata" > conflicting.json
if "$jq" -s -f "$filter" input.json "$metadata" conflicting.json > /dev/null 2> conflict.txt; then
    echo 'Conflicting evidence must fail.' >&2
    exit 1
fi
"$jq" -e -R -s 'contains("Conflicting Cargo license evidence")' conflict.txt

"$jq" '.schema_version = 99' "$metadata" > malformed.json
if "$jq" -s -f "$filter" input.json malformed.json > /dev/null 2> malformed.txt; then
    echo 'Unsupported metadata must fail.' >&2
    exit 1
fi
"$jq" -e -R -s 'contains("Unsupported Cargo license metadata")' malformed.txt
