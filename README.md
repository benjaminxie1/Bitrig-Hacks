# RabbitHelper (Burrow for iPhone Duo)

Work-in-progress snapshot for the iPhone Duo hackathon. Pushed mid-build so the team can follow along; not everything here is finished or verified.

## What's where

| Path | What it is |
|---|---|
| `App/`, `Tests/`, `Project.json`, `Package.swift` | The main app, built in Bitrig. SwiftUI, iOS 27.1, iPhone Duo APIs (reserved regions + hinge). |
| `App/Ink/` | Handwritten work page (PencilKit), Vision OCR, ported step judge, chalk ring, fold-to-reveal, ordered ink replay (`InkReplaySequence`). |
| `App/Web/` | Homework web tab: the bundled Riverside Learning "Show your work" page (`App/Resources/WebDemo/`), equation extraction (`LinearEquation`), read-only. |
| `docs/DEMO.md` | Demo/rehearsal guide, API findings, and what is still unverified. |
| `scripts/record.sh` | Boots the Duo simulator, clean status bar, launches with `-recording`, records both displays (inner = display 3, outer = display 1). |
| `demo-ink/` | Generated handwriting for the demo (`p1-a-mistake`: `3x + 5 = 20` → `3x = 25` arithmetic slip (20 − 5 written as 25); `p1-b-fix`: erase 25, write 15, then `x = 5`). Each has an `.ink.json` sidecar (InkDemoAsset format: timed normalized PKDrawing frames + ground-truth lines/token boxes), a `.pkdrawing`, PNG previews, and GIFs. Regenerate with `swiftc -O make_ink.swift -o make_ink && ./make_ink out`. |
| `prototypes/claude-native/` | An earlier typed-answer prototype (number pad version). Superseded by the ink direction; kept for reference only. |

## Status (2:10 PT)

- Done: flat / book / tabletop / closed poses from reserved regions; ink page with fold-to-reveal, chalk ring that clears when the line is fixed, celebrate on solve; ordered demo ink replay (p1-a-mistake → p1-b-fix); homework web tab wired into the flat layout; recording/debug modes.
- Verified in Bitrig's simulator: the book-pose ink loop (reveal, erase and rewrite, ring clearing, solved).
- Just landed, being checked: the web tab in the running app.
- App is now named RABBITHELPER (bundle id unchanged).

Art, fonts and hint design come from [Burrow](https://github.com/jerryjlwang/Burrow) (HackMIT). Duo API patterns from [iPhone Duo by Examples](https://github.com/artemnovichkov/iPhone-Duo-by-Examples) (MIT).
