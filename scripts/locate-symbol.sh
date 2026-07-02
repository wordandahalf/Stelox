#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: $0 <path-to.efi> <runtime-image-base> <addr1> [addr2 ...]"
    echo "Example: $0 bootx64.efi 0x7A81000 0x7A8202C 0x7A83110"
    exit 1
}

if [ "$#" -lt 3 ]; then
    usage
fi

EFI_FILE="$1"
RUNTIME_BASE_RAW="$2"
shift 2
ADDRS=("$@")

if [ ! -f "$EFI_FILE" ]; then
    echo "Error: file not found: $EFI_FILE" >&2
    exit 1
fi

for tool in llvm-readobj llvm-symbolizer; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "Error: '$tool' not found on PATH." >&2
        exit 1
    fi
done

# Strip an optional 0x/0X prefix, validate, and print the decimal value.
to_dec() {
    local raw="${1#0x}"
    raw="${raw#0X}"
    if [[ -z "$raw" || ! "$raw" =~ ^[0-9A-Fa-f]+$ ]]; then
        echo "Error: '$1' is not a valid hex address" >&2
        exit 1
    fi
    printf '%d\n' "$((16#$raw))"
}

RUNTIME_BASE=$(to_dec "$RUNTIME_BASE_RAW")

# Extract the link-time (preferred) ImageBase from the PE optional header
HEADER_OUTPUT=$(llvm-readobj --file-headers "$EFI_FILE" 2>&1 || true)
PREF_BASE_HEX=$(printf '%s\n' "$HEADER_OUTPUT" \
    | grep -oiE 'ImageBase:[[:space:]]*0x[0-9A-Fa-f]+' \
    | head -n1 \
    | grep -oiE '0x[0-9A-Fa-f]+' || true)

if [ -z "$PREF_BASE_HEX" ]; then
    HEADER_OUTPUT=$(llvm-readobj --all "$EFI_FILE" 2>&1 || true)
    PREF_BASE_HEX=$(printf '%s\n' "$HEADER_OUTPUT" \
        | grep -oiE 'ImageBase:[[:space:]]*0x[0-9A-Fa-f]+' \
        | head -n1 \
        | grep -oiE '0x[0-9A-Fa-f]+' || true)
fi

if [ -z "$PREF_BASE_HEX" ]; then
    echo "Error: could not find 'ImageBase' in llvm-readobj output for $EFI_FILE" >&2
    echo "Try 'llvm-readobj --help' to find the right dump flag for your LLVM version." >&2
    exit 1
fi

PREFERRED_BASE=$(to_dec "$PREF_BASE_HEX")

DELTA=$((RUNTIME_BASE - PREFERRED_BASE))

printf 'Runtime base   : 0x%x\n' "$RUNTIME_BASE"
printf 'Link-time base : 0x%x\n' "$PREFERRED_BASE"
printf 'Delta          : 0x%x\n' "$DELTA"
echo

TRANSLATED=()
for addr in "${ADDRS[@]}"; do
    raw_dec=$(to_dec "$addr")
    fixed_dec=$((raw_dec - DELTA))
    printf '0x%016x  ->  0x%016x\n' "$raw_dec" "$fixed_dec"
    TRANSLATED+=("$(printf '0x%x' "$fixed_dec")")
done
echo

llvm-symbolizer --obj="$EFI_FILE" --functions=linkage --inlining --pretty-print "${TRANSLATED[@]}"