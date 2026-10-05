#!/usr/bin/env -S just --justfile

# Show the module development interface.
default:
    just --list


# Run module tests, toolchain overrides, failure cases, and repository tests.
[positional-arguments]
test *bazel_args:
    bazel test //tests/... "$@" --lockfile_mode=error
    SBOM_HOST_MARKER=must-not-leak SYFT_CONFIG=/outside/config.yaml bazel test --action_env=SBOM_HOST_MARKER --action_env=SYFT_CONFIG --extra_toolchains=//tests:fake_toolchain //tests:override_test "$@" --lockfile_mode=error
    bash tests/failures.sh "$@" --lockfile_mode=error
    # Repository tests create and change their entire workspace in a temporary directory.
    bash tests/repositories.sh "$@" --lockfile_mode=update

# Build the independent consumer.
[positional-arguments]
consumer *bazel_args:
    cd examples/basic && bazel mod deps --lockfile_mode=error
    cd examples/basic && bazel build //:sbom //:spdx //enriched:sbom "$@" --lockfile_mode=error

# Validate the module, consumer, and documentation.
# Requires Bazel, Aspect, Git, Bash, jq, rg, tar, and shasum.
[positional-arguments]
check *bazel_args:
    bazel mod deps --lockfile_mode=error
    just check-quick "$@"
    aspect lint "$@" --lockfile_mode=error
    just test "$@"
    just consumer "$@"
    just docs-check "$@"

# Check module and example build files through Git discovery and check host shell syntax.
[positional-arguments]
check-quick *bazel_args:
    bazel run //tools/format:format.check "$@" --lockfile_mode=error
    bazel test //validation:quick "$@" --lockfile_mode=error
    bash tools/check-shell.bash

# Generate module reference pages and update the checked-in files.
[positional-arguments]
docs *bazel_args:
    bazel build //docs:rules //docs:toolchains //docs:extensions "$@" --lockfile_mode=error
    for page in rules toolchains extensions; do cp "bazel-bin/docs/generated/$page.md" "docs/$page.md"; done

# Check module reference freshness through declared Bazel comparisons.
[positional-arguments]
docs-check *bazel_args:
    bazel test //docs:rules_test //docs:toolchains_test //docs:extensions_test "$@" --lockfile_mode=error
