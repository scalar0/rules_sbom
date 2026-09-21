"""Test SBOM outputs with the declared jq toolchain."""

load("@bazel_skylib//lib:shell.bzl", "shell")
load("@jq.bzl//jq/toolchain:toolchain.bzl", "TOOLCHAIN_TYPE")

def _json_test_impl(ctx):
    jq = ctx.toolchains[TOOLCHAIN_TYPE].jqinfo.bin
    inputs = [jq, ctx.file.filter] + ctx.files.srcs
    runner = ctx.actions.declare_file(ctx.label.name + ".sh")
    paths = ['"$TEST_SRCDIR/$TEST_WORKSPACE"/' + shell.quote(file.short_path) for file in inputs]
    ctx.actions.write(
        runner,
        "#!/bin/bash\nset -euo pipefail\nexec " + paths[0] + " -e -s -f " + " ".join(paths[1:]) + "\n",
        is_executable = True,
    )
    return [DefaultInfo(executable = runner, runfiles = ctx.runfiles(files = inputs))]

json_test = rule(
    implementation = _json_test_impl,
    test = True,
    attrs = {
        "filter": attr.label(allow_single_file = [".jq"], mandatory = True),
        "srcs": attr.label_list(allow_files = True, mandatory = True),
    },
    toolchains = [TOOLCHAIN_TYPE],
)

def _jq_script_test_impl(ctx):
    jq = ctx.toolchains[TOOLCHAIN_TYPE].jqinfo.bin
    files = [ctx.file.script, jq] + ctx.files.data
    runner = ctx.actions.declare_file(ctx.label.name + ".sh")
    paths = ['"$TEST_SRCDIR/$TEST_WORKSPACE"/' + shell.quote(file.short_path) for file in files]
    ctx.actions.write(runner, "#!/bin/bash\nset -euo pipefail\nexec bash " + " ".join(paths) + "\n", is_executable = True)
    return [DefaultInfo(executable = runner, runfiles = ctx.runfiles(files = files))]

jq_script_test = rule(
    implementation = _jq_script_test_impl,
    test = True,
    attrs = {
        "data": attr.label_list(allow_files = True),
        "script": attr.label(allow_single_file = [".sh"], mandatory = True),
    },
    toolchains = [TOOLCHAIN_TYPE],
)

def _directory_impl(ctx):
    output = ctx.actions.declare_directory(ctx.label.name)
    ctx.actions.run_shell(outputs = [output], command = 'mkdir -p "$1"', arguments = [output.path])
    return [DefaultInfo(files = depset([output]))]

directory = rule(implementation = _directory_impl)

def _script_tool_impl(ctx):
    executable = ctx.actions.declare_file(ctx.label.name + ".sh")
    ctx.actions.symlink(output = executable, target_file = ctx.file.src, is_executable = True)
    return [DefaultInfo(executable = executable, runfiles = ctx.runfiles(files = ctx.files.data))]

script_tool = rule(
    implementation = _script_tool_impl,
    executable = True,
    attrs = {
        "data": attr.label_list(allow_files = True),
        "src": attr.label(allow_single_file = True),
    },
)
