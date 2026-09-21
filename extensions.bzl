"""Download the pinned Syft release binaries."""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("//private:cargo.bzl", _cargo = "cargo")
load("//private:releases.bzl", "SYFT_RELEASES", "SYFT_VERSION")

cargo = _cargo

def _syft_impl(module_ctx):
    for platform, release in SYFT_RELEASES.items():
        http_archive(
            name = "syft_" + platform,
            urls = ["https://github.com/anchore/syft/releases/download/v{0}/syft_{0}_{1}.tar.gz".format(SYFT_VERSION, platform)],
            sha256 = release.sha256,
            build_file_content = 'exports_files(["syft"], visibility = ["//visibility:public"])\n',
        )
    return module_ctx.extension_metadata(reproducible = True)

syft = module_extension(
    implementation = _syft_impl,
    doc = "Download Syft 1.46.0 for Linux and macOS on x86_64 and arm64.",
)
