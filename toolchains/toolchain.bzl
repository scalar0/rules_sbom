"""Supply the Syft executable for the execution platform."""

load("//private:releases.bzl", "SYFT_RELEASES")

def _syft_toolchain_impl(ctx):
    return [platform_common.ToolchainInfo(
        syft = ctx.executable.syft,
        files_to_run = ctx.attr.syft[DefaultInfo].files_to_run,
    )]

syft_toolchain = rule(
    implementation = _syft_toolchain_impl,
    attrs = {
        "syft": attr.label(
            executable = True,
            cfg = "exec",
            allow_single_file = True,
            mandatory = True,
            doc = "Syft executable compatible with the rule's CLI and configuration controls.",
        ),
    },
    doc = "Supply a Syft executable.\nRegister it with the //toolchains:type toolchain type.",
)

def release_toolchains(name):
    """Declare toolchains for the pinned release platforms.

    Args:
        name: Prefix for the toolchain targets.
    """
    for platform, release in SYFT_RELEASES.items():
        target = name + "_" + platform
        syft_toolchain(
            name = target + "_implementation",
            syft = "@syft_" + platform + "//:syft",
        )
        native.toolchain(
            name = target,
            toolchain = ":" + target + "_implementation",
            toolchain_type = ":type",
            exec_compatible_with = [
                "@platforms//os:" + release.os,
                "@platforms//cpu:" + release.cpu,
            ],
        )
