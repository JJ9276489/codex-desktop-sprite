# Changelog

## 0.7.1 — 2026-06-19

### Added
- Added a reproducible Codex Desktop custom-pet installer that converts Lumi's maintained standing and sitting sheets into Codex's 1536 x 1872 pet spritesheet format.
- Added the generated Lumi Codex pet sheet and documented the `~/.codex/pets/lumi` install path.

### Changed
- Extended the focused test harness to validate Codex custom-pet sheet generation.

## 0.7.0 — 2026-06-19

### Changed
- Restored the project to the supported Codex Desktop Sprite path: a thin AppKit UI over Codex `app-server`.
- Replaced the visible character with Lumi's standing and sitting orientation sheets.
- Simplified sprite behavior to cursor-gaze standing/sitting, click greeting bubbles, drag feedback, and small working thought bubbles.
- Suppressed raw structured Codex status dictionaries such as `activeFlags` in the prompt UI.
- Renamed the app bundle back to `CodexSprite.app` and restored `CODEX_SPRITE_*` configuration.

### Removed
- Removed the standalone Lumi agent runtime: durable Lumi log, memory/dream consolidation, Claude Code backend, local voice, diary window, attachment system, provider orchestration, and expression/action/sleep sprite sheets.
- Removed unused generated sprite scratch assets from the maintained checkout.

### Added
- Added focused tests for version/config, Codex status formatting, and the retained stand/sit asset manifests.
- Added `--build` support for CI/release packaging without launching the GUI.
- Added ad-hoc signing to local bundle staging so `codesign --verify` passes.

## 0.1.0 — 2026-06-06

- Initial MVP: floating Codex sprite with prompt window and Codex `app-server` integration.

## Superseded Lumi-era Releases

Versions `0.3.0` through `0.6.0` grew the project into the standalone Lumi app. That direction is intentionally retired in `0.7.0`; details remain available in git history.
