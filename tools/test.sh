#!/usr/bin/env bash
# Import the project and run all unit tests in tests/unit/.
# The exit code is 0 only when all tests pass.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-$ROOT/.tools/godot/godot}"
if [[ ! -x "$GODOT" ]]; then
  echo "test.sh: Godot is missing. Run tools/setup.sh first." >&2
  exit 2
fi

mkdir -p "$ROOT/build"
# Godot must not import the screenshots in build/.
touch "$ROOT/build/.gdignore"
LOG="$ROOT/build/unit-tests.log"

# Report 0026, D-0026-44: the import files in the repository are the files
# that Godot writes. A short form (as tools/world/fetch.py writes it for a new
# model) changes at each import, and each play test leaves changed files. The
# check compares the import files before and after the import.
imports_state() {
  git -C "$ROOT" diff -- '*.import' 2>/dev/null | sha256sum
}
in_git=false
git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1 && in_git=true
$in_git && before=$(imports_state)

echo "Import the project."
"$GODOT" --headless --path "$ROOT" --import >"$ROOT/build/import.log" 2>&1 || {
  cat "$ROOT/build/import.log"
  echo "test.sh: the import failed." >&2
  exit 1
}

if $in_git && [[ "$(imports_state)" != "$before" ]]; then
  git -C "$ROOT" status --porcelain -- '*.import' | grep -v '^??' || true
  echo "test.sh: the import changed import files of the repository. Commit the files that Godot writes." >&2
  exit 1
fi

echo "Run the unit tests."
set +e
"$GODOT" --headless --path "$ROOT" --audio-driver Dummy \
  -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit 2>&1 | tee "$LOG"
status=${PIPESTATUS[0]}
set -e

# A script error is a failure, also when GUT does not see it.
if grep -E "SCRIPT ERROR|Parse Error" "$LOG" >/dev/null; then
  echo "test.sh: Godot printed a script error." >&2
  exit 1
fi
exit "$status"
