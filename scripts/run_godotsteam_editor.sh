#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
editor="$project_dir/.tools/godotsteam-4.20.1/godotsteam.471.editor.x86_64"

if [[ ! -x "$editor" ]]; then
	printf 'GodotSteam não encontrado em: %s\n' "$editor" >&2
	printf 'Conclua a fase MP0 antes de executar este atalho.\n' >&2
	exit 1
fi

cd "$project_dir"
exec "$editor" --editor --path "$project_dir" "$@"
