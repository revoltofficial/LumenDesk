# Validation record

Date: 13 October 2026. Status: source prototype, not a verified executable.

| Check | Result |
|---|---|
| App Info.plist syntax | Passed with macOS plutil |
| Build script syntax | Passed with zsh syntax check |
| Swift compilation | Blocked: invalid active developer path; xcrun missing |
| Six XCTest tests | Written, not run; same compiler blocker |
| Native interface rendering | Not run |
| Receiver/hardware output | Not run |
| ArtDMX field layout review | Compared with official specification; no wire capture |

Source review corrected the display universe range to 1–32768, mapped it to wire addresses 0–32767, made stage previews use rendered output, rejected duplicate IDs and overlapping channels, capped show-file loads, versioned the project schema, used monotonic time for fades, and let final dark packets drain before cancellation.

This review does not establish that the Swift source compiles. The sender is an ArtDMX unicast prototype: ArtPoll/subscriber discovery, bound source-port behavior, ArtPollReply handling, refresh negotiation, network recovery and full Art-Net controller conformance remain work items. The [official Art-Net specification](https://art-net.org.uk/downloads/art-net.pdf) requires subscription-aware transmission. A configured IP and correct packet bytes alone do not satisfy all controller requirements.

Before hardware use: compile/tests, inspect the native interface, receive packets on a simulator, verify byte order, sequencing, universe mapping and refresh rate, then verify blackout, cue interruption, destination changes, stopped output and receiver timeout behavior on a dedicated node.

## Cloud build — 2026-10-13

GitHub Actions run 38427549376 compiled the arm64 app successfully on macOS 15.7.9. All six XCTest tests passed. Release packaging and ad-hoc signature verification succeeded. The downloaded app also passed local codesign verification. UI and physical lighting output remain untested.

Build: https://github.com/revoltofficial/LumenDesk/actions/runs/38427549376

## Workspace update — 2026-10-13

GitHub Actions run 38428995234 compiled commit ea09a2bb6e7d2086a772f9e4c4696692f6f9bc59 successfully. All eight XCTest tests passed. Release packaging and downloaded ad-hoc signature verification passed. The app opened through native app control; shell launch failed in the restricted environment.

Local UI checks: Design layout rendered; Live buttons and cue-list views opened; Go Next activated the first cue then the second, disabled at the end, and the stage settled to 70% for Blue scene. Effect controls and patch/output sheet opened. Preview-only status remained visible throughout; no physical lighting output was started.

Build: https://github.com/revoltofficial/LumenDesk/actions/runs/38428995234

## Sequence update — 2026-10-13

Build 38430129557 compiled commit b5b791b34f30278e9bcd29f12c14c78c33ef5df3 for Apple Silicon. All 14 XCTest tests passed; the downloaded app passed signature verification. Local UI checks confirmed Run, Pause (53.3 seconds remained fixed across observations), Resume (countdown continued), and Stop (sequence controls reset and all preview fixtures reached 0%). Art-Net output stayed off. Hardware output remains untested.

Build: https://github.com/revoltofficial/LumenDesk/actions/runs/38430129557

## Fixture groups — 2026-10-13

Final build 38433123861 compiled commit 14713a5266db1c82310c37032fe2e2604385b1d5. All 18 tests passed. Local checks confirmed the Multi-select toggle adds fixtures; different RGB values display Mixed; changing Dimmer updates the selected three fixtures to 70%; saving Front lights stores three members; Clear followed by group recall restores all three. Group editor checkboxes and color favorites were also checked on the preceding group build. Output stayed off.

The delivered app uses local.lumendesk.groups as its bundle identifier so it can open alongside earlier prototypes. It was ad-hoc re-signed locally after this metadata change and passed codesign verification. Native automation did not confirm modifier-key selection; the visible Multi-select toggle is the verified interaction. Fixture movement still affects one fixture at a time. Hardware output remains untested.

Build: https://github.com/revoltofficial/LumenDesk/actions/runs/38433123861

## Presets and layered cues — 2026-10-13

Build 38435473635 compiled commit 87aaa61d551b7502e6cc06e929014cb9e07bf775 successfully. All 25 tests passed, including seven new tests for sparse channels, priority, release, fade endpoints, fixture isolation, effect override/release, manual takeover, Stop, concurrent scene sequences, persistence, legacy files, fixture deletion, and invalid references/values. The initial test build exposed floating-point fade endpoint rounding; completed fades now return exact target values.

Local app checks confirmed capture of a color preset and an intensity preset; layered cue composition and storage; color activation and release restoring the underlying blue scene; and simultaneous color/intensity overlays. With both layers active, Wash 1 showed captured red RGB values at 22% intensity while the other five fixtures remained blue at 70%. Output remained off. The native Save dialog wrote Layered-cues-demo.lumendesk.json, and its JSON contains the two expected preset types and layer definitions. Active playback is intentionally not saved.

The delivered app uses local.lumendesk.layers so it can coexist with earlier prototypes, and was ad-hoc re-signed and verified after that metadata change. Fade-in applies to level channels over the changing underlying look; effects and releases switch immediately. Hardware output and long-duration behavior remain untested.

Build: https://github.com/revoltofficial/LumenDesk/actions/runs/38435473635

## Moving heads — 2026-10-13

Build 38439002849 compiled ae11bf21ee9010f3307ab95f35421038a190d059 for Apple Silicon and passed all 34 tests. Nine moving-head tests cover exact 16-bit byte order and quantization, reversed/custom channel ranges, overlapping fine-channel rejection, neutral/quarter-turn floor projection, above-horizon suppression, beam-angle footprint, absolute 540-degree travel, discrete gobo changes, legacy state defaults, profile persistence, cue/preview/output synchronization, blackout preserving movement, patch bounds, position presets, and motion-effect fixture isolation.

Local checks on that build confirmed adding the two-head demo (8 fixtures, heads patched at 19 and 30 with 11-channel footprints), changing from the left to right four-second cue with intermediate pan/tilt readings and moving head/beam geometry, tilt 127.4 degrees removing Head 1’s floor beam while Head 2 remained visible, Aim forward restoring the beam, zoom 28.8 degrees to 8 degrees shrinking its floor spot, and gobo Star being displayed from the cue. Importing the supplied example profile added Example Moving Head · 11ch to the library. The prior Layered-cues-demo.lumendesk.json loaded successfully, with six fixtures. All checks kept Art-Net output off. Moving-heads-demo.lumendesk.json was saved and inspected: eight fixtures, two profile snapshots and four cues including both movement sweeps.

The preview is a schematic hanging-mount floor projection with original gobo shapes, not motor/photometric simulation. Real fixture mapping, mechanical lag, orientation calibration and hardware output remain unverified. Preview and output use the same rendered attributes; 16-bit output quantization can differ from continuous preview by at most half an encoded step.

Build: https://github.com/revoltofficial/LumenDesk/actions/runs/38439002849

## Final moving-head delivery — 2026-10-13

Build 38441313892 compiled commit 5e44f1c8f32f181a67cacccf5453fed0cad187cf on the standard macOS 26 Apple Silicon runner. All 36 XCTest tests passed, including legacy-show orbit availability and Stop preserving the rendered position with movement effects. Release packaging passed. The downloaded arm64 app was assigned the local delivery bundle identifier local.lumendesk.movingheads and ad-hoc re-signed; strict deep signature verification passed.

The final app launched on the user's macOS 15.6.1 machine. The saved moving-head demo opened with eight fixtures. The compact Color/Position/Beam tabs displayed correctly. Activating Heads · left showed intermediate pan/tilt and settled at pan -37.8 degrees, tilt 40.5 degrees. Stop darkened all eight fixtures while leaving both glyph poses and those pan/tilt values unchanged. The demo was left open with Art-Net output off. Real fixtures, mechanical response and photometric accuracy remain untested.
