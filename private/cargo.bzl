"""Fetch Cargo license evidence before build actions."""

load("@bazel_tools//tools/build_defs/repo:git.bzl", "git_repository")
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@toml.bzl", "toml")

_CRATES_IO = [
    "registry+https://github.com/rust-lang/crates.io-index",
    "sparse+https://index.crates.io/",
    "registry+https://index.crates.io/",
]

def _identity(entry):
    return [entry["name"], entry["version"], entry.get("source", ""), entry.get("checksum", "")]

def _metadata_impl(ctx):
    sources = json.decode(ctx.attr.entries)
    staged = {}
    for source in sources:
        kind = source["kind"]
        if kind == "unsupported":
            continue
        index = source["index"]
        key = kind + "_" + str(index)
        if key not in staged:
            label = ctx.attr.registry_manifests[index] if kind == "registry" else ctx.attr.git_lists[index]
            root = ctx.path(label).dirname
            paths = ["Cargo.toml"] if kind == "registry" else sorted([p for p in ctx.read(label).split("\000") if p])
            for path in paths:
                file = root.get_child(path)
                if path.startswith("/") or ".." in path.split("/") or not str(file.realpath).startswith(str(root.realpath) + "/"):
                    fail("A Cargo manifest escapes its source repository: " + path)
                ctx.symlink(file, "sources/" + key + "/" + path)
            staged[key] = paths
        source["root"] = "sources/" + key
        source["manifests"] = staged[key]
    ctx.file("sources.json", json.encode({"schema_version": 1, "sources": sources}))
    ctx.file("BUILD.bazel", """load("@rules_sbom//private:license_metadata.bzl", "license_metadata")
license_metadata(
    name = "licenses",
    src = "sources.json",
    manifests = glob(["sources/**/Cargo.toml"], allow_empty = True),
    visibility = ["//visibility:public"],
)
""")

cargo_metadata_repository = repository_rule(
    implementation = _metadata_impl,
    attrs = {
        "entries": attr.string(mandatory = True),
        "git_lists": attr.label_list(),
        "registry_manifests": attr.label_list(),
    },
)

def _hex(value, length):
    return len(value) == length and all([c in "0123456789abcdef" for c in value.elems()])

def declare_cargo_repositories(ctx, archive = http_archive, git = git_repository, metadata = cargo_metadata_repository):
    """Declare source repositories through the supplied Bazel repository rules.

    Args:
        ctx: Module extension context.
        archive: Archive repository rule.
        git: Git repository rule.
        metadata: License evidence repository rule.
    """
    for mod in ctx.modules:
        for tag in mod.tags.from_lockfiles:
            if not tag.lockfiles:
                fail("Set lockfiles to a nonempty list of source Cargo.lock labels.")
            unique = {}
            for lockfile in tag.lockfiles:
                data = toml.decode(ctx.read(lockfile))
                if data.get("version") not in [3, 4]:
                    fail("Cargo license enrichment requires lockfile version 3 or 4.")
                for package in data.get("package", []):
                    key = _identity(package)
                    if any([type(value) != "string" for value in key]):
                        fail("Cargo package identity fields must be strings.")
                    unique[json.encode(key)] = dict(zip(["name", "version", "source", "checksum"], key))
            entries = []
            registry_manifests = []
            git_lists = []
            git_sources = {}
            for index, key in enumerate(sorted(unique)):
                entry = unique[key]
                source = entry["source"]
                name = tag.name + "_source_" + str(index)
                if source in _CRATES_IO:
                    if not _hex(entry["checksum"], 64):
                        fail("A crates.io package requires a SHA-256 checksum: " + key)
                    if any([c in entry["name"] + entry["version"] for c in ["/", "\\", "\n"]]):
                        fail("Invalid Cargo package name or version: " + key)
                    archive_name = entry["name"] + "-" + entry["version"]
                    url = "https://static.crates.io/crates/{}/{}.crate".format(entry["name"], archive_name)
                    archive(
                        name = name,
                        urls = [url],
                        sha256 = entry["checksum"],
                        type = "tar.gz",
                        strip_prefix = archive_name,
                        build_file_content = 'exports_files(["Cargo.toml"], visibility = ["//visibility:public"])\n',
                    )
                    entries.append(dict(entry = entry, kind = "registry", index = len(registry_manifests), url = url))
                    registry_manifests.append("@" + name + "//:Cargo.toml")
                elif source.startswith("git+https://"):
                    remote, separator, commit = source[4:].rpartition("#")
                    remote = remote.partition("?")[0]
                    if not separator or not _hex(commit, 40):
                        fail("A Git Cargo package requires a full locked commit: " + key)
                    if "@" in remote[len("https://"):].partition("/")[0]:
                        fail("Cargo license fetching supports public HTTPS Git URLs without credentials.")
                    git_key = remote + "#" + commit
                    if git_key not in git_sources:
                        git(
                            name = name,
                            remote = remote,
                            commit = commit,
                            init_submodules = False,
                            patch_cmds = ["git ls-files -z -- Cargo.toml '*/Cargo.toml' > .rules_sbom_manifests"],
                            build_file_content = 'exports_files([".rules_sbom_manifests"], visibility = ["//visibility:public"])\n',
                        )
                        git_sources[git_key] = len(git_lists)
                        git_lists.append("@" + name + "//:.rules_sbom_manifests")
                    entries.append(dict(entry = entry, kind = "git", index = git_sources[git_key], url = remote, commit = commit))
                else:
                    entries.append(dict(entry = entry, kind = "unsupported"))
            metadata(
                name = tag.name,
                entries = json.encode(entries),
                registry_manifests = registry_manifests,
                git_lists = git_lists,
            )

def _cargo_impl(ctx):
    declare_cargo_repositories(ctx)
    return ctx.extension_metadata(reproducible = True)

cargo = module_extension(
    implementation = _cargo_impl,
    tag_classes = {
        "from_lockfiles": tag_class(attrs = {
            "lockfiles": attr.label_list(mandatory = True, doc = "Source Cargo.lock files. Generated files are not supported."),
            "name": attr.string(mandatory = True, doc = "Name of the generated license metadata repository."),
        }),
    },
    doc = "Fetch crates.io and public HTTPS Git license evidence from source Cargo.lock files.",
)
