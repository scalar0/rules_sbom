#!/bin/bash
set -euo pipefail

exec_root=$PWD
syft_binary="$exec_root/$1"
syft_config="$exec_root/$2"
allow_network=$3
metadata_count=$4
shift 4
enrichment_args=()
if [[ $allow_network == false ]]; then
    enrichment_args=(--enrich none)
fi
metadata=()
if ((metadata_count > 0)); then
    jq_binary="$exec_root/$1"
    enrich_filter="$exec_root/$2"
    shift 2
fi
for ((i = 0; i < metadata_count; i++)); do
    metadata+=("$exec_root/$1")
    shift
done
input_count=$1
shift

scan_scratch=$(mktemp -d "$exec_root/.sbom.XXXXXXXX")
trap 'rm -rf "$scan_scratch"' EXIT
scan_root="$scan_scratch/inputs"
mkdir -p "$scan_root" "$scan_scratch/home" "$scan_scratch/tmp" "$scan_scratch/cache" "$scan_scratch/config"

for ((i = 0; i < input_count; i++)); do
    destination="$scan_root/$2"
    mkdir -p "${destination%/*}"
    cp -L "$exec_root/$1" "$destination"
    shift 2
done

outputs=()
while (($#)); do
    output="$exec_root/$2"
    mkdir -p "${output%/*}"
    outputs+=(--output "$1=$output")
    shift 2
done

export HOME="$scan_scratch/home" TMPDIR="$scan_scratch/tmp"
export XDG_CACHE_HOME="$scan_scratch/cache" XDG_CONFIG_HOME="$scan_scratch/config"

if ((metadata_count == 0)); then
    "$syft_binary" scan "$scan_root" --config "$syft_config" \
        --from dir --base-path "$scan_root" "${enrichment_args[@]}" "${outputs[@]}"
else
    SYFT_FORMAT_JSON_LEGACY=false "$syft_binary" scan "$scan_root" --config "$syft_config" \
        --from dir --base-path "$scan_root" "${enrichment_args[@]}" \
        --output "syft-json=$scan_scratch/raw.json"
    "$jq_binary" --slurp -f "$enrich_filter" \
        "$scan_scratch/raw.json" "${metadata[@]}" > "$scan_scratch/enriched.json"
    "$syft_binary" convert "$scan_scratch/enriched.json" --config "$syft_config" "${outputs[@]}"
fi
