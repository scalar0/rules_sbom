"""Output extensions and rule-owned Syft configuration."""

# Syft ignores hyphens and underscores when it matches format names and aliases.
FORMAT_EXTENSIONS = {
    "cdx": ".xml",
    "cyclone": ".xml",
    "cyclonedx": ".xml",
    "cyclonedxjson": ".json",
    "cyclonedxxml": ".xml",
    "github": ".json",
    "githubjson": ".json",
    "json": ".json",
    "purl": ".txt",
    "purls": ".txt",
    "spdx": ".spdx",
    "spdxjson": ".json",
    "spdxtagvalue": ".spdx",
    "spdxtv": ".spdx",
    "syft": ".json",
    "syftjson": ".json",
    "syfttable": ".txt",
    "syfttext": ".txt",
    "table": ".txt",
    "text": ".txt",
}

SYFT_ENV = {
    "PATH": "/usr/bin:/bin",
    "SYFT_CACHE_DIR": "",
    "SYFT_CACHE_TTL": "0",
    "SYFT_CHECK_FOR_APP_UPDATE": "false",
    "SYFT_DEV_PROFILE": "",
    "SYFT_FORMAT_TEMPLATE_PATH": "",
    "SYFT_GOLANG_SEARCH_LOCAL_MOD_CACHE_LICENSES": "false",
    "SYFT_GOLANG_SEARCH_LOCAL_VENDOR_LICENSES": "false",
    "SYFT_GOLANG_USE_PACKAGES_LIB": "false",
    "SYFT_JAVA_USE_MAVEN_LOCAL_REPOSITORY": "false",
    "SYFT_LOG_FILE": "",
}

SYFT_OFFLINE_ENV = {
    "SYFT_GOLANG_SEARCH_REMOTE_LICENSES": "false",
    "SYFT_JAVASCRIPT_SEARCH_REMOTE_LICENSES": "false",
    "SYFT_JAVA_RESOLVE_TRANSITIVE_DEPENDENCIES": "false",
    "SYFT_JAVA_USE_NETWORK": "false",
    "SYFT_PYTHON_SEARCH_REMOTE_LICENSES": "false",
}
