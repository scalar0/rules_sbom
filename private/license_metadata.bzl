"""Extract and validate Cargo licenses from declared manifests."""

def _license_metadata_impl(ctx):
    output = ctx.actions.declare_file(ctx.label.name + ".json")
    ctx.actions.run(
        executable = ctx.executable._validator,
        arguments = [ctx.file.src.path, output.path],
        inputs = [ctx.file.src] + ctx.files.manifests,
        tools = [ctx.attr._validator[DefaultInfo].files_to_run],
        outputs = [output],
        execution_requirements = {"block-network": "1"},
        mnemonic = "CargoLicenseValidation",
    )
    return [DefaultInfo(files = depset([output]))]

license_metadata = rule(
    implementation = _license_metadata_impl,
    attrs = {
        "manifests": attr.label_list(allow_files = ["Cargo.toml"]),
        "src": attr.label(allow_single_file = [".json"], mandatory = True),
        "_validator": attr.label(default = Label("//private:validate_licenses"), executable = True, cfg = "exec"),
    },
)
