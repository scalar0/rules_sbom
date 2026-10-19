"""Pinned release data for Syft repositories and execution platforms."""

SYFT_VERSION = "1.54.1"

SYFT_RELEASES = {
    "darwin_amd64": struct(os = "osx", cpu = "x86_64"),
    "darwin_arm64": struct(os = "osx", cpu = "aarch64"),
    "linux_amd64": struct(os = "linux", cpu = "x86_64"),
    "linux_arm64": struct(os = "linux", cpu = "aarch64"),
}
