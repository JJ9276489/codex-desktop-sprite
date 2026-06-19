#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build/codex-lumi-pet"
OUTPUT_SPRITESHEET="$BUILD_DIR/spritesheet.png"
GENERATED_ASSET_DIR="$ROOT_DIR/Assets/ChibiAssistant/generated/codex-pet"
GENERATED_ASSET="$GENERATED_ASSET_DIR/codex-lumi-spritesheet.png"
PET_DIR="${CODEX_HOME:-$HOME/.codex}/pets/lumi"
STATE_FILE="${CODEX_HOME:-$HOME/.codex}/.codex-global-state.json"
MODE="install"

usage() {
  printf '%s\n' \
    "Usage: script/install_codex_lumi_pet.sh [--install|--build-only|--help]" \
    "" \
    "Builds a Codex-compatible Lumi custom-pet spritesheet." \
    "--install    Build, install to ~/.codex/pets/lumi, and select custom:lumi. Default." \
    "--build-only Build and validate the spritesheet without touching Codex state."
}

while (($#)); do
  case "$1" in
    --install)
      MODE="install"
      ;;
    --build-only)
      MODE="build-only"
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      printf 'error: unknown option: %s\n' "$1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

SWIFT_BIN="${SWIFT_BIN:-$(xcrun --find swift)}"

"$SWIFT_BIN" "$ROOT_DIR/script/generate_codex_pet_spritesheet.swift" \
  --standing-image "$ROOT_DIR/Assets/ChibiAssistant/generated/standing-orientations/standing-orientations-sheet.png" \
  --standing-json "$ROOT_DIR/Assets/ChibiAssistant/generated/standing-orientations/standing-orientations-sheet.json" \
  --sitting-image "$ROOT_DIR/Assets/ChibiAssistant/generated/sitting-orientations/sitting-orientations-sheet.png" \
  --sitting-json "$ROOT_DIR/Assets/ChibiAssistant/generated/sitting-orientations/sitting-orientations-sheet.json" \
  --output "$OUTPUT_SPRITESHEET"

read -r WIDTH HEIGHT < <(/usr/bin/sips -g pixelWidth -g pixelHeight "$OUTPUT_SPRITESHEET" 2>/dev/null | awk '/pixelWidth/{w=$2} /pixelHeight/{h=$2} END{print w, h}')

if [[ "$WIDTH" != "1536" || "$HEIGHT" != "1872" ]]; then
  printf 'error: expected 1536x1872 spritesheet, got %sx%s\n' "$WIDTH" "$HEIGHT" >&2
  exit 1
fi

if [[ "$MODE" == "build-only" ]]; then
  printf 'Built Codex Lumi pet spritesheet: %s\n' "$OUTPUT_SPRITESHEET"
  exit 0
fi

mkdir -p "$GENERATED_ASSET_DIR"
cp "$OUTPUT_SPRITESHEET" "$GENERATED_ASSET"

mkdir -p "$PET_DIR"
cp "$OUTPUT_SPRITESHEET" "$PET_DIR/spritesheet.png"
printf '%s\n' '{"displayName":"Lumi","description":"Lumi standing and sitting sprites for the Codex desktop pet.","spritesheetPath":"spritesheet.png"}' > "$PET_DIR/pet.json"

NODE_BIN="${NODE_BIN:-}"
if [[ -z "$NODE_BIN" ]]; then
  for CANDIDATE in "/Applications/Codex.app/Contents/Resources/cua_node/bin/node" "$(command -v node || true)"; do
    if [[ -n "$CANDIDATE" && -x "$CANDIDATE" ]]; then
      NODE_BIN="$CANDIDATE"
      break
    fi
  done
fi

if [[ -z "$NODE_BIN" ]]; then
  printf 'error: could not find node to update Codex persisted state\n' >&2
  exit 1
fi

mkdir -p "$(dirname "$STATE_FILE")"
if [[ -f "$STATE_FILE" ]]; then
  cp "$STATE_FILE" "$STATE_FILE.bak"
fi

STATE_FILE="$STATE_FILE" "$NODE_BIN" <<'NODE'
const fs = require("fs");
const path = process.env.STATE_FILE;

let state = {};
if (fs.existsSync(path)) {
  const raw = fs.readFileSync(path, "utf8").trim();
  state = raw.length ? JSON.parse(raw) : {};
}

const atomStateKey = "electron-persisted-atom-state";
const atomState = state[atomStateKey] && typeof state[atomStateKey] === "object" ? state[atomStateKey] : {};
atomState["selected-avatar-id"] = "custom:lumi";
state[atomStateKey] = atomState;

fs.writeFileSync(path, `${JSON.stringify(state)}\n`);
NODE

printf 'Installed Lumi as Codex desktop pet: custom:lumi\n'
printf 'Spritesheet: %s\n' "$PET_DIR/spritesheet.png"
printf 'Codex state: %s\n' "$STATE_FILE"
