first(.[] | select(any(.artifacts[].name; . == "external-dep"))) as $external |
first(.[] | select(any(.artifacts[].locations[].path; endswith("/generated/Cargo.lock")))) as $generated |
([$generated.artifacts[].name] | sort == ["example", "fixture-dep"]) and
([$generated.artifacts[].locations[].path] | all(endswith("/generated/Cargo.lock"))) and
([$external.artifacts[].name] | sort == ["example", "external-dep", "fixture-dep"]) and
([$external.artifacts[].locations[].path] | any(contains("external/"))) and
(map(select(.artifacts | length == 0)) | length == 2)
