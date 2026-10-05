"""Buildifier lint policy for this workspace."""

load("@aspect_rules_lint//lint:buildifier.bzl", "lint_buildifier_aspect")
load("@aspect_rules_lint//lint:lint_test.bzl", "lint_test")

buildifier = lint_buildifier_aspect(
    binary = Label("@buildifier_linux_amd64//file:buildifier"),
    args = ["-config=off", "-mode=check"],
)

buildifier_test = lint_test(aspect = buildifier)
