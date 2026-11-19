#!/usr/bin/env bash
# Plan 0026, R21: a look on a real graphics card. On a Mac, in a checkout of
# the branch, this one command gets the macOS look build of the branch (the
# artifact "macos-look-build" of the export workflow: the macOS build with the
# play tests), runs PT-72 showcase_shots on High with it (the runs with
# --quality=high, and the run of the sheets), records the memory of the game
# in each run, and makes the sheets in docs/showcase/mac/.
#
#   tools/look_on_mac.sh            # the branch of the checkout
#   tools/look_on_mac.sh BRANCH
#
# It needs the GitHub CLI (brew install gh; gh auth login) and Python 3 with
# Pillow (python3 -m pip install pillow). The build is not signed: the script
# takes away the quarantine flag of the download (docs/release-notes.md).
# The memory: the log of each run (build/playtest/showcase_shots/1280x720/
# log.json) gives the memory of the engine and the video memory at each shot,
# and memory.txt the largest resident memory of the process of each run.
set -euo pipefail
cd "$(dirname "$0")/.."

REPO="sntran/Vung_Tau"
BRANCH="${1:-$(git rev-parse --abbrev-ref HEAD)}"
LOOK="build/macos-look"
OUT="$PWD/build/playtest/showcase_shots/1280x720"
PHOTOS="$PWD/docs/reference/photos"

command -v gh >/dev/null || { echo "ERROR: install the GitHub CLI (brew install gh) and run: gh auth login" >&2; exit 1; }
python3 -c "import PIL" 2>/dev/null || { echo "ERROR: install Pillow: python3 -m pip install pillow" >&2; exit 1; }

RUN="$(gh run list --repo "$REPO" --workflow export.yml --branch "$BRANCH" --status success --limit 1 \
  --json databaseId -q '.[0].databaseId')"
if [ -z "$RUN" ]; then
  echo "ERROR: no run of the export workflow on $BRANCH passed (push to the branch, or run the workflow by hand)" >&2
  exit 1
fi
echo "The macOS look build of $BRANCH: the export run $RUN."
rm -rf "$LOOK"
mkdir -p "$LOOK"
gh run download "$RUN" --repo "$REPO" -n macos-look-build -D "$LOOK"
ditto -x -k "$LOOK/VungTau-look.zip" "$LOOK"
APP="$(find "$LOOK" -maxdepth 1 -name '*.app' | head -n 1)"
[ -n "$APP" ] || { echo "ERROR: no .app in $LOOK" >&2; exit 1; }
xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true
BIN="$APP/Contents/MacOS/$(defaults read "$PWD/$APP/Contents/Info" CFBundleExecutable)"

rm -rf "$OUT"
mkdir -p "$OUT"
: > "$OUT/memory.txt"
failed=0
phase=0
# Each "# phase:" line of the scenario is one run (tools/playtest.sh does the same).
while IFS= read -r args; do
  phase=$((phase + 1))
  case "$args" in *quality=low*) continue ;; esac
  method=""
  game_args=""
  for arg in $args; do
    case "$arg" in
      --renderer=*) method="--rendering-method ${arg#--renderer=}" ;;
      *) game_args="$game_args $arg" ;;
    esac
  done
  echo "PT-72, run $phase:$game_args ${method}"
  # shellcheck disable=SC2086
  if ! /usr/bin/time -l "$BIN" $method --resolution 1280x720 --audio-driver Dummy -- \
      --playtest=showcase_shots --out="$OUT" --phase="$phase" --save-path="$OUT/save.json" \
      --photos="$PHOTOS" $game_args 2> "$OUT/time-$phase.txt"; then
    echo "  run $phase failed: see $OUT/log.json and $OUT/time-$phase.txt"
    failed=1
  fi
  rss="$(grep 'maximum resident set size' "$OUT/time-$phase.txt" | awk '{print $1}')"
  echo "run $phase:$game_args: the largest resident memory ${rss:-?} bytes" | tee -a "$OUT/memory.txt"
done < <(grep '^# phase:' playtests/showcase_shots.gd | sed 's/^# phase: //')

python3 tools/showcase/sheets.py --out docs/showcase/mac
cp "$OUT/memory.txt" docs/showcase/mac/memory.txt
echo "The sheets are in docs/showcase/mac/ (index.html), with memory.txt. Commit them to $BRANCH."
exit "$failed"
