# Sprite Asset Boundary

Codex Desktop Sprite uses only the Lumi standing and sitting orientation sheets:

- `Assets/ChibiAssistant/generated/standing-orientations/standing-orientations-sheet.png`
- `Assets/ChibiAssistant/generated/sitting-orientations/sitting-orientations-sheet.png`

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
