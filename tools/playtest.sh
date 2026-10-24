#!/usr/bin/env bash
# Run the play tests under Xvfb with real input events.
#
# Usage:
#   tools/playtest.sh NAME [--size=WxH]   Run one scenario (default size 720x1280).
#   tools/playtest.sh --all               Run all scenarios at all their sizes.
#
# Output goes to build/playtest/NAME/WxH/: numbered screenshots, log.json,
# and godot-N.log (the Godot output of run N).
#
# A scenario file can have these header lines:
#   # sizes: 720x1280 1080x2400 1280x720   The sizes for --all.
#   # phase: ARGS                          One run with these arguments. Each
#                                          phase line is one run, in order.
#                                          The runs use the same save file.
#                                          The argument --fresh-save deletes
#                                          the save file before the run.
#
# A play test fails when an expect() fails or a wait times out, when Godot
# prints "SCRIPT ERROR" or "ERROR:" (not the audio driver lines), or when the
# scenario takes more than 180 seconds.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-$ROOT/.tools/godot/godot}"
DEFAULT_SIZES="720x1280 1080x2400"
TIME_LIMIT=200

if [[ ! -x "$GODOT" ]]; then
  echo "playtest.sh: Godot is missing. Run tools/setup.sh first." >&2
  exit 2
fi

usage() {
  echo "Usage: tools/playtest.sh NAME [--size=WxH] | --all" >&2
  exit 2
}

all=0
name=""
size=""
for arg in "$@"; do
  case "$arg" in
    --all) all=1 ;;
    --size=*) size="${arg#--size=}" ;;
    -*) usage ;;
    *) name="$arg" ;;
  esac
done
[[ "$all" == 1 || -n "$name" ]] || usage

# Prints the lines of a Godot log that are errors. An error line is ignored
# when it, or the "at:" line after it, is about the audio driver.
error_lines() {
  awk '
    function report() { if (pending != "" && !audio) print pending; pending = ""; audio = 0 }
    /SCRIPT ERROR|ERROR:/ {
      report(); pending = $0; audio = ($0 ~ /ALSA|audio_driver/); next
    }
    pending != "" && /^[[:space:]]+at:/ { if ($0 ~ /ALSA|audio_driver/) audio = 1; report(); next }
    { report() }
    END { report() }
  ' "$1"
}

# Runs one scenario at one size. Returns 0 when it passes.
run_one() {
  local scenario="$1" run_size="$2"
  local file="$ROOT/playtests/$scenario.gd"
  local out="$ROOT/build/playtest/$scenario/$run_size"
  if [[ ! -f "$file" ]]; then
    echo "playtest.sh: no scenario $file" >&2
    return 1
  fi
  rm -rf "$out"
  mkdir -p "$out"
  local phases=()
  while IFS= read -r line; do
    phases+=("${line#\# phase:}")
  done < <(grep -E '^# phase:' "$file")
  [[ ${#phases[@]} -gt 0 ]] || phases=("")

  local result=0 n=0
  for args in "${phases[@]}"; do
    n=$((n + 1))
    local log="$out/godot-$n.log"
    if [[ " $args " == *" --fresh-save "* ]]; then
      rm -f "$out/save.json"
      args="${args/--fresh-save/}"
    fi
    # shellcheck disable=SC2086
    timeout "$TIME_LIMIT" xvfb-run -a -s "-screen 0 2560x2560x24" \
      "$GODOT" --path "$ROOT" --rendering-driver opengl3 --audio-driver Dummy \
      --resolution "$run_size" -- \
      --playtest="$scenario" --out="$out" --save-path="$out/save.json" --phase="$n" $args \
      >"$log" 2>&1
    local status=$?
    if [[ $status == 124 ]]; then
      echo "  FAIL: run $n takes more than $TIME_LIMIT seconds" >&2
      result=1
    elif [[ $status != 0 ]]; then
      echo "  FAIL: run $n exit code $status" >&2
      grep -E '^  - ' "$log" >&2
      result=1
    fi
    if ! grep -q "PLAYTEST PASS" "$log"; then
      result=1
    fi
    local errors
    errors="$(error_lines "$log")"
    if [[ -n "$errors" ]]; then
      echo "  FAIL: Godot printed errors in run $n:" >&2
      echo "$errors" | sed 's/^/    /' >&2
      result=1
    fi
    [[ $result == 0 ]] || break
  done
  return $result
}

sizes_of() {
  local found
  found="$(grep -E '^# sizes:' "$ROOT/playtests/$1.gd" | head -1 | sed 's/^# sizes://')"
  echo "${found:-$DEFAULT_SIZES}"
}

mkdir -p "$ROOT/build/playtest"
echo "Import the project."
"$GODOT" --headless --path "$ROOT" --import >"$ROOT/build/playtest/import.log" 2>&1

failed=()
passed=0
if [[ "$all" == 1 ]]; then
  scenarios=()
  for f in "$ROOT"/playtests/*.gd; do
    scenarios+=("$(basename "$f" .gd)")
  done
else
  scenarios=("$name")
fi

for scenario in "${scenarios[@]}"; do
  if [[ "$all" == 1 ]]; then
    run_sizes="$(sizes_of "$scenario")"
  else
    run_sizes="${size:-720x1280}"
  fi
  for s in $run_sizes; do
    start=$(date +%s)
    if run_one "$scenario" "$s"; then
      echo "PASS $scenario $s ($(( $(date +%s) - start )) s)"
      passed=$((passed + 1))
    else
      echo "FAIL $scenario $s ($(( $(date +%s) - start )) s)"
      failed+=("$scenario $s")
    fi
  done
done

echo "Passed: $passed. Failed: ${#failed[@]}."
for f in "${failed[@]}"; do
  echo "  failed: $f"
done
[[ ${#failed[@]} == 0 ]]
