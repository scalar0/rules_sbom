<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Generate native Syft documents from declared lockfiles.

<a id="sbom"></a>

## sbom

<pre>
load("@rules_sbom//:defs.bzl", "sbom")

sbom(<a href="#sbom-name">name</a>, <a href="#sbom-cargo_licenses">cargo_licenses</a>, <a href="#sbom-config">config</a>, <a href="#sbom-formats">formats</a>, <a href="#sbom-lockfiles">lockfiles</a>)
</pre>

Scan declared lockfiles together.
Return native files through DefaultInfo and one output group per format.

**ATTRIBUTES**

| Name                                           | Description                                                                                          | Type                                                                | Mandatory | Default |
| :--------------------------------------------- | :--------------------------------------------------------------------------------------------------- | :------------------------------------------------------------------ | :-------- | :------ |
| <a id="sbom-name"></a>name                     | A unique name for this target.                                                                       | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required  |         |
| <a id="sbom-cargo_licenses"></a>cargo_licenses | Optional validated Cargo license metadata labels. A nonempty list enables offline enrichment.        | <a href="https://bazel.build/concepts/labels">List of labels</a>    | optional  | `[]`    |
| <a id="sbom-config"></a>config                 | Optional Syft configuration with lower priority than rule-owned input, output, and offline settings. | <a href="https://bazel.build/concepts/labels">Label</a>             | optional  | `None`  |
| <a id="sbom-formats"></a>formats               | Nonempty list of native Syft formats, such as syft-json or spdx-json@3.0.                            | List of strings                                                     | required  |         |
| <a id="sbom-lockfiles"></a>lockfiles           | Nonempty list of file labels with one lockfile per label.                                            | <a href="https://bazel.build/concepts/labels">List of labels</a>    | required  |         |
