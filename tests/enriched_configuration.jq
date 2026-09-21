all(.[];
  [.artifacts[] | select(.name == "fixture-dep") | .licenses[0].spdxExpression] == ["MIT OR Apache-2.0"])
and (map(select(.source.name == "enriched-legacy")) | length == 1)
and (map(select(.source.name == "configured-inventory")) | length == 1)
