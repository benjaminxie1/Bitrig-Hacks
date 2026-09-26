# Burrow demo

Native SwiftUI, Swift 6, iOS 27.1, no package dependencies and no network calls.
Build and run the Burrow target in Bitrig. Project settings are owned by
Project.json; fonts and JSON are bundled from App/Resources.

## Recording

Run scripts/record.sh after building. An optional first argument selects a
different built Burrow.app. SIMULATOR_UDID selects an existing Duo.

The script boots a 27.1 Duo, installs the app, applies 9:41/full battery/full
signal options independently, and launches with -recording. Unsupported
status-bar options are reported and skipped. Ctrl+C finalizes the movies and
clears the status-bar override. Output goes to ignored recordings/.

Duo exposes two separate capture surfaces: **3 is the inner display** and
**1 is the outer display** in this SDK/runtime. A default capture can be black
when it targets the inactive inner panel. The script records both panels
simultaneously; use the inner movie for steps 1–6 and the outer movie for the
closing shot. It does not stitch them into one movie. The UUID is
used instead of ambiguous "booted" when other simulators are running.
INNER_DISPLAY and OUTER_DISPLAY can override those surface IDs.

Recording mode hides the triple-tap debug gesture, starts a fresh practice
session, fixes the random seed and timer steps, selects day art, and disables
voice initially. Every spoken line remains visible as text.

## Rehearsal

1. Open flat. Enter **3**, Check; enter **7**, Check. A new digit replaces a
   checked answer, so no backspacing is required.
2. Watch the glance, question mark, and offer. Bunny suggests folding.
3. Partially fold with a **horizontal** division. Bunny dives and receives on
   the top stage. The first nudge marks the + 5 term in the problem.
4. Tap **Another hint**.
5. Enter **5**, Check. Bunny celebrates.
6. Unfold. After the return animation, the second problem loads.
7. Close. The conversation and current input survive the display change.

The simulator controls observed in Bitrig are **Closed**, **Partially Open**,
**Fully Open**, **Rotate Right**, **Seated**, and **Standing**. Fully Open
selects flat; Closed selects compact; Partially Open selects book when the
division is vertical and tabletop when horizontal. Rotate Right changes the
division's axis. The app itself never derives pose from orientation or angle.
These are verified control labels, not a claim that the complete sequence was
successfully exercised in Device Hub.

Outside recording mode, triple-tap **burrow** to select any fallback pose,
return to the device pose, or reset the demo. Launch overrides also work:

    -pose flat
    -pose tabletop
    -pose book
    -pose closed

POSE=tabletop scripts/record.sh records a fallback pose. Omit POSE for the
live device. Previews are provided through this runtime pose selector rather
than #Preview, following this project's Bitrig coding rules.

## Implementation

- App/Pose: live/simulated providers, pure pose derivation, smoothed cosmetic
  hinge progress. Reserved regions are queried fresh in the root view.
- App/Design: source color tokens, pixel button style, region rectangles,
  asymmetric occlusion avoidance.
- App/Art: original manifest decoding, frame cropping, independent blink
  and mouth overlays, nine-slice chrome, layered Wonderland scene.
- App/Models: practice input, per-problem wrong counts, struggle signals,
  staged interventions, cooldown/decline handling, per-problem hint ladders,
  shared conversation, and travel state.
- App/Views: safe-area header, workspace, keypad, guide brackets/paw,
  speech bubbles, stage, and compact companion.
- App/Resources/Problems.json: six problems with five hint rungs each.
- Tests: dependency-free Swift Testing checks against the app's own sources.

The source player keeps relative manifest timings. Its jump sequence runs at
2.25× with a short ears-out hold; the automated check verifies the complete
sending/receiving pair is below 1.5 seconds. Feet stay at row 53 in a 64×58
cell. Rabbit/scene scales and guide-art scales are integers.

## API and source findings

Checked the Xcode 27.1 (27A9269) iOS 27.1 SwiftUICore SDK interface:

- GeometryProxy.reservedRegions(kind:options:layoutDirectionBehavior:)
  returns [ReservedRegion].
- ReservedRegion.QueryOptions.includeInactive is available.
- DeviceHingeContext.hinge is optional; DeviceHinge.angle is Angle.
- DeviceHinge.Status supplies .closed, .partiallyOpen, .fullyOpen.
- View.onHingeChange(isEnabled:_:) supplies old and new contexts.

No API-name/signature discrepancy was found. ContentView and PoseModel
guard the 27.1-only APIs. Shared root coordinates are appropriate here;
foreground content is clipped to regions outside the division.

Art discrepancy: the rabbit manifest has **no dedicated pointing state**.
The implementation uses its watch/listening states, facing the problem, and
the original gold corner brackets plus paw within the problem region.

References reviewed before implementation:

- [Burrow](https://github.com/jerryjlwang/Burrow), revision
  516ff4958cc0d496e604d6806df840c65b78677b: README, shared mock agent/hints,
  proactive signals/engine, pet player/manifests/travel, components and art.
- [iPhone Duo by Examples](https://github.com/artemnovichkov/iPhone-Duo-by-Examples),
  revision 3b9206e11595e0438e3f4d4d280bc234fe816ef8: HingeAngle,
  ReservedRegions, Tabletop, AvoidDivision.

Original PNGs, manifests, CSS and fonts are preserved; the icon is the original
icon128 enlarged with nearest-neighbor sampling. No tools/pet/become assets
were used. Font OFL notices are bundled. The Duo examples are MIT; the reviewed
Burrow revision has no root license file.

## Verification and remaining simulator checks

swift test --parallel: **8 passing tests** covering pose priority, regions
arriving after first layout, asymmetric occlusion, struggle escalation,
cooldown/decline, per-problem ladder boundaries, demo/fraction input, seeded
randomness, and the complete manifest travel sequence.

The Xcode App Resizability skill was applied across all five task categories
and independently rechecked. The launch screen, four orientations and
full-screen opt-out state pass. No global screen/orientation/idiom APIs,
cached safe-area values, or AppDelegate lifecycle assumptions were found.
Scene timer restart, short-window scrolling, and reset pose initialization
were corrected.

The full app has built successfully and the outer layout has been visually
observed in Bitrig. The user confirmed Burrow is visible on Device Hub's inner
screen. Automated Device Hub access repeatedly timed out, simulator commands
stalled, and automated inner-display captures were black.

Consequently, the following remain **unverified**, and should not be treated
as a completed recording acceptance test:

- all live fold/rotate/close transitions and the full seven-step take;
- actual Split View and accessibility-size visual testing;
- whether this simulator emits continuous hinge samples or one jump;
- end-to-end recording-script execution and movie playback.

Raw hinge samples are logged to OSLog subsystem Burrow, category Pose.
Cosmetic effects use time-based smoothing for either sample pattern; pose
placement still uses only the reserved region and size class.
