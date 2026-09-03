#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
steam_editor="$project_dir/.tools/godotsteam-4.20.1/godotsteam.471.editor.x86_64"
official_editor="${GODOT_BIN:-godot}"
package_name="${1:-Farmacia-Windows-Steam-MP10-RC1}"
windows_dir="$project_dir/builds/windows"
archive="$project_dir/builds/$package_name.zip"
temporary_root="$(mktemp -d)"

cleanup() {
	rm -rf "$temporary_root"
}
trap cleanup EXIT

if [[ ! -x "$steam_editor" ]]; then
	printf 'GodotSteam não encontrado em: %s\n' "$steam_editor" >&2
	exit 1
fi
if ! command -v "$official_editor" >/dev/null 2>&1; then
	printf 'Godot oficial não encontrado: %s\n' "$official_editor" >&2
	exit 1
fi

printf 'Validando com Godot oficial...\n'
XDG_DATA_HOME="$temporary_root/official-data" \
XDG_CONFIG_HOME="$temporary_root/official-config" \
	"$official_editor" --headless --path "$project_dir" --quit-after 240

printf 'Validando com GodotSteam...\n'
XDG_DATA_HOME="$temporary_root/steam-data" \
XDG_CONFIG_HOME="$temporary_root/steam-config" \
	"$steam_editor" --headless --path "$project_dir" --quit-after 240

printf 'Exportando Windows...\n'
XDG_DATA_HOME="$temporary_root/export-data" \
XDG_CONFIG_HOME="$temporary_root/export-config" \
	"$steam_editor" --headless --path "$project_dir" \
	--export-debug Farmacia "$windows_dir/Farmacia.exe"

required_files=(
	"$windows_dir/Farmacia.exe"
	"$windows_dir/Farmacia.pck"
	"$windows_dir/steam_api64.dll"
	"$windows_dir/steam_appid.txt"
	"$windows_dir/LEIA-ME.txt"
)
for required_file in "${required_files[@]}"; do
	if [[ ! -f "$required_file" ]]; then
		printf 'Arquivo obrigatório ausente: %s\n' "$required_file" >&2
		exit 1
	fi
done

zip -j -9 "$archive" "${required_files[@]}"
unzip -t "$archive"
sha256sum "$archive"
