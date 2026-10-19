#!/usr/bin/env -S just --justfile

# Show the module development interface.
default:
    just --list

# Run module tests, toolchain overrides, failure cases, and repository tests.
[positional-arguments]
test *bazel_args:
    aspect test //tests/... "$@"
    SBOM_HOST_MARKER=must-not-leak SYFT_CONFIG=/outside/config.yaml aspect test --action_env=SBOM_HOST_MARKER --action_env=SYFT_CONFIG --extra_toolchains=//tests:fake_toolchain //tests:override_test "$@"
    SBOM_HOST_MARKER=must-not-leak SYFT_CONFIG=/outside/config.yaml aspect test --action_env=SBOM_HOST_MARKER --action_env=SYFT_CONFIG --extra_toolchains=//tests:fake_toolchain --define=RULES_SBOM_REFRESH_KEY=test-refresh //tests:online_override_test "$@"
    bash tests/failures.sh "$@"
    # Repository tests create and change their entire workspace in a temporary directory.
    bash tests/repositories.sh "$@" --lockfile_mode=update

# Build the independent consumer.
[positional-arguments]
consumer *bazel_args:
    cd examples/basic && aspect mod -- deps
    cd examples/basic && aspect build //:sbom //:spdx //enriched:sbom "$@"

# Validate the module, consumer, and documentation.
# Requires Bazel, Aspect, Git, Bash, jq, rg, tar, and shasum.
[positional-arguments]
check *bazel_args:
    aspect mod -- deps
    just check-quick "$@"
    aspect lint "$@"
    just test "$@"
    just consumer "$@"
    just docs-check "$@"

# Check module and example build files through Git discovery and check host shell syntax.
[positional-arguments]
check-quick *bazel_args:
    bash tools/local.test.bash
    aspect run //tools/format:format.check "$@"
    aspect test //validation:quick "$@"
    bash tools/check-shell.bash

# Generate module reference pages and update the checked-in files.
[positional-arguments]
docs *bazel_args:
    aspect build //docs:rules //docs:toolchains //docs:extensions "$@"
    for page in rules toolchains extensions; do cp "bazel-bin/docs/generated/$page.md" "docs/$page.md"; done

# Check module reference freshness through declared Bazel comparisons.
[positional-arguments]
docs-check *bazel_args:
    aspect test //docs:rules_test //docs:toolchains_test //docs:extensions_test "$@"

# Import the original checkout's local settings after Aspect creates a worktree.
# Keep module paths absolute in the original user.bazelrc.
# Existing different configurations stop setup without changes.
[doc("Import local settings from the original checkout after worktree creation.")]
worktree-setup:
    bash tools/worktree-setup.bash

# Run full validation.
[positional-arguments]
check-full *bazel_args:
    just check "$@"

# Format source files selected by Aspect's change detection.
[positional-arguments]
fmt *args:
    aspect format-sources "$@"

# Format all configured source files.
fmt-all:
    aspect format-sources --scope=all

# Check every configured source format without changes.
[positional-arguments]
fmt-check *args:
    aspect format-check "$@"
