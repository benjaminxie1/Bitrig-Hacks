# RabbitHelper (Burrow for iPhone Duo)

Work-in-progress snapshot for the iPhone Duo hackathon. Pushed mid-build so the team can follow along; not everything here is finished or verified.

## What's where

| Path | What it is |
|---|---|
| `App/`, `Tests/`, `Project.json`, `Package.swift` | The main app, built in Bitrig. SwiftUI, iOS 27.1, iPhone Duo APIs (reserved regions + hinge). |
| `App/Ink/` | **In progress:** handwritten work page (PencilKit), Vision OCR, ported step judge, chalk ring, ink record/replay. Not fully wired into the UI yet. |
| `docs/DEMO.md` | Demo/rehearsal guide, API findings, and what is still unverified. |
| `scripts/record.sh` | Boots the Duo simulator, clean status bar, launches with `-recording`, records both displays (inner = display 3, outer = display 1). |
| `demo-ink/` | Generated handwriting for the demo (`p1-a-mistake`: `3x + 5 = 20` → `3x = 25` sign slip; `p1-b-fix`: erase 25, write 15, then `x = 5`). Each has an `.ink.json` sidecar (InkDemoAsset format: timed normalized PKDrawing frames + ground-truth lines/token boxes), a `.pkdrawing`, PNG previews, and GIFs. Regenerate with `swiftc -O make_ink.swift -o make_ink && ./make_ink out`. |
| `prototypes/claude-native/` | An earlier typed-answer prototype (number pad version). Superseded by the ink direction; kept for reference only. |

## Status

- Done: poses (flat / tabletop / book / closed) from reserved regions, sprite player + jump sequence, struggle levels and hint ladder, recording/debug modes, 8 core tests.
- In progress: ink page, fold-to-reveal choreography in book pose, closed read-only view, photo import, record/replay menu.
- Unverified: the full demo take on Device Hub's inner display.

Art, fonts and hint design come from [Burrow](https://github.com/jerryjlwang/Burrow) (HackMIT). Duo API patterns from [iPhone Duo by Examples](https://github.com/artemnovichkov/iPhone-Duo-by-Examples) (MIT).
