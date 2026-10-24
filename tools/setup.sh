#!/usr/bin/env bash
# Download the tools for the project if they are missing.
#
# Usage: tools/setup.sh [--templates]
#
# - Godot 4.7.2-stable for Linux goes to .tools/godot/.
# - With --templates, the export templates for 4.7.2 go to the
#   Godot template folder (~/.local/share/godot/export_templates/).
# - GUT 9.7.1 goes to addons/gut/ when that folder is missing.
# - The Mesa Vulkan drivers (package mesa-vulkan-drivers) when lavapipe is missing.
#
# The script does nothing for the files that are already there.
set -euo pipefail

GODOT_VERSION="4.7.2"
GODOT_TAG="${GODOT_VERSION}-stable"
GUT_VERSION="9.7.1"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS="$ROOT/.tools"
GODOT_DIR="$TOOLS/godot"
GODOT_BIN="$GODOT_DIR/Godot_v${GODOT_TAG}_linux.x86_64"
RELEASES="https://github.com/godotengine/godot/releases/download/${GODOT_TAG}"
TEMPLATE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/${GODOT_VERSION}.stable"

want_templates=0
for arg in "$@"; do
  case "$arg" in
    --templates) want_templates=1 ;;
    *) echo "setup.sh: unknown argument: $arg" >&2; exit 2 ;;
  esac
done

download() { # url, output file
  curl --fail --location --retry 4 --retry-delay 2 --silent --show-error -o "$2" "$1"
}

# The Mobile renderer needs Vulkan. The workspace and CI have no GPU, so the
# play tests use the Mesa software Vulkan driver (lavapipe).
if [[ ! -f /usr/share/vulkan/icd.d/lvp_icd.json ]]; then
  echo "Install the Mesa Vulkan drivers (lavapipe)."
  if [[ "$(id -u)" == 0 ]]; then
    apt-get install -y mesa-vulkan-drivers || { apt-get update && apt-get install -y mesa-vulkan-drivers; }
  else
    sudo apt-get install -y mesa-vulkan-drivers || { sudo apt-get update && sudo apt-get install -y mesa-vulkan-drivers; }
  fi
fi

mkdir -p "$GODOT_DIR"

if [[ ! -x "$GODOT_BIN" ]]; then
  echo "Download Godot ${GODOT_TAG}."
  tmp="$(mktemp -d)"
  download "$RELEASES/Godot_v${GODOT_TAG}_linux.x86_64.zip" "$tmp/godot.zip"
  unzip -q -o "$tmp/godot.zip" -d "$GODOT_DIR"
  chmod +x "$GODOT_BIN"
  rm -rf "$tmp"
fi
ln -sf "$GODOT_BIN" "$GODOT_DIR/godot"

if [[ "$want_templates" == 1 && ! -f "$TEMPLATE_DIR/version.txt" ]]; then
  echo "Download the export templates for ${GODOT_TAG}."
  tmp="$(mktemp -d)"
  download "$RELEASES/Godot_v${GODOT_TAG}_export_templates.tpz" "$tmp/templates.tpz"
  unzip -q -o "$tmp/templates.tpz" -d "$tmp"
  mkdir -p "$TEMPLATE_DIR"
  cp -r "$tmp/templates/." "$TEMPLATE_DIR/"
  rm -rf "$tmp"
fi

if [[ ! -f "$ROOT/addons/gut/gut_cmdln.gd" ]]; then
  echo "Download GUT ${GUT_VERSION}."
  tmp="$(mktemp -d)"
  git -c advice.detachedHead=false clone --quiet --depth 1 --branch "v${GUT_VERSION}" https://github.com/bitwes/Gut.git "$tmp/gut"
  mkdir -p "$ROOT/addons"
  cp -r "$tmp/gut/addons/gut" "$ROOT/addons/gut"
  rm -rf "$tmp"
fi

echo "Godot: $("$GODOT_BIN" --version)"
