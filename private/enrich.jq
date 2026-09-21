# Match Cargo source identities. Preserve all existing licenses and package IDs.
def identity:
  [.name, .version, (.source // ""), (.checksum // "")] | tojson;

def warning($artifact; $reason):
  ("rules_sbom: " + $artifact.name + "@" + $artifact.version
    + " [" + (if ($artifact.metadata.source // "") == "" then "local" else $artifact.metadata.source end) + "]: " + $reason + "\n")
  | stderr | empty;

def records:
  reduce .[] as $map ({};
    if $map.schema_version != 2 then
      error("Unsupported Cargo license metadata structure.")
    else
      reduce $map.packages[] as $record (. ;
        ($record | identity) as $key |
        if has($key) and .[$key] != $record then
          error("Conflicting Cargo license evidence: " + $key)
        else .[$key] = $record end)
    end);

def candidate:
  .type == "rust-crate" and .foundBy == "rust-cargo-lock-cataloger"
    and .metadataType == "rust-cargo-lock-entry"
    and ((.licenses // []) | length) == 0;

.[0] as $sbom | (.[1:] | records) as $licenses | $sbom |
([.artifacts[] | select(candidate)] | unique_by(.metadata | identity) | .[] |
  . as $artifact | ($licenses[(.metadata | identity)] // null) as $record |
  if $record == null then warning($artifact; "No declared license evidence matches this package.")
  elif $record.license == null then warning($artifact; $record.reason)
  else empty end),
(.artifacts |= map(
  if candidate then
    ($licenses[(.metadata | identity)] // null) as $record |
    if $record.license != null then
      .licenses = [$record.license]
    else . end
  else . end))
