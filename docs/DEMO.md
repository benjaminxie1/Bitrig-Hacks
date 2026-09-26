# RABBITHELPER ink demo

Build the RABBITHELPER target in Bitrig. Swift 6, iOS 27.1, no third-party dependencies.
The original Burrow art, sprite player, scene, nine-slice controls, pose providers,
and BunnyBrain structure are preserved. The active interface uses PencilKit work
instead of typed answers. The flat facing page uses Claude’s in-app homework tab. The bundled Riverside
“Show your work” page supplies the equation, while the leading paper holds the ink.

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

## Code-freeze verification — September 26, 2026

The integrated RABBITHELPER build passed in Bitrig. No app code was changed during
this verification. All 27 Swift tests passed after the web integration.

Verified in the Duo simulator:

- Flat: Riverside “Show your work” loads and the status reads “Found 3x + 5 = 20”.
  The page's working textarea, label, check button, and feedback are hidden by the
  bundled-page stylesheet. The paper tools remain beside the leading page.
- Live flat-to-book transition: the paper stays fixed, Bunny arrives beside the
  wrong line, the ring surrounds 25, a nudge appears, and the stage retains the equation.
- Ordered replay in book: p1-a-mistake is followed by p1-b-fix. The second take starts
  with the page and ring intact, then clears the ring and reaches the solved message.
- Closed outer display: the retained work, equation, Bunny message, and “Open me up
  to keep writing” fit without overlap. The work is read-only.
- Launch with -recording: the address is text, not a text field; tapping it does not
  raise a keyboard. The first hidden tap plays the mistake. Both hidden taps were
  also exercised end to end with -recording -pose book, confirming continuation and
  the final ring clearing in the recording backup layout.
- Offline resource audit: working.html loads local demo.css and demo.js. These
  resources contain no external URLs or network-request APIs. Recording mode
  starts on the bundled file and rejects non-file/about navigation. This is a
  source/resource check, not a packet capture of WebKit's separate processes.

Simulator caveat: after a direct simctl relaunch, Bitrig's fold controls sometimes
stopped reaching the running app. A managed build restored live fold testing.
The live physical transition was tested separately from the recording-mode
book fallback. Direct Device Hub automation is still unavailable; these checks
used Bitrig's Duo simulator. The user separately confirmed the app in Device Hub.

Prior checks covered live mouse erasing/rewriting, Vision recognition of the fixed
line and solved answer, tabletop layout, and recording-script Ctrl+C/movie playback.
The App Resizability audit corrected short-window clipping and mid-stroke resizing.
Actual Split View and accessibility-size visual checks remain outside this final
four-check acceptance pass.

## Source/API notes

The iOS 27.1 SDK matched the requested reservedRegions, includeInactive,
onHingeChange, optional hinge, status, and Angle signatures. No signature discrepancy.
The source rabbit has no dedicated pointing state; it faces the fold using its
existing listening/watch art. InkJudgement's upstream wire shape includes
confidence; rung belongs to the input/session, not the verdict. Scripted nudges
follow the server prompt's stricter wording rules.

References: jerryjlwang/Burrow (original art, steps, ink contract and InkCoach),
artemnovichkov/iPhone-Duo-by-Examples (fold API examples). No tools/pet/become art.
