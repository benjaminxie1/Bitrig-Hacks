# RABBITHELPER ink demo

Build the RABBITHELPER target in Bitrig. Swift 6, iOS 27.1, no third-party dependencies.
The original Burrow art, sprite player, scene, nine-slice controls, pose providers,
and BunnyBrain structure are preserved. The active interface uses PencilKit work
instead of typed answers. Browser integration is owned by Claude and is a separate
handoff; the replay implementation does not depend on it.

## Recording sequence

1. Open the Duo fully, with the inner display wide and the division vertical.
2. In recording mode, tap the **top-left 44 × 44 points of the paper**. This plays
   `p1-a-mistake`: the original equation, then an arithmetic slip on line two.
3. Wait for Bunny's invitation, then choose **Partially Open**. The paper stays
   at the same size and position. Bunny dives, arrives beside the wrong line,
   draws the ring, and gives a nudge without supplying the correction.
4. Tap the same hidden paper corner again. This plays `p1-b-fix`. Its `continues`
   field points to `p1-a-mistake`. The document and diagnosis stay intact; the ring
   remains through the incomplete erased line, clears at the corrected-line
   checkpoint, and Bunny celebrates at the solved checkpoint.
5. Unfold or close. The work and conversation persist. Closed is read-only and
   says “Open me up to keep writing.”

The next hidden tap cycles back to the mistake. Taps during replay are ignored.
A continuation is allowed only after its predecessor completes, on an unedited
page. Drawing, erasing, or undoing invalidates ground truth. A mismatched replay
starts a fresh page. Named problem takes are ordered by ID; generic sample
assets remain separately selectable in the debug menu.

Outside recording mode, triple-tap the RABBITHELPER header. **Replay ink** uses
that same sequence. The menu also offers individual samples, **Record ink**,
**Stop recording ink**, **Reset demo**, and simulated poses. Recording mode hides
that menu/gesture, selects day art, seeds sprite randomness, uses deterministic
clock steps, and defaults voice off. Text always carries the spoken content.

## Live work and capture

Pen, eraser, and undo sit beside the paper. PencilKit accepts mouse/finger input.
After about 1.5 seconds of stillness, Vision reads a white, light-trait rendering
of the work. The algebra judge skips an unfinished last line and refuses to mark
low-confidence recognition as wrong. Reviewed sidecars override OCR for bundled
items only. Photos can be imported with the system picker.

Record ink saves normalized PKDrawing snapshots and timing to the app's Documents/
InkRecordings directory. Each recording has a .pkdrawing and .ink.json. Review
its transcript and token boxes, set verified only after review, then use
scripts/bundle-ink.py to bundle it. Unreviewed OCR is never promoted to ground truth.
The five current sidecars include the two p1 takes and three generic samples.

## Simulator controls and movies

Verified in Bitrig's Duo simulator:

- **Fully Open**, wide inner display: flat paper and facing problem.
- **Partially Open**, wide inner display: book, vertical division.
- **Rotate Right** while partially open: tabletop, horizontal division; work
  scales uniformly into the bottom region and Bunny occupies the top.
- **Closed**: compact outer display, read-only work.

The app derives placement from fresh active/inactive reserved regions, never
orientation or hinge angle. Actual hinge samples arrived at irregular intermediate
angles; cosmetic effects are smoothed. Inactive horizontal divisions retain a
bottom work page while flat to keep it anchored to the future fold.

Run scripts/record.sh after the final build. Optionally pass the built .app path,
set SIMULATOR_UDID, or choose POSE=book for a simulated-pose backup. The script
boots a Duo, installs RABBITHELPER, applies 9:41/full battery/full signal independently,
and launches with -recording. Unsupported status-bar flags are skipped.

**DISPLAY_ID=3** records the inner display (default); **DISPLAY_ID=1** records the
outer display in a separate take. This runtime rejected concurrent capture of
both displays. Ctrl+C finalizes the movie and clears the status-bar override.
Output defaults to ignored recordings/. Use RECORDINGS_DIR to choose another folder.
Inactive display surfaces can produce black video, so open the corresponding panel.

## Verification at replay handoff

- Bitrig build passed after the replay changes and rename.
- 27 Swift tests passed: upstream step-judge cases, OCR normalization, uncertain
  and incomplete work, token targeting, nudge constraints, normalized page layout,
  all five sidecars, ID order, continuation metadata, original pose/brain/player tests.
- Prior simulator verification covered fold reveal, live mouse erasing/rewriting,
  ring clearing, recognition of the solved final line, tabletop and closed layouts.
- The latest build visually confirmed tools beside the paper. The new p1 replay
  sequence passed model/sidecar tests; its final UI retest was interrupted by the
  browser handoff changing project files. Do not mistake that for a recorded take.
- App Resizability audit corrected short-window clipping and mid-stroke resizing.
  Actual Split View and accessibility-size visual checks remain outstanding.
- Recording script Ctrl+C/movie playback passed for an outer-display take before
  the rename; the app-discovery path now uses RABBITHELPER.app.
- Direct Device Hub automation repeatedly timed out. Live fold checks above used
  Bitrig's built-in simulator; the user confirmed the app in Device Hub separately.

## Source/API notes

The iOS 27.1 SDK matched the requested reservedRegions, includeInactive,
onHingeChange, optional hinge, status, and Angle signatures. No signature discrepancy.
The source rabbit has no dedicated pointing state; it faces the fold using its
existing listening/watch art. InkJudgement's upstream wire shape includes
confidence; rung belongs to the input/session, not the verdict. Scripted nudges
follow the server prompt's stricter wording rules.

References: jerryjlwang/Burrow (original art, steps, ink contract and InkCoach),
artemnovichkov/iPhone-Duo-by-Examples (fold API examples). No tools/pet/become art.
