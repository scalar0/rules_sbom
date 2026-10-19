<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Download the pinned Syft release binaries.

<a id="cargo"></a>

## cargo

<pre>
cargo = use_extension("@rules_sbom//:extensions.bzl", "cargo")
cargo.from_lockfiles(<a href="#cargo.from_lockfiles-name">name</a>, <a href="#cargo.from_lockfiles-lockfiles">lockfiles</a>)
</pre>

Fetch crates.io and public HTTPS Git license evidence from source Cargo.lock files.


**TAG CLASSES**

<a id="cargo.from_lockfiles"></a>

### from_lockfiles

**Attributes**

| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="cargo.from_lockfiles-name"></a>name |  Name of the generated license metadata repository.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="cargo.from_lockfiles-lockfiles"></a>lockfiles |  Source Cargo.lock files. Generated files are not supported.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | required |  |


<a id="syft"></a>

## syft

<pre>
syft = use_extension("@rules_sbom//:extensions.bzl", "syft")
</pre>

Download Syft 1.54.1 for Linux and macOS on x86_64 and arm64.



