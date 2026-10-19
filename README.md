# rules_sbom

Generate SBOMs from declared lockfiles with the Syft binary.

```starlark
load("@rules_sbom//:defs.bzl", "sbom")

sbom(
    name = "deps",
    lockfiles = ["Cargo.lock", "package-lock.json"],
    formats = ["syft-json", "spdx-json@3.0", "cyclonedx-json"],
    # config = "syft.yaml",
)
```

Add `rules_sbom` as a Bzlmod dependency.
The module registers its release toolchains.
The [independent example](examples/basic/MODULE.bazel) uses a local module override.

| Attribute        | Contract                                                                                |
| ---------------- | --------------------------------------------------------------------------------------- |
| `lockfiles`      | Required, nonempty list of labels. Each label supplies one file.                        |
| `formats`        | Required, nonempty list of native Syft formats. Version selectors are optional.         |
| `config`         | Optional Syft configuration file. Rule-owned settings take precedence.                  |
| `allow_network`  | Permit network enrichment from the configuration. The default is `False`.               |
| `cargo_licenses` | Optional list of validated Cargo license metadata labels. Each label supplies one file. |

Source files, generated files, and external repository files can supply lockfiles.
Each file must keep the filename that Syft recognizes.
The rule does not discover companion files or rename inputs.
Syft determines which formats and lockfiles it supports.
Template output is not supported because it requires an additional input.

One scan reads all declared lockfiles.
Without enrichment, Syft writes each requested format directly.
Each output path is `<target>/<format><extension>`.
For example, `spdx-json@3.0` produces `<target>/spdx-json@3.0.json`.

| Output encoding                | Extension |
| ------------------------------ | --------- |
| JSON                           | `.json`   |
| XML                            | `.xml`    |
| Text, tables, and package URLs | `.txt`    |
| SPDX tag-value                 | `.spdx`   |

Syft format aliases use the same extensions as their corresponding formats.
`DefaultInfo` contains all output files.
A standard output group selects one format:

```starlark
filegroup(
    name = "spdx",
    srcs = [":deps"],
    output_group = "spdx-json@3.0",
)
```

The document describes declared lockfile inventory.
It does not describe a Bazel target's resolved dependencies or binary contents.
Syft owns package identity, relationships, and output conversion.
Optional Cargo enrichment adds declared licenses without changing package IDs or relationships.
An empty inventory can succeed.
Native timestamps and identifiers can change between uncached builds.
The rule does not validate whole SPDX documents or normalize output documents.

## Cargo license enrichment

Register source lockfiles in `MODULE.bazel`:

```starlark
cargo = use_extension("@rules_sbom//:extensions.bzl", "cargo")
cargo.from_lockfiles(
    name = "cargo_licenses",
    lockfiles = ["//:Cargo.lock"],
)
use_repo(cargo, "cargo_licenses")
```

Supply the generated metadata target to `sbom`:

```starlark
sbom(
    name = "deps",
    lockfiles = ["Cargo.lock"],
    formats = ["spdx-json@3.0", "cyclonedx-json"],
    cargo_licenses = ["@cargo_licenses//:licenses"],
)
```

Repository setup downloads crates.io archives and verifies their Cargo.lock checksums.
Public HTTPS Git sources require host Git and use the locked commit.
Packages at the same Git commit share one source repository.
The extension requires source lockfiles with format version 3 or 4.
Generated lockfiles remain available for ordinary scans.
No step runs Cargo or reads a host Cargo cache.

One offline action extracts manifest declarations with Python's `tomllib` and validates them with `packaging`.
It resolves workspace inheritance from declared manifests.
It converts legacy Cargo slash separators to `OR` when necessary.
It keeps the original declaration and adds a canonical SPDX expression.
The SBOM action matches package name, version, source, and checksum.
It fills only missing licenses and keeps source evidence in native Syft license URLs.
Syft converts the enriched JSON into each requested format.
Each format determines which evidence fields it can retain.

| Condition                                                      | Behavior                               |
| -------------------------------------------------------------- | -------------------------------------- |
| Missing or invalid license expression                          | Warn and leave the license unresolved. |
| Local packages, alternate registries, or non-HTTPS Git sources | Warn and leave the license unresolved. |
| Custom license references or license-file-only declarations    | Warn and leave the license unresolved. |
| Download failure or checksum mismatch                          | Fail repository fetching.              |
| Malformed manifests or ambiguous package matches               | Fail metadata extraction.              |
| Conflicting metadata records                                   | Fail SBOM enrichment.                  |

The first version does not support private Git, Git submodules, or embedded license text.
Warnings describe unresolved packages in the scanned SBOM.
There is no separate diagnostics output.
The [enriched example](examples/basic/enriched/BUILD.bazel) shows standalone use.

## Configuration

The action copies declared files into a separate scan directory.
It preserves repository-relative paths under separate repository directories.
It does not copy adjacent workspace files.

The action always passes an explicit configuration file and ignores host configuration.
A supplied configuration can select catalogers, exclude inputs, and set document metadata.
The rule overrides source selection, scan paths, output paths, and local dependency-cache searches.
It also disables update checks, Syft caching, extra log files, profiles, and template paths.
User and temporary directories belong to the action.
By default, the rule disables network enrichment and requests Bazel network blocking where the execution strategy supports it.
Set `allow_network = True` to permit network enrichment from the configuration.
For example, enable `javascript.search-remote-licenses` or `python.search-remote-licenses` in the configuration to request registry license data.
The rule then requests network access and disables local and remote spawn caches.
Bazel can still reuse an unchanged action from its persistent action cache.
For a fresh lookup, build with a new value for `--define=RULES_SBOM_REFRESH_KEY=<value>`.
The rule includes this value in the online action environment.
Offline actions ignore this value.
Registry results can change between scans, and Syft can leave unavailable license data unresolved.

See the [toolchain API](docs/toolchains.md) and [design](DESIGN.md).
The [API index](docs/README.md) lists the generated reference pages.

## Compatibility

This API replaces `syft_lockfile`, `lockfile_sbom`, `spdx_check`, and their providers.
Replace scan-target labels with file labels in `sbom.lockfiles`.
Set the required `formats` list.
Replace custom document configuration with optional Syft configuration.
Replace provider access with standard output groups.

The module uses unmodified release binaries.
It does not retain the former Syft or SPDX patches.
The integration tests cover the Bazel contract, not every Syft parser.
