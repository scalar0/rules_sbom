"""Check Cargo manifest extraction and SPDX validation without Bazel fetching."""

import tempfile
import tomllib
import unittest
from pathlib import Path

from private.validate_licenses import build_metadata, extract, validate


ENTRY = dict(
    name="example",
    version="1.0.0",
    source="git+https://example.invalid/repo#abc",
    checksum="",
)
SOURCE = dict(
    entry=ENTRY, kind="git", url="https://example.invalid/repo", commit="abc"
)


def declaration(value, reason=""):
    return dict(
        ENTRY,
        license=value,
        urls=["https://example.invalid/repo#abc:Cargo.toml"],
        reason=reason,
    )


class LicenseValidationTest(unittest.TestCase):
    def test_expressions(self):
        for value, expected in [
            ("MIT", "MIT"),
            ("mit OR Apache-2.0", "MIT OR Apache-2.0"),
            (
                "MIT AND (BSD-3-Clause OR Apache-2.0)",
                "MIT AND (BSD-3-Clause OR Apache-2.0)",
            ),
            (
                "GPL-2.0-only WITH Classpath-exception-2.0",
                "GPL-2.0-only WITH Classpath-exception-2.0",
            ),
            ("MIT/Apache-2.0", "MIT OR Apache-2.0"),
        ]:
            with self.subTest(value=value):
                result = validate(declaration(value))
                self.assertEqual(result["license"]["value"], value)
                self.assertEqual(result["license"]["spdxExpression"], expected)
                self.assertEqual(result["license"]["type"], "declared")
                self.assertEqual(result["reason"], "")

    def test_unresolved(self):
        for value in [
            "MIT OR",
            "unknown-license",
            "MIT WITH unknown-exception",
            "LicenseRef-custom",
        ]:
            with self.subTest(value=value):
                result = validate(declaration(value))
                self.assertIsNone(result["license"])
                self.assertTrue(result["reason"])

    def test_missing_license(self):
        result = validate(declaration(None, "No expression."))
        self.assertIsNone(result["license"])
        self.assertEqual(result["reason"], "No expression.")

    def test_malformed_declaration(self):
        with self.assertRaisesRegex(ValueError, "must be a string"):
            validate(declaration(0))


class ManifestExtractionTest(unittest.TestCase):
    def setUp(self):
        self.manifests = {
            "Cargo.toml": tomllib.loads(
                '[workspace.package]\nversion="1.0.0"\nlicense="MIT OR Apache-2.0"'
            ),
            "crates/example/Cargo.toml": tomllib.loads(
                '[package]\nname="example"\nversion.workspace=true\nlicense.workspace=true'
            ),
        }

    def test_workspace_inheritance_and_provenance(self):
        record = extract(SOURCE, self.manifests)
        self.assertEqual(record["license"], "MIT OR Apache-2.0")
        self.assertEqual(
            record["urls"], ["https://example.invalid/repo#abc:Cargo.toml"]
        )
        self.assertEqual(record["source"], ENTRY["source"])

    def test_explicit_workspace(self):
        root = self.manifests.pop("Cargo.toml")
        self.manifests["shared/Cargo.toml"] = root
        self.manifests["crates/example/Cargo.toml"]["package"]["workspace"] = (
            "../../shared"
        )
        record = extract(SOURCE, self.manifests)
        self.assertEqual(
            record["urls"],
            ["https://example.invalid/repo#abc:shared/Cargo.toml"],
        )

    def test_workspace_cannot_escape(self):
        self.manifests["crates/example/Cargo.toml"]["package"]["workspace"] = (
            "../../../outside"
        )
        with self.assertRaisesRegex(ValueError, "escapes"):
            extract(SOURCE, self.manifests)

    def test_ambiguous_package(self):
        self.manifests["duplicate/Cargo.toml"] = self.manifests[
            "crates/example/Cargo.toml"
        ]
        with self.assertRaisesRegex(
            ValueError, "Ambiguous Cargo package manifests"
        ):
            extract(SOURCE, self.manifests)

    def test_missing_workspace_or_wrong_version(self):
        for manifests in [
            {
                "crates/example/Cargo.toml": self.manifests[
                    "crates/example/Cargo.toml"
                ]
            },
            {
                "Cargo.toml": {
                    "package": dict(
                        name="example", version="2.0.0", license="MIT"
                    )
                }
            },
        ]:
            self.assertEqual(
                extract(SOURCE, manifests)["reason"],
                "No matching package manifest.",
            )

    def test_registry_manifest(self):
        manifest = tomllib.loads(
            '[package]\nname="example"\nversion="1.0.0"\nlicense="MIT"'
        )
        source = dict(
            SOURCE, kind="registry", url="https://example.invalid/example.crate"
        )
        result = validate(extract(source, {"Cargo.toml": manifest}))
        self.assertEqual(
            result["license"]["urls"],
            ["https://example.invalid/example.crate#Cargo.toml"],
        )

    def test_license_file_only(self):
        package = self.manifests["crates/example/Cargo.toml"]["package"]
        package.pop("license")
        package["license-file"] = "LICENSE"
        result = validate(extract(SOURCE, self.manifests))
        self.assertIsNone(result["license"])
        self.assertIn("No license expression", result["reason"])

    def test_malformed_manifest(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "Cargo.toml").write_text("[package\n", encoding="utf-8")
            source = dict(SOURCE, root=".", manifests=["Cargo.toml"])
            with self.assertRaises(tomllib.TOMLDecodeError):
                build_metadata({"schema_version": 1, "sources": [source]}, root)

    def test_unsupported_source(self):
        result = validate(extract(dict(SOURCE, kind="unsupported"), {}))
        self.assertIsNone(result["license"])
        self.assertIn("Unsupported", result["reason"])


if __name__ == "__main__":
    unittest.main()
