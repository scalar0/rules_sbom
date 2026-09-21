"""Extract and validate Cargo licenses without network access."""

import json
import posixpath
import re
import sys
import tomllib
from pathlib import Path

from packaging.licenses import InvalidLicenseExpression, canonicalize_license_expression


def workspace(path, manifest, manifests):
    """Find the declared workspace without reading undeclared files."""
    directory = posixpath.dirname(path)
    explicit = manifest.get("package", {}).get("workspace")
    if explicit is not None:
        if not isinstance(explicit, str) or explicit.startswith("/") or "\\" in explicit:
            raise ValueError("The Cargo workspace path must be a relative path.")
        candidate = posixpath.normpath(posixpath.join(directory, explicit, "Cargo.toml"))
        if candidate.startswith("../"):
            raise ValueError("A Cargo workspace path escapes its source repository.")
        return candidate, manifests.get(candidate, {})
    while True:
        candidate = posixpath.join(directory, "Cargo.toml")
        data = manifests.get(candidate, {})
        if "workspace" in data:
            return candidate, data
        if not directory:
            return "", {}
        directory = posixpath.dirname(directory)


def field(package, name, workspace_manifest):
    """Resolve a package field or its workspace declaration."""
    value = package.get(name)
    if isinstance(value, dict) and value.get("workspace") is True:
        return workspace_manifest.get("workspace", {}).get("package", {}).get(name)
    return value


def extract(source, manifests):
    """Match one package and keep its declaration source."""
    record = dict(source["entry"], license=None, urls=[], reason="No matching package manifest.")
    if source["kind"] == "unsupported":
        record["reason"] = "Unsupported Cargo source or local package."
        return record
    matches = []
    for path, manifest in manifests.items():
        package = manifest.get("package", {})
        if package.get("name") != record["name"]:
            continue
        workspace_path, workspace_manifest = workspace(path, manifest, manifests)
        version = field(package, "version", workspace_manifest)
        if version is None and "version" not in package:
            version = "0.0.0"
        if version != record["version"]:
            continue
        matches.append(path)
        value = field(package, "license", workspace_manifest)
        if value is not None and not isinstance(value, str):
            raise ValueError(f"The Cargo license declaration must be a string: {path}")
        origin = workspace_path if isinstance(package.get("license"), dict) else path
        fragment = f'{source["commit"]}:{origin}' if source["kind"] == "git" else origin
        record.update(
            license=value,
            urls=[f'{source["url"]}#{fragment}'],
            reason="" if value else "No license expression in the package manifest.",
        )
    if len(matches) > 1:
        raise ValueError(f'Ambiguous Cargo package manifests for {record["name"]}@{record["version"]}: {matches}')
    return record


def validate(record):
    """Return a native Syft license or an unresolved reason."""
    result = {key: record[key] for key in ("name", "version", "source", "checksum", "reason")}
    if not all(isinstance(value, str) for value in result.values()):
        raise ValueError("Cargo package identity fields and reasons must be strings.")
    result["license"] = None
    value = record.get("license")
    if value is None or value == "":
        return result
    if not isinstance(value, str):
        raise ValueError("The license declaration must be a string.")
    if re.search(r"\b(?:DocumentRef|LicenseRef)-", value, re.IGNORECASE):
        result["reason"] = "Custom license references require definitions and are not supported."
        return result
    try:
        expression = canonicalize_license_expression(value)
    except InvalidLicenseExpression:
        try:
            expression = canonicalize_license_expression(value.replace("/", " OR "))
        except InvalidLicenseExpression:
            result["reason"] = "The license declaration is not a supported SPDX expression."
            return result
    result["license"] = dict(
        value=value, spdxExpression=str(expression), type="declared",
        urls=record["urls"], locations=[],
    )
    result["reason"] = ""
    return result


def build_metadata(data, directory):
    """Read each declared source once and produce validated metadata."""
    if data.get("schema_version") != 1 or not isinstance(data.get("sources"), list):
        raise ValueError("Unsupported Cargo source metadata structure.")
    cache = {}
    records = []
    for source in data["sources"]:
        if source["kind"] == "unsupported":
            manifests = {}
        else:
            root = source["root"]
            if root not in cache:
                cache[root] = {}
                for path in source["manifests"]:
                    with (directory / root / path).open("rb") as manifest:
                        cache[root][path] = tomllib.load(manifest)
            manifests = cache[root]
        records.append(validate(extract(source, manifests)))
    return {"schema_version": 2, "packages": records}


def main():
    source = Path(sys.argv[1])
    with source.open(encoding="utf-8") as stream:
        data = build_metadata(json.load(stream), source.parent)
    with open(sys.argv[2], "w", encoding="utf-8") as output:
        json.dump(data, output, sort_keys=True)
        output.write("\n")


if __name__ == "__main__":
    main()
