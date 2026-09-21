"""Scan declared lockfiles with the Syft executable."""

load("@jq.bzl//jq/toolchain:toolchain.bzl", "TOOLCHAIN_TYPE")
load(":settings.bzl", "FORMAT_EXTENSIONS", "SYFT_ENV")

_TOOLCHAIN = "//toolchains:type"
_FORMAT_CHARS = "abcdefghijklmnopqrstuvwxyz0123456789-_.@"

def _scan_path(file):
    path = file.short_path
    if path.startswith("../"):
        path = "external/" + path[3:]
    else:
        path = "main/" + path
    if any([part in ["", ".", ".."] for part in path.split("/")]):
        fail("The lockfile path must stay inside its repository: " + file.short_path)
    return path

def _sbom_impl(ctx):
    if not ctx.attr.lockfiles:
        fail("Set lockfiles to a nonempty list of file labels.")
    if not ctx.attr.formats:
        fail("Set formats to a nonempty list of Syft formats.")

    inputs = []
    paths = {}
    for target in ctx.attr.lockfiles:
        files = target[DefaultInfo].files.to_list()
        if len(files) != 1 or files[0].is_directory:
            fail("Each lockfile label must supply one regular file: " + str(target.label))
        file = files[0]
        path = _scan_path(file)
        if path in paths:
            fail("Duplicate lockfile path: " + path)
        paths[path] = file
        inputs.append(file)

    outputs = {}
    for format in ctx.attr.formats:
        if not format or format in [".", ".."] or any([char not in _FORMAT_CHARS for char in format.elems()]):
            fail("Each format must be a safe filename component: " + repr(format))
        if format.split("@")[0] == "template":
            fail("Template output requires an additional input and is not supported.")
        if format in outputs:
            fail("Duplicate format: " + format)
        format_name = format.split("@")[0].replace("-", "").replace("_", "")
        extension = FORMAT_EXTENSIONS.get(format_name, "")
        outputs[format] = ctx.actions.declare_file(ctx.label.name + "/" + format + extension)

    config = ctx.file.config
    if config == None:
        config = ctx.actions.declare_file(ctx.label.name + ".syft.yaml")
        ctx.actions.write(config, "{}\n")

    toolchain = ctx.toolchains[_TOOLCHAIN]
    metadata = []
    for target in ctx.attr.cargo_licenses:
        files = target[DefaultInfo].files.to_list()
        if len(files) != 1 or files[0].is_directory:
            fail("Each cargo_licenses label must supply one metadata file: " + str(target.label))
        metadata.append(files[0])
    args = ctx.actions.args()
    args.add(toolchain.syft)
    args.add(config)
    args.add(len(metadata))
    enrichment_inputs = []
    if metadata:
        jq = ctx.toolchains[TOOLCHAIN_TYPE].jqinfo.bin
        args.add(jq)
        args.add(ctx.file._enrich)
        args.add_all(metadata)
        enrichment_inputs = metadata + [jq, ctx.file._enrich]
    args.add(len(paths))
    for path, file in paths.items():
        args.add(file)
        args.add(path)
    for format, output in outputs.items():
        args.add(format)
        args.add(output)

    ctx.actions.run(
        executable = ctx.file._runner,
        arguments = [args],
        inputs = inputs + enrichment_inputs + [config, toolchain.syft],
        tools = [toolchain.files_to_run],
        outputs = outputs.values(),
        env = SYFT_ENV,
        use_default_shell_env = False,
        execution_requirements = {"block-network": "1"},
        mnemonic = "SbomScan",
        progress_message = "Scan lockfiles for %{label}",
    )
    return [
        DefaultInfo(files = depset(outputs.values())),
        OutputGroupInfo(**{format: depset([file]) for format, file in outputs.items()}),
    ]

sbom = rule(
    implementation = _sbom_impl,
    attrs = {
        "cargo_licenses": attr.label_list(allow_files = [".json"], doc = "Optional validated Cargo license metadata labels. A nonempty list enables offline enrichment."),
        "config": attr.label(allow_single_file = True, doc = "Optional Syft configuration with lower priority than rule-owned input, output, and offline settings."),
        "formats": attr.string_list(mandatory = True, doc = "Nonempty list of native Syft formats, such as syft-json or spdx-json@3.0."),
        "lockfiles": attr.label_list(allow_files = True, mandatory = True, doc = "Nonempty list of file labels with one lockfile per label."),
        "_enrich": attr.label(default = Label("//private:enrich.jq"), allow_single_file = True),
        "_runner": attr.label(default = Label("//private:scan.sh"), allow_single_file = True),
    },
    toolchains = [_TOOLCHAIN, TOOLCHAIN_TYPE],
    doc = "Scan declared lockfiles together.\nReturn native files through DefaultInfo and one output group per format.",
)
