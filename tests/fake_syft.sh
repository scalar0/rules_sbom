#!/bin/bash
set -euo pipefail

[[ $1 == scan ]]
scan_root=$2
shift 2
[[ -d $scan_root ]]
[[ -d $HOME && -d $TMPDIR && -d $XDG_CONFIG_HOME && -d $XDG_CACHE_HOME ]]
[[ $HOME == "${scan_root%/inputs}/home" ]]
[[ ${SBOM_HOST_MARKER+x} != x ]]
[[ ${SYFT_CONFIG+x} != x ]]
[[ $SYFT_CHECK_FOR_APP_UPDATE == false ]]
[[ $SYFT_JAVASCRIPT_SEARCH_REMOTE_LICENSES == false ]]
[[ ${SYFT_LOG_FILE+x} == x && -z $SYFT_LOG_FILE ]]
[[ ${SYFT_DEV_PROFILE+x} == x && -z $SYFT_DEV_PROFILE ]]
[[ ${SYFT_FORMAT_TEMPLATE_PATH+x} == x && -z $SYFT_FORMAT_TEMPLATE_PATH ]]
[[ $SYFT_CACHE_TTL == 0 ]]

lockfile="$scan_root/main/tests/fixtures/Cargo.lock"
[[ -f $lockfile && ! -L $lockfile ]]
[[ ! -e "$scan_root/main/tests/fixtures/package-lock.json" ]]
[[ -f "$0.runfiles/_main/tests/toolchain-marker.txt" ]]

if [[ ${1:-} == --config ]]; then
    [[ -f $2 ]]
    shift 2
fi
[[ $1 == --from && $2 == dir ]]
[[ $3 == --base-path && $4 == "$scan_root" ]]
[[ $5 == --enrich && $6 == none ]]
shift 6

while (($#)); do
    [[ $1 == --output ]]
    case $2 in
        syft-json=*) printf '{"toolchain":"override","isolated":true}\n' > "${2#*=}" ;;
        failure=*) echo 'The test tool failed.' >&2; exit 23 ;;
        *) exit 24 ;;
    esac
    shift 2
done
