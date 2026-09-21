"""Supply local source evidence for offline integration tests."""

load("//private:cargo.bzl", "cargo_metadata_repository")

def _fixtures_impl(ctx):
    cargo_metadata_repository(
        name = "cargo_fixture_licenses",
        registry_manifests = ["//tests/sources/registry:Cargo.toml"],
        git_lists = ["//tests/sources/git:manifests"],
        entries = json.encode([
            {
                "entry": {
                    "checksum": "a" * 64,
                    "name": "fixture-dep",
                    "source": "registry+https://github.com/rust-lang/crates.io-index",
                    "version": "2.0.0",
                },
                "index": 0,
                "kind": "registry",
                "url": "https://static.crates.io/crates/fixture-dep/fixture-dep-2.0.0.crate",
            },
            {
                "commit": "b" * 40,
                "entry": {
                    "checksum": "",
                    "name": "fixture-dep",
                    "source": "git+https://example.invalid/source?branch=main#" + "b" * 40,
                    "version": "2.0.0",
                },
                "index": 0,
                "kind": "git",
                "url": "https://example.invalid/source",
            },
        ]),
    )
    return ctx.extension_metadata(reproducible = True)

fixtures = module_extension(implementation = _fixtures_impl)
