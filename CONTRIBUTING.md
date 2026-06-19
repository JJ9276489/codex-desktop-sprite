# Contributing to Codex Desktop Sprite

## Development Setup

```bash
git clone https://github.com/jeraldhu-yuan/codex-desktop-sprite.git
cd codex-desktop-sprite
./script/build_and_run.sh   # build and launch
./script/test.sh            # run tests
```

Requirements: macOS 14+ and the Xcode Command Line Tools. The project has no third-party dependencies.

## Guidelines

- Keep the app a thin UI over Codex `app-server`; do not rebuild a second agent runtime here.
- Keep runtime sprite assets limited to the standing and sitting Lumi orientation sheets unless a new sheet is explicitly needed.
- Keep wire-format and status formatting testable outside AppKit.
- Tests must pass before pushing.
- Keep the direct `swiftc` fallback working; it is part of the local reliability story.

## Useful Commands

```bash
./script/test.sh
./script/build_and_run.sh --build
./script/build_and_run.sh --verify
```
