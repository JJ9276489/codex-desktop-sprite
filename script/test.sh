#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

mkdir -p .build

xcrun swiftc -swift-version 5 \
  Sources/CodexSprite/AppConfig.swift \
  Sources/CodexSprite/CodexStatusFormatter.swift \
  Tests/TestRunner/main.swift \
  -o .build/codex-sprite-tests

.build/codex-sprite-tests
./script/install_codex_lumi_pet.sh --build-only >/dev/null
