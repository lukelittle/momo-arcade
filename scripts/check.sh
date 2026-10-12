#!/usr/bin/env bash
# Runs every quality gate: format, lint, strict type check, and a Rojo build per game.
# Usage: ./scripts/check.sh            (from the repo root)
set -euo pipefail
cd "$(dirname "$0")/.."

CACHE=".cache"
DEFS="$CACHE/globalTypes.d.luau"
mkdir -p "$CACHE"
if [ ! -f "$DEFS" ]; then
	echo "Downloading Roblox type definitions for luau-lsp..."
	curl -fsSL -o "$DEFS" \
		https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau
fi

echo "==> stylua --check"
stylua --check shared games

echo "==> selene"
selene shared games

for project in games/*/default.project.json; do
	game_dir="$(dirname "$project")"
	name="$(basename "$game_dir")"
	echo "==> rojo build ($name)"
	rojo build "$project" -o "$CACHE/$name.rbxl"

	echo "==> luau-lsp analyze ($name)"
	# Sourcemap paths are relative to the project file, so analyze from the game folder.
	(
		cd "$game_dir"
		rojo sourcemap default.project.json -o "../../$CACHE/$name.sourcemap.json"
		luau-lsp analyze \
			--platform=roblox \
			--defs="../../$DEFS" \
			--sourcemap="../../$CACHE/$name.sourcemap.json" \
			--no-strict-dm-types \
			../../shared src
	)
done

echo "All checks passed."
