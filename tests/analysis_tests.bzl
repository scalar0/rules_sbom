"""Check input contracts and execution platform selection."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("//:defs.bzl", "sbom")

def _failure_impl(ctx):
    env = analysistest.begin(ctx)
    asserts.expect_failure(env, ctx.attr.message)
    return analysistest.end(env)

_failure_test = analysistest.make(
    _failure_impl,
    expect_failure = True,
    attrs = {"message": attr.string()},
)

def _platform_impl(ctx):
    env = analysistest.begin(ctx)
    actions = [action for action in analysistest.target_actions(env) if action.mnemonic == "SbomScan"]
    asserts.equals(env, 1, len(actions))
    if actions:
        paths = [file.path for file in actions[0].inputs.to_list()]
        asserts.true(env, any(["syft_" + ctx.attr.platform + "/syft" in path for path in paths]), str(paths))
        asserts.false(env, any([path.endswith("/enrich.jq") or "jq_toolchains_" in path for path in paths]), str(paths))
    return analysistest.end(env)

_linux_amd64_test = analysistest.make(_platform_impl, attrs = {"platform": attr.string(default = "linux_amd64")}, config_settings = {"//command_line_option:extra_execution_platforms": ["//tests/platforms:linux_amd64"]})
_linux_arm64_test = analysistest.make(_platform_impl, attrs = {"platform": attr.string(default = "linux_arm64")}, config_settings = {"//command_line_option:extra_execution_platforms": ["//tests/platforms:linux_arm64"]})
_darwin_amd64_test = analysistest.make(_platform_impl, attrs = {"platform": attr.string(default = "darwin_amd64")}, config_settings = {"//command_line_option:extra_execution_platforms": ["//tests/platforms:darwin_amd64"]})
_darwin_arm64_test = analysistest.make(_platform_impl, attrs = {"platform": attr.string(default = "darwin_arm64")}, config_settings = {"//command_line_option:extra_execution_platforms": ["//tests/platforms:darwin_arm64"]})

def analysis_tests(name):
    """Declare failure cases and toolchain selection tests.

    Args:
        name: Name of the test suite.
    """
    tests = []
    cases = {
        "directory_input": ([":directory"], ["syft-json"], "one regular file"),
        "duplicate_formats": (["//tests/fixtures:Cargo.lock"], ["syft-json", "syft-json"], "Duplicate format"),
        "duplicate_inputs": (["//tests/fixtures:Cargo.lock", ":cargo_alias"], ["syft-json"], "Duplicate lockfile path"),
        "empty_formats": (["//tests/fixtures:Cargo.lock"], [], "Set formats to a nonempty list"),
        "empty_inputs": ([], ["syft-json"], "Set lockfiles to a nonempty list"),
        "multiple_files": ([":two_files"], ["syft-json"], "one regular file"),
        "template_format": (["//tests/fixtures:Cargo.lock"], ["template"], "Template output requires"),
        "unsafe_format": (["//tests/fixtures:Cargo.lock"], ["../outside"], "safe filename component"),
    }
    for case, (lockfiles, formats, message) in cases.items():
        sbom(name = case, lockfiles = lockfiles, formats = formats, tags = ["manual"])
        _failure_test(name = case + "_test", target_under_test = ":" + case, message = message)
        tests.append(":" + case + "_test")

    for platform, test in {
        "darwin_amd64": _darwin_amd64_test,
        "darwin_arm64": _darwin_arm64_test,
        "linux_amd64": _linux_amd64_test,
        "linux_arm64": _linux_arm64_test,
    }.items():
        test(name = platform + "_test", target_under_test = ":combined")
        tests.append(":" + platform + "_test")
    native.test_suite(name = name, tests = tests)
