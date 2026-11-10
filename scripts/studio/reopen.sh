#!/usr/bin/env bash
# Rebuilds a project to build/<name>.rbxlx and reopens it in Roblox Studio (Studio can't fetch
# localhost, so this is how code reaches the open place). Usage:
#   bash scripts/studio/reopen.sh [project=dev] [name=final]
set -euo pipefail
cd "$(dirname "$0")/../.."
TOOLS="${TOOLS:-/c/Users/Administrator/Tools/1v1card}"
PROJECT="${1:-dev}"; NAME="${2:-final}"
taskkill //IM RobloxStudioBeta.exe //F >/dev/null 2>&1 || true
"$TOOLS/bin/rojo" build "$PROJECT.project.json" -o "build/$NAME.rbxlx" >/dev/null
STUDIO=$(ls -d "/c/Program Files/Roblox/Versions/"*/RobloxStudioBeta.exe | tail -1)
"$STUDIO" "$(cygpath -w "$PWD/build/$NAME.rbxlx")" >/dev/null 2>&1 &
echo "opening build/$NAME.rbxlx"
