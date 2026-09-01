#!/usr/bin/env bash
# Packages the macOS setup installer (WiiCompiled-Setup-macos-arm64.pkg).
# Resolves dependencies (Translator.Cli, nodtool, CMake, Ninja) and invokes
# Launcher/macos/build-setup-pkg.command.
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
workspace=$(cd "$script_dir/.." && pwd)

fail() { printf 'build-macos-pkg.sh: error: %s\n' "$*" >&2; exit 1; }

output_dir="$workspace/Launcher/dist"
version="0.1.0"
identity=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --output-dir) output_dir=$2; shift 2 ;;
        --version) version=$2; shift 2 ;;
        --installer-identity) identity=$2; shift 2 ;;
        -h|--help)
            echo "Usage: build-macos-pkg.sh [--output-dir DIR] [--version VERSION] [--installer-identity NAME]"
            exit 0
            ;;
        *) fail "unknown argument: $1" ;;
    esac
done

mkdir -p "$output_dir"

echo "Publishing the translator (self-contained osx-arm64)..."
translator_publish_tmp="$workspace/Launcher/artifacts/macos-build/publish-translator"
rm -rf "$translator_publish_tmp"
dotnet publish "$workspace/translator/src/Translator.Cli" -c Release -r osx-arm64 \
    --self-contained -p:PublishSingleFile=true -p:EnableCompressionInSingleFile=true \
    -o "$translator_publish_tmp"

echo "Resolving nodtool..."
nodtool_path=$(dotnet run --project "$workspace/Launcher/WiiCompiled.Setup.Common.Cli" -c Release -- \
    --workspace "$workspace" | tail -n1)

echo "Locating CMake and Ninja..."
cmake_bin=$(command -v cmake || true)
ninja_bin=$(command -v ninja || true)
[[ -n "$cmake_bin" ]] || fail "cmake not found on PATH"
[[ -n "$ninja_bin" ]] || fail "ninja not found on PATH"

cmake_root=$(cd "$(dirname "$cmake_bin")/.." && pwd)

output_pkg="$output_dir/WiiCompiled-Setup-macos-arm64.pkg"

echo "Building macOS installer package..."
cmd=(
    bash "$workspace/Launcher/macos/build-setup-pkg.command"
    --workspace "$workspace"
    --nodtool "$nodtool_path"
    --translator "$translator_publish_tmp/Translator.Cli"
    --cmake-root "$cmake_root"
    --ninja "$ninja_bin"
    --output "$output_pkg"
    --version "$version"
)
if [[ -n "$identity" ]]; then
    cmd+=(--installer-identity "$identity")
fi

"${cmd[@]}"

echo "Built: $output_pkg"
