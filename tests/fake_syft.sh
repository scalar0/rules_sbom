#!/bin/bash
set -euo pipefail

command=$1
scan_root=$2
shift 2
[[ -d $HOME && -d $TMPDIR && -d $XDG_CONFIG_HOME && -d $XDG_CACHE_HOME ]]
[[ ${SBOM_HOST_MARKER+x} != x ]]
[[ ${SYFT_CONFIG+x} != x ]]
[[ $SYFT_CHECK_FOR_APP_UPDATE == false ]]
online=false
if [[ ${RULES_SBOM_REFRESH_KEY+x} == x ]]; then
    online=true
    [[ $RULES_SBOM_REFRESH_KEY == test-refresh ]]
    [[ ${SYFT_GOLANG_SEARCH_REMOTE_LICENSES+x} != x ]]
    [[ ${SYFT_JAVASCRIPT_SEARCH_REMOTE_LICENSES+x} != x ]]
    [[ ${SYFT_PYTHON_SEARCH_REMOTE_LICENSES+x} != x ]]
    [[ ${SYFT_JAVA_USE_NETWORK+x} != x ]]
    [[ ${SYFT_JAVA_RESOLVE_TRANSITIVE_DEPENDENCIES+x} != x ]]
else
    [[ $SYFT_GOLANG_SEARCH_REMOTE_LICENSES == false ]]
    [[ $SYFT_JAVASCRIPT_SEARCH_REMOTE_LICENSES == false ]]
    [[ $SYFT_PYTHON_SEARCH_REMOTE_LICENSES == false ]]
    [[ $SYFT_JAVA_USE_NETWORK == false ]]
    [[ $SYFT_JAVA_RESOLVE_TRANSITIVE_DEPENDENCIES == false ]]
fi
[[ $SYFT_GOLANG_SEARCH_LOCAL_MOD_CACHE_LICENSES == false ]]
[[ $SYFT_GOLANG_SEARCH_LOCAL_VENDOR_LICENSES == false ]]
[[ $SYFT_GOLANG_USE_PACKAGES_LIB == false ]]
[[ $SYFT_JAVA_USE_MAVEN_LOCAL_REPOSITORY == false ]]
[[ ${SYFT_LOG_FILE+x} == x && -z $SYFT_LOG_FILE ]]
[[ ${SYFT_DEV_PROFILE+x} == x && -z $SYFT_DEV_PROFILE ]]
[[ ${SYFT_FORMAT_TEMPLATE_PATH+x} == x && -z $SYFT_FORMAT_TEMPLATE_PATH ]]
[[ $SYFT_CACHE_TTL == 0 ]]

[[ -f "$0.runfiles/_main/tests/toolchain-marker.txt" ]]

if [[ ${1:-} == --config ]]; then
    [[ -f $2 ]]
    shift 2
fi
if [[ $command == scan ]]; then
    [[ -d $scan_root ]]
    [[ $HOME == "${scan_root%/inputs}/home" ]]
    lockfile="$scan_root/main/tests/fixtures/Cargo.lock"
    [[ -f $lockfile && ! -L $lockfile ]]
    [[ ! -e "$scan_root/main/tests/fixtures/package-lock.json" ]]
    [[ $1 == --from && $2 == dir ]]
    [[ $3 == --base-path && $4 == "$scan_root" ]]
    shift 4
    if [[ $online == false ]]; then
        [[ $1 == --enrich && $2 == none ]]
        shift 2
    fi
else
    [[ $command == convert && $online == true && -f $scan_root ]]
fi

while (($#)); do
    [[ $1 == --output ]]
    case $2 in
        syft-json=*)
            if [[ $command == convert ]]; then
                cp "$scan_root" "${2#*=}"
            elif [[ $online == true ]]; then
                printf '{"toolchain":"override","isolated":true,"network":true,"artifacts":[]}\n' > "${2#*=}"
            else
                printf '{"toolchain":"override","isolated":true}\n' > "${2#*=}"
            fi
            ;;
        failure=*) echo 'The test tool failed.' >&2; exit 23 ;;
        *) exit 24 ;;
    esac
    shift 2
done
