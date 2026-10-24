#!/usr/bin/env bash
# Run the play tests under Xvfb with real input events.
#
# Usage:
#   tools/playtest.sh NAME [--size=WxH] [--renderer=mobile|forward_plus|compatibility]
#                                         Run one scenario (default 1280x720, mobile).
#   tools/playtest.sh --all               Run all scenarios at all their sizes.
#   tools/playtest.sh NAME --only-phase=N  Run only phase N of a scenario (to
#                                          find a defect in a long scenario).
#   tools/playtest.sh --all --shard=I/N    Run the I-th of N parts of the
#                                          scenarios (CI runs the parts at the
#                                          same time).
#
# Output goes to build/playtest/NAME/WxH/: numbered screenshots, log.json,
# and godot-N.log (the Godot output of run N).
#
# A scenario file can have these header lines:
#   # sizes: 1280x720 2400x1080            The sizes for --all.
#   # compatibility: 1280x720              With --all, also one run at this size
#                                          with the Compatibility renderer (the
#                                          renderer of the web build).
#   # phase: ARGS                          One run with these arguments. Each
#                                          phase line is one run, in order.
#                                          The runs use the same save file.
#                                          The argument --fresh-save deletes
#                                          the save file before the run.
#                                          The argument --renderer=NAME runs
#                                          this phase with another renderer
#                                          (mobile, forward_plus, or
#                                          compatibility).
#
# The environment variable PLAYTEST_MAX_FPS limits the frame rate, so that a
# fast computer can test like a slow one (for example PLAYTEST_MAX_FPS=3).
#
# A play test fails when an expect() fails or a wait times out, when Godot
# prints "SCRIPT ERROR" or "ERROR:" (not the audio driver lines), or when the
# scenario takes more than 180 seconds.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-$ROOT/.tools/godot/godot}"
DEFAULT_SIZES="1280x720 2400x1080"
TIME_LIMIT=200

if [[ ! -x "$GODOT" ]]; then
  echo "playtest.sh: Godot is missing. Run tools/setup.sh first." >&2
  exit 2
fi

usage() {
  echo "Usage: tools/playtest.sh NAME [--size=WxH] [--renderer=mobile|forward_plus|compatibility] | --all" >&2
  exit 2
}

all=0
name=""
size=""
renderer="mobile"
only_phase=""
shard=""
for arg in "$@"; do
  case "$arg" in
    --all) all=1 ;;
    --size=*) size="${arg#--size=}" ;;
    --renderer=*) renderer="${arg#--renderer=}" ;;
    --only-phase=*) only_phase="${arg#--only-phase=}" ;;
    --shard=*) shard="${arg#--shard=}" ;;
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

# The renderer arguments for each renderer name.
renderer_args() {
  case "$1" in
    mobile) echo "--rendering-driver vulkan --rendering-method mobile" ;;
    forward_plus) echo "--rendering-driver vulkan --rendering-method forward_plus" ;;
    compatibility) echo "--rendering-driver opengl3 --rendering-method gl_compatibility" ;;
    *) echo "playtest.sh: unknown renderer $1" >&2; exit 2 ;;
  esac
}

# Runs one scenario at one size. Returns 0 when it passes.
run_one() {
  local scenario="$1" run_size="$2" renderer="${3:-mobile}"
  local file="$ROOT/playtests/$scenario.gd"
  local out="$ROOT/build/playtest/$scenario/$run_size"
  [[ "$renderer" == mobile ]] || out="$out-$renderer"
  local RENDERER_ARGS
  RENDERER_ARGS="$(renderer_args "$renderer")"
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
    if [[ -n "$only_phase" && "$n" != "$only_phase" ]]; then
      continue
    fi
    local log="$out/godot-$n.log"
    if [[ " $args " == *" --fresh-save "* ]]; then
      rm -f "$out/save.json"
      args="${args/--fresh-save/}"
    fi
    local phase_renderer_args="$RENDERER_ARGS"
    if [[ "$args" =~ --renderer=([a-z_]+) ]]; then
      phase_renderer_args="$(renderer_args "${BASH_REMATCH[1]}")"
      args="${args/--renderer=${BASH_REMATCH[1]}/}"
    fi
    # shellcheck disable=SC2086
    timeout "$TIME_LIMIT" xvfb-run -a -s "-screen 0 2560x2560x24" \
      "$GODOT" --path "$ROOT" $phase_renderer_args --audio-driver Dummy ${PLAYTEST_MAX_FPS:+--max-fps "$PLAYTEST_MAX_FPS"} \
      --resolution "$run_size" -- \
      --playtest="$scenario" --out="$out" --save-path="$out/save.json" --phase="$n" $args \
      >"$log" 2>&1 &
    local pid=$!
    # A script that does not parse never ends the run. Stop it at once.
    while kill -0 "$pid" 2>/dev/null; do
      if grep -q "Parse Error" "$log" 2>/dev/null; then
        sleep 2
        pkill -P "$pid" 2>/dev/null
        kill "$pid" 2>/dev/null
        break
      fi
      sleep 1
    done
    wait "$pid"
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
# Godot must not import the screenshots in build/.
touch "$ROOT/build/.gdignore"
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

# All runs: scenario, size, and renderer.
runs=()
for scenario in "${scenarios[@]}"; do
  if [[ "$all" == 1 ]]; then
    run_sizes="$(sizes_of "$scenario")"
  else
    run_sizes="${size:-1280x720}"
  fi
  for s in $run_sizes; do
    runs+=("$scenario:$s:$renderer")
  done
  if [[ "$all" == 1 ]]; then
    for s in $(grep -E '^# compatibility:' "$ROOT/playtests/$scenario.gd" | head -1 | sed 's/^# compatibility://'); do
      runs+=("$scenario:$s:compatibility")
    done
  fi
done

# A shard I/N takes the runs I, I + N, I + 2N, and so on.
if [[ -n "$shard" ]]; then
  part="${shard%%/*}"
  parts="${shard##*/}"
  selected=()
  for i in "${!runs[@]}"; do
    if (( i % parts == part - 1 )); then
      selected+=("${runs[$i]}")
    fi
  done
  runs=("${selected[@]}")
fi

for run in "${runs[@]}"; do
  IFS=: read -r scenario s r <<<"$run"
  label="$scenario $s"
  [[ "$r" == mobile ]] || label="$label $r"
  start=$(date +%s)
  if run_one "$scenario" "$s" "$r"; then
    echo "PASS $label ($(( $(date +%s) - start )) s)"
    passed=$((passed + 1))
  else
    echo "FAIL $label ($(( $(date +%s) - start )) s)"
    failed+=("$label")
  fi
done

echo "Passed: $passed. Failed: ${#failed[@]}."
for f in "${failed[@]}"; do
  echo "  failed: $f"
done
[[ ${#failed[@]} == 0 ]]
