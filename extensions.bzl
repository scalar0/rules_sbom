"""Download the pinned Syft release binaries."""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("//private:cargo.bzl", _cargo = "cargo")
load("//private:releases.bzl", "SYFT_RELEASES", "SYFT_VERSION")

cargo = _cargo

def _syft_impl(module_ctx):
    for platform in SYFT_RELEASES:
        http_archive(
            name = "syft_" + platform,
            urls = [
                "https://github.com/anchore/syft/releases/download/v{0}/syft_{0}_{1}.tar.gz".format(
                    SYFT_VERSION,
                    platform,
                ),
            ],
            build_file_content = 'exports_files(["syft"], visibility = ["//visibility:public"])\n',
        )
    return module_ctx.extension_metadata(reproducible = True)

syft = module_extension(
    implementation = _syft_impl,
    doc = "Download Syft {} for Linux and macOS on x86_64 and arm64.".format(SYFT_VERSION),
)
