#!/usr/bin/env bash
# The full pre-commit gate: StyLua, Selene, luau-lsp strict, the three Rojo builds and the
# headless TestEZ suite. Tools come from $TOOLS (default C:\Users\Administrator\Tools\1v1card),
# set up as described in README "Toolchain".
#   bash scripts/check.sh          everything
#   bash scripts/check.sh fast     skip the Rojo builds
set -euo pipefail
cd "$(dirname "$0")/.."
TOOLS="${TOOLS:-/c/Users/Administrator/Tools/1v1card}"
export PATH="$TOOLS/bin:$TOOLS/py/tools:$PATH"
GLOBAL_TYPES="${GLOBAL_TYPES:-$TOOLS/globalTypes.d.luau}"

echo "== stylua"; stylua --check src tests
echo "== selene"; selene --quiet src tests
echo "== sourcemap"; rojo sourcemap dev.project.json -o sourcemap.json
echo "== luau-lsp"
luau-lsp analyze --definitions="$GLOBAL_TYPES" --definitions=testez.d.luau \
	--sourcemap=sourcemap.json --ignore="DevPackages/**" src tests
if [ "${1:-}" != "fast" ]; then
	echo "== rojo builds"
	mkdir -p build
	for p in default dev e2e; do rojo build "$p.project.json" -o "build/check_$p.rbxlx" >/dev/null; done
fi
echo "== headless TestEZ"
python scripts/headless/bundle.py
luau build/headless.luau | tail -n 5
