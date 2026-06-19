# Codex Desktop Sprite

[![CI](https://github.com/jeraldhu-yuan/codex-desktop-sprite/actions/workflows/ci.yml/badge.svg)](https://github.com/jeraldhu-yuan/codex-desktop-sprite/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
![macOS 14+](https://img.shields.io/badge/macOS-14%2B-black)

Codex Desktop Sprite is a small macOS desktop companion for the supported Codex app-server path. The app keeps a lightweight sprite on the desktop, opens a compact prompt window when clicked, and sends requests to Codex in the configured workspace.

This repository intentionally does **not** maintain the old standalone Lumi agent stack. The memory, dreaming, voice, multi-provider orchestration, and append-only agent-log experiments were removed so this project can stay a thin UI over Codex instead of a second agent runtime.

## What It Does

- Shows a draggable desktop-level sprite that stays on the current desktop.
- Uses Lumi's better standing and sitting sprite sheets for the visible character.
- Can install Lumi as Codex Desktop's built-in custom pet so the supported Codex pet overlay uses Lumi art.
- Tracks cursor gaze continuously while standing or sitting.
- Sits after idle time and stands for prompt/working states.
- Shows the small speech/thought bubbles from the original Codex sprite path.
- Opens a prompt window on click.
- Starts a Codex `app-server` thread rooted in the configured workspace.
- Streams Codex response text into the prompt panel.
- Supports follow-up prompts with `thread/resume`.
- Includes a `New Thread` action to clear the active Codex thread.
- Opens Codex Desktop for the configured workspace.

## Requirements

- macOS 14 or later
- Xcode Command Line Tools
- Codex Desktop app at `/Applications/Codex.app` or a standalone `codex` binary

The app has no third-party dependencies.

## Install And Run

```bash
git clone https://github.com/jeraldhu-yuan/codex-desktop-sprite.git
cd codex-desktop-sprite
./script/build_and_run.sh
```

The build script stages `dist/CodexSprite.app`. It tries SwiftPM first and falls back to a direct `swiftc` build because the app is dependency-free.

## Configuration

All settings are environment variables read at launch.

| Variable | Default | Description |
|---|---|---|
| `CODEX_SPRITE_WORKSPACE` | `~/CODEX - DIGITAL ASSISTANT TASKS` | Working directory for Codex turns |
| `CODEX_SPRITE_CODEX_PATH` | auto-detected | Path to the Codex binary |
| `CODEX_SPRITE_SANDBOX` | `workspace-write` | Codex sandbox mode |
| `CODEX_SPRITE_APPROVAL_POLICY` | `on-request` | Codex approval policy |

Example:

```bash
CODEX_SPRITE_WORKSPACE="/path/to/workspace" \
CODEX_SPRITE_CODEX_PATH="/Applications/Codex.app/Contents/Resources/codex" \
./script/build_and_run.sh
```

## Development

| Command | Description |
|---|---|
| `./script/build_and_run.sh` | Build, stage `dist/CodexSprite.app`, and launch |
| `./script/build_and_run.sh --build` | Build and stage only |
| `./script/build_and_run.sh --verify` | Build, launch, and assert the process is running |
| `./script/install_codex_lumi_pet.sh` | Build, install, and select Lumi as Codex Desktop's built-in custom pet |
| `./script/install_codex_lumi_pet.sh --build-only` | Build and validate the Codex custom-pet spritesheet only |
| `./script/test.sh` | Run the focused test harness |
| `./script/summon.sh` | Relaunch the staged app without rebuilding |

The test harness covers version/config, Codex status formatting, and the retained stand/sit asset manifests. CI runs build and tests on macOS.

## Architecture

```text
Sources/CodexSprite/main.swift                  AppKit entrypoint
Sources/CodexSprite/AppConfig.swift             launch configuration and version
Sources/CodexSprite/AppDelegate.swift           app glue between sprite, prompt, and Codex
Sources/CodexSprite/SpriteWindowController.swift desktop sprite window, gaze, stand/sit rendering
Sources/CodexSprite/PromptWindowController.swift prompt and response panel
Sources/CodexSprite/CodexAppServerClient.swift  JSON-RPC app-server adapter
Sources/CodexSprite/CodexStatusFormatter.swift  UI-safe Codex status text mapping
```

Runtime sprite assets are intentionally limited to:

- `Assets/ChibiAssistant/generated/standing-orientations/standing-orientations-sheet.png`
- `Assets/ChibiAssistant/generated/sitting-orientations/sitting-orientations-sheet.png`
- `Assets/ChibiAssistant/generated/codex-pet/codex-lumi-spritesheet.png`

See [docs/ASSETS.md](docs/ASSETS.md) for the asset boundary.

## Codex Desktop Built-In Pet

Codex Desktop supports custom pets from `~/.codex/pets`. To replace the default Codex pet with Lumi without patching the signed Codex app bundle:

```bash
./script/install_codex_lumi_pet.sh
```

The installer generates Codex's required 1536 x 1872 spritesheet from the maintained Lumi stand/sit sheets, writes `~/.codex/pets/lumi`, and selects `custom:lumi` in Codex's persisted state. If Codex is already running, relaunch Codex or refresh the Pets settings for the change to appear in the overlay.

## Known Limits

- Interactive input prompts, MCP elicitations, and dynamic tool calls are not yet handled inside the sprite UI. Open Codex Desktop if a turn needs those.
- The Codex app-server protocol is experimental.
- Thread deep-linking into Codex Desktop is not implemented; the `Open Codex` button opens the configured workspace.
- Local builds are ad-hoc signed for bundle integrity, but they are not Developer ID signed or notarized.

## License

[MIT](LICENSE)
