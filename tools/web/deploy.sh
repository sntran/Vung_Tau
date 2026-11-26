#!/bin/bash
# Plan 0009, R16: export the web build and deploy it to the Worker vung-tau.
# main goes to the Worker; another branch goes to its preview URL (an alias
# from the name of the branch). index.wasm goes to the R2 bucket vung-tau under
# builds/COMMIT/, with the manifest of the packs of the build; each pack goes in
# parts named by the hash of their content (p/HASH.pck, plan 0031, D15, R7),
# and only the parts that the bucket does not have go up. The deploy keeps the
# files of the last five builds and of the build of main, and removes the other
# files of the bucket (R9). Only the Worker vung-tau and its bucket change.
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
  # Plan 0031, D4: the filters of the preset Web and the gzip copies of the build data.
  python3 tools/web/prepare.py
  rm -rf "$WEB"; mkdir -p "$WEB"
  .tools/godot/godot --headless --path . --export-release "Web" "$WEB/index.html"
  # Plan 0031, D5: the packs of data/web/packs.json, which the game gets while it runs.
  python3 tools/web/prepare.py --packs | sed -n 's/^PACK //p' | while read -r id files; do
    # shellcheck disable=SC2086
    .tools/godot/godot --headless --path . -s tools/web/make_pack.gd -- "$WEB/$id.pck" $files
  done
fi
# Plan 0031, R2: no near level of a building and no raw data in the web pack.
python3 tools/web/check_pack.py "$WEB/index.pck"
# Plan 0031, D5: the test pack of a second pack (?packtest): the near level of
# a building, which the main pack leaves out.
.tools/godot/godot --headless --path . -s tools/web/make_pack.gd -- "$WEB/packtest.pck" res://assets/world/nha_mai_ngoi_cam.glb
# Plan 0031, D15 and R7: each pack in parts of at most 40 MB, named by their
# hash; the page gets them, keeps them in its cache, and gives them to the engine.
rm -rf "$WEB/parts"
PACK_ARGS=(index="$WEB/index.pck")
for pack in "$WEB"/*.pck; do
  id="$(basename "$pack" .pck)"
  [[ "$id" == "index" || "$id" == "packtest" ]] || PACK_ARGS+=("$id=$pack")
done
python3 tools/web/parts.py "$WEB/parts" "${PACK_ARGS[@]}" > "$WEB/packs.json"
# Plan 0031, D4: the Brotli copies of the large files.
node tools/web/compress.js "$WEB"/parts/p/*.pck "$WEB/packtest.pck" "$WEB/index.wasm"
# The small files are static assets; the page takes the large files from b/BUILD/.
rm -rf "$ASSETS"; mkdir -p "$ASSETS"
for file in "$WEB"/*; do
  case "$(basename "$file")" in
    *.pck|index.wasm|*.br|parts|packs.json) ;;
    *) cp "$file" "$ASSETS/" ;;
  esac
done
KIND="new"; grep -q "func web_args" autoload/game_state.gd || KIND="old"
python3 - "$ASSETS/index.html" "$BUILD" "$KIND" "$BRANCH" "$ROOT/tools/web/page.js" "$WEB/packs.json" <<'PY'
import json, re, sys
path, build, kind, branch, page_js, packs_json = sys.argv[1:7]
packs = json.load(open(packs_json, encoding="utf-8"))["packs"]
html = open(path, encoding="utf-8").read()
# Plan 0031, D11: the build and the branch for the game, and the marks of the
# times of the start, before the script of Godot.
page = open(page_js, encoding="utf-8").read()
head = "<script>window.vungTauBuild = %s;\n%s</script>" % (json.dumps({"build": build, "branch": branch, "packs": packs}), page)
html = html.replace("<head>", "<head>" + head, 1)
# Plan 0031, D15: the page gets the start pack and gives it to the engine.
assert html.count("engine.startGame({") == 1
html = html.replace("engine.startGame({", "window.vungTau.startGame(engine, {", 1)
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
# Plan 0031, D15: the manifest of the packs of the build (r2.py keeps the parts that it uses).
$WRANGLER r2 object put "vung-tau/builds/$BUILD/manifest.json" --file "$WEB/packs.json" --content-type application/json --remote
# The parts that the bucket does not have yet.
HAVE="$(python3 "$ROOT/tools/web/r2.py" keys p/)"
for part in "$WEB"/parts/p/*.pck; do
  name="$(basename "$part")"
  for file in "$name" "$name.br"; do
    if [[ -f "$WEB/parts/p/$file" ]] && ! grep -qx "p/$file" <<< "$HAVE"; then
      $WRANGLER r2 object put "vung-tau/p/$file" --file "$WEB/parts/p/$file" --content-type application/octet-stream --remote
    fi
  done
done
for name in index.wasm packtest.pck; do
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
  # The Brotli copy (plan 0031, D4): the Worker gives it to a browser that takes "br".
  if [[ -f "$WEB/$name.br" ]] && (( $(stat -c %s "$WEB/$name.br") <= PART_BYTES )); then
    $WRANGLER r2 object put "vung-tau/builds/$BUILD/$name.br" --file "$WEB/$name.br" --content-type "$type" --remote
  fi
done
if [[ "$BRANCH" == "main" ]]; then
  $WRANGLER deploy
else
  ALIAS="$(echo "$BRANCH" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g; s/--*/-/g; s/^-//; s/-$//' | cut -c1-40)"
  $WRANGLER versions upload --preview-alias "$ALIAS" --message "$BRANCH $BUILD"
fi
echo "Deployed the build $BUILD of $BRANCH."
# Plan 0031, R9: remove the files of the builds older than the last five; the
# build of main (the page of the Worker) stays.
MAIN_BUILD="$(curl -fsS -A "deploy-tool" https://vung-tau.fifo.workers.dev/ | grep -o 'b/[0-9a-f]\{12\}/index' | head -1 | cut -d/ -f2 || true)"
if [[ -n "$MAIN_BUILD" ]]; then
  python3 "$ROOT/tools/web/r2.py" prune --keep 5 --protect "$MAIN_BUILD" "$BUILD"
else
  echo "r2.py: the build of main is not known: no removal."
fi
