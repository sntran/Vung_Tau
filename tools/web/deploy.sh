#!/bin/bash
# Plan 0009, R16: export the web build and deploy it to the Worker vung-tau.
# main goes to the Worker; another branch goes to its preview URL (an alias
# from the name of the branch). index.pck and index.wasm go to the R2 bucket
# vung-tau under builds/COMMIT/. Only the Worker vung-tau and its bucket change.
# Needs CLOUDFLARE_API_TOKEN and CLOUDFLARE_ACCOUNT_ID in the environment, and
# wrangler (WRANGLER, default "npx --yes wrangler@4.166.0").
# SKIP_EXPORT=1 deploys build/web as it is; BRANCH=NAME gives the branch of a
# worktree with no branch (detached).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
WRANGLER="${WRANGLER:-npx --yes wrangler@4.166.0}"
BUILD="$(git rev-parse --short=12 HEAD)"
BRANCH="${BRANCH:-$(git rev-parse --abbrev-ref HEAD)}"
WEB="$ROOT/build/web"
ASSETS="$ROOT/build/web-assets"
if [[ "${SKIP_EXPORT:-}" != "1" ]]; then
  rm -rf "$WEB"; mkdir -p "$WEB"
  .tools/godot/godot --headless --path . --export-release "Web" "$WEB/index.html"
fi
# The small files are static assets; the page takes the large files from b/BUILD/.
rm -rf "$ASSETS"; mkdir -p "$ASSETS"
for file in "$WEB"/*; do
  case "$(basename "$file")" in
    index.pck|index.wasm) ;;
    *) cp "$file" "$ASSETS/" ;;
  esac
done
KIND="new"; grep -q "func web_args" autoload/game_state.gd || KIND="old"
python3 - "$ASSETS/index.html" "$BUILD" "$KIND" <<'PY'
import json, re, sys
path, build, kind = sys.argv[1], sys.argv[2], sys.argv[3]
html = open(path, encoding="utf-8").read()
match = re.search(r"const GODOT_CONFIG = (\{.*?\});", html)
config = json.loads(match.group(1))
base = f"b/{build}/index"
config["executable"] = base
config["mainPack"] = f"{base}.pck"
config["fileSizes"] = {f"b/{build}/{name}": size for name, size in config["fileSizes"].items()}
# A build with no reader of the URL (before R16) starts the Vũng Tàu world from the config.
if kind == "old":
    config["args"] = ["--world=vung_tau"]
html = html[:match.start(1)] + json.dumps(config) + html[match.end(1):]
open(path, "w", encoding="utf-8").write(html)
PY
cd "$ROOT/tools/web"
$WRANGLER r2 bucket list | grep -q "^name: *vung-tau$" || $WRANGLER r2 bucket create vung-tau
# wrangler uploads at most 300 MiB for one object: a larger file goes in parts
# of 250 MiB (NAME.part0, NAME.part1, ...), and the Worker gives them as one file.
PART_BYTES=262144000
PARTS="$ROOT/build/web-parts"
for name in index.pck index.wasm; do
  type="application/octet-stream"; [[ "$name" == *.wasm ]] && type="application/wasm"
  if (( $(stat -c %s "$WEB/$name") > PART_BYTES )); then
    rm -rf "$PARTS"; mkdir -p "$PARTS"
    split -b "$PART_BYTES" -d -a 1 "$WEB/$name" "$PARTS/$name.part"
    for part in "$PARTS"/*; do
      $WRANGLER r2 object put "vung-tau/builds/$BUILD/$(basename "$part")" --file "$part" --content-type "$type" --remote
    done
    rm -rf "$PARTS"
  else
    $WRANGLER r2 object put "vung-tau/builds/$BUILD/$name" --file "$WEB/$name" --content-type "$type" --remote
  fi
done
if [[ "$BRANCH" == "main" ]]; then
  $WRANGLER deploy
else
  ALIAS="$(echo "$BRANCH" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g; s/--*/-/g; s/^-//; s/-$//' | cut -c1-40)"
  $WRANGLER versions upload --preview-alias "$ALIAS" --message "$BRANCH $BUILD"
fi
echo "Deployed the build $BUILD of $BRANCH."
