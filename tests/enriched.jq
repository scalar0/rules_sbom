map(select(has("artifacts")))[0] as $syft |
map(select(has("components")))[0] as $cdx |
map(select(has("@graph")))[0] as $spdx |
([$syft.artifacts[] | select((.metadata.source // "") | startswith("registry+")) | .licenses[0].spdxExpression] == ["MIT OR Apache-2.0"]) and
([$syft.artifacts[] | select((.metadata.source // "") | startswith("git+")) | .licenses[0].spdxExpression] == ["GPL-2.0-only WITH Classpath-exception-2.0"]) and
([$syft.artifacts[] | select(.name == "fixture-dep") | .licenses[0].type] == ["declared", "declared"]) and
([$syft.artifacts[] | select(.name == "fixture-dep") | .licenses[0].urls[]] | length == 2) and
([$cdx.components[] | .licenses[]? | .expression // .license.id] | index("MIT OR Apache-2.0") != null) and
([$spdx."@graph"[] | select(.type == "expandedlicensing_DisjunctiveLicenseSet") | .expandedlicensing_member | length] == [2]) and
([$spdx."@graph"[] | select(.type == "expandedlicensing_WithAdditionOperator")] | length == 1)
