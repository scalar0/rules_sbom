<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Supply the Syft executable for the execution platform.

<a id="syft_toolchain"></a>

## syft_toolchain

<pre>
load("@rules_sbom//toolchains:toolchain.bzl", "syft_toolchain")

syft_toolchain(<a href="#syft_toolchain-name">name</a>, <a href="#syft_toolchain-syft">syft</a>)
</pre>

Supply a Syft executable.
Register it with the //toolchains:type toolchain type.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="syft_toolchain-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="syft_toolchain-syft"></a>syft |  Syft executable compatible with the rule's CLI and configuration controls.   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |


