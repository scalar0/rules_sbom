"""Redirect production fetch declarations to local integration fixtures."""

load("@bazel_tools//tools/build_defs/repo:git.bzl", "git_repository")
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@rules_sbom//private:cargo.bzl", "cargo_metadata_repository", "declare_cargo_repositories")

def _impl(ctx):
    root = ctx.path(ctx.modules[0].tags.from_lockfiles[0].lockfiles[0]).dirname
    calls = []

    def archive(**kwargs):
        if kwargs["urls"] != ["https://static.crates.io/crates/registry-fixture/registry-fixture-1.0.0.crate"]:
            fail("Unexpected registry URL.")
        kwargs["urls"] = ["file://" + str(root.get_child("fixture.crate"))]
        http_archive(**kwargs)

    def git(**kwargs):
        if kwargs["remote"] != "https://example.invalid/fixture":
            fail("Unexpected Git remote.")
        if kwargs["init_submodules"]:
            fail("Submodules must stay disabled.")
        calls.append(kwargs["commit"])
        kwargs["remote"] = str(root.get_child("git"))
        git_repository(**kwargs)

    def metadata(**kwargs):
        if len(calls) != 1 or len(kwargs["git_lists"]) != 1:
            fail("Packages at the same Git commit must share one fetch.")
        cargo_metadata_repository(**kwargs)

    declare_cargo_repositories(ctx, archive = archive, git = git, metadata = metadata)
    return ctx.extension_metadata(reproducible = True)

fixtures = module_extension(
    implementation = _impl,
    tag_classes = {
        "from_lockfiles": tag_class(attrs = {
            "lockfiles": attr.label_list(mandatory = True),
            "name": attr.string(mandatory = True),
        }),
    },
)
