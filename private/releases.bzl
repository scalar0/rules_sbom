"""Pinned release data for Syft repositories and execution platforms."""

SYFT_VERSION = "1.46.0"

SYFT_RELEASES = {
    "darwin_amd64": struct(os = "osx", cpu = "x86_64", sha256 = "5c983db13533de02e5331aae88091116f25365840741f86234084a30166672a7"),
    "darwin_arm64": struct(os = "osx", cpu = "aarch64", sha256 = "cd4e2c40e075684a5746d8959f76b6572bb2d2dda8cf6877dbfff1cc0baeea01"),
    "linux_amd64": struct(os = "linux", cpu = "x86_64", sha256 = "d654f678b709eb53c393d38519d5ed7d2e57205529404018614cfefa0fb2b5ca"),
    "linux_arm64": struct(os = "linux", cpu = "aarch64", sha256 = "9fafef4db4f032ce81008d3a1529985d41ceb6ccdf2b388c9ce2f1ed7d32082e"),
}
