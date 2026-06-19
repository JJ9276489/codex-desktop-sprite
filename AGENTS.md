# Codex Desktop Sprite Engineering Notes

This repo is intentionally back to a small Codex Desktop Sprite app.

- Keep `Sources/CodexSprite` as the only app source tree.
- Do not reintroduce the standalone Lumi agent log, dreaming, memory consolidation, local voice, Claude Code backend, or diary UI.
- The supported agent path is Codex `app-server`; this app is only a desktop sprite and prompt shell.
- Runtime art should stay limited to Lumi's standing and sitting orientation sheets unless the user explicitly asks for more.
- For Codex Desktop's built-in pet, use `./script/install_codex_lumi_pet.sh`; it installs a Codex-compatible custom pet under `~/.codex/pets/lumi` and selects `custom:lumi` without patching `/Applications/Codex.app`.
- Use `./script/test.sh` and `./script/build_and_run.sh --build` before pushing.
