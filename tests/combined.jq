first(.[] | select(has("artifacts"))) as $syft |
first(.[] | select(has("@graph"))) as $spdx |
first(.[] | select(has("bomFormat"))) as $cyclonedx |
($syft.descriptor.version == "1.54.1") and
($syft.source.type == "directory") and
([$syft.artifacts[].name] | sort == ["example", "example", "fixture-dep"]) and
($spdx | has("@graph")) and
($cyclonedx.bomFormat == "CycloneDX") and
([$cyclonedx.components[] | select(.type == "library") | .name] | sort == ["example", "example", "fixture-dep"])
