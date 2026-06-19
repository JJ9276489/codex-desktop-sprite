# Sprite Asset Boundary

Codex Desktop Sprite uses only the Lumi standing and sitting orientation sheets:

- `Assets/ChibiAssistant/generated/standing-orientations/standing-orientations-sheet.png`
- `Assets/ChibiAssistant/generated/sitting-orientations/sitting-orientations-sheet.png`
- `Assets/ChibiAssistant/generated/codex-pet/codex-lumi-spritesheet.png`

Each sheet is a 5-column by 2-row grid of 256 px frames. The matching JSON manifests document the frame order:

1. front neutral
2. front blink
3. gaze up right
4. gaze up
5. gaze up left
6. gaze right
7. gaze down right
8. gaze down
9. gaze down left
10. gaze left

The old Lumi expression, action, sleep/wake, voice, memory, and dream artifacts are intentionally not part of the maintained runtime. If a future sprite state needs more art, add only the minimum new sheet and document why it is needed.

## Codex Desktop Custom Pet

Codex Desktop custom pets use a fixed 1536 x 1872 grid: 8 columns, 9 rows, and 192 x 208 px frames. The generated Lumi custom pet adapts only the maintained standing and sitting sheets into that grid.

Build and install it with:

```bash
./script/install_codex_lumi_pet.sh
```

That writes:

- `~/.codex/pets/lumi/pet.json`
- `~/.codex/pets/lumi/spritesheet.png`

It also sets Codex's persisted `selected-avatar-id` to `custom:lumi`. If Codex is already running, relaunch Codex or refresh the Pets settings for the running app to pick up the new selected pet.
