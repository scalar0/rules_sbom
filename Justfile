#!/usr/bin/env -S just --justfile

# Show the module development interface.
default:
    just --list

# Format Starlark and Markdown sources.
fmt:
    rg --files -g '*.bzl' -g BUILD.bazel -g MODULE.bazel -0 | xargs -0 buildifier
    prettier --write --prose-wrap preserve '*.md' 'docs/README.md'

# Run the module integration and analysis tests. Optional arguments pass to Bazel.
test *bazel_args:
    bazel test //tests/... {{bazel_args}}
    env SBOM_HOST_MARKER=must-not-leak SYFT_CONFIG=/outside/config.yaml bazel test --action_env=SBOM_HOST_MARKER --action_env=SYFT_CONFIG --extra_toolchains=//tests:fake_toolchain //tests:override_test {{bazel_args}}
    bash tests/failures.sh {{bazel_args}}
    # Repository fetching needs a separate fixture module before analysis.
    bash tests/repositories.sh {{bazel_args}}

# Build the independent consumer. Optional arguments pass to Bazel.
consumer *bazel_args:
    cd examples/basic && bazel build //:sbom //:spdx //enriched:sbom {{bazel_args}}

# Check Starlark formatting and module dependency consistency.
check:
    rg --files -g '*.bzl' -g BUILD.bazel -g MODULE.bazel -0 | xargs -0 buildifier -mode=check -lint=warn
    bazel mod deps --lockfile_mode=error

# Generate API pages. Optional arguments pass to Bazel.
# If GCC cannot find its linker, pass --host_linkopt=-B/path/to/linker-directory.
docs *bazel_args:
    bazel build //docs:all {{bazel_args}}
    for page in rules toolchains extensions; do cp "bazel-bin/docs/generated/$page.md" "docs/$page.md"; done

# Check API page freshness. Optional arguments pass to Bazel.
docs-check *bazel_args:
    bazel build //docs:all {{bazel_args}}
    for page in rules toolchains extensions; do cmp "bazel-bin/docs/generated/$page.md" "docs/$page.md" || exit 1; done
