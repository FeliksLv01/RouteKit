#!/bin/sh

set -e

cd "$(dirname "$0")"

macro_name="RouteKitMacros"
output_dir="./Prebuilt"
build_config="release"

mkdir -p "${output_dir}"

cd RouteKitMacros

swift build -c "${build_config}" -Xswiftc -Osize
bin_path_root=$(swift build -c "${build_config}" --show-bin-path)
binary=$(find "${bin_path_root}" -name "${macro_name}-tool" -type f -not -path "*.dSYM*" | head -n 1)

if [ -z "${binary}" ]; then
    binary=$(find "${bin_path_root}" -name "${macro_name}" -type f -not -path "*.dSYM*" | head -n 1)
fi

if [ -z "${binary}" ]; then
    echo "Error: ${macro_name} executable not found in ${bin_path_root}"
    exit 1
fi

output_path="../Prebuilt/${macro_name}"
cp "${binary}" "${output_path}"
chmod u+x "${output_path}"
strip -x "${output_path}"

echo "Built ${output_dir}/${macro_name}"
