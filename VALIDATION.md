# Validation record

Date: 14 October 2026. Current status: Apple Silicon executable built, 75 tests passed and native interface checked; real audio capture and hardware output untested. The initial table below records the earlier local compiler blocker.

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

## Per-fixture calibration — 2026-10-13

Build 38442517604 compiled 9f61a72ad2b324d2a0d3be0a03d67b042c205617 successfully. All 39 tests passed, including rotated floor-ray and cone geometry, exact inverted 16-bit bytes, calibration persistence, legacy defaults and invalid rotation rejection. The downloaded delivery app passed strict deep ad-hoc signature verification and launched locally. Native UI checks confirmed separate controls for each head; Head 1 accepted 90-degree rotation and both inversion toggles while Head 2 remained at defaults. Settings were restored to defaults after the check. Art-Net output stayed off. Physical calibration requires hardware verification.

## Custom live board and profile drafts — 2026-10-13

Build 38445531414 compiled b6a27cd0f70ddd5daf35dfac8128b0bea4bd34ac successfully. All 44 tests passed. New tests cover board persistence/layout limits, effect toggle and momentary release, missing targets, blackout position preservation, unsupported momentary scenes and exact provisional fixture profile output bytes. The N-GEAR full-intensity value is 134; channels 8/9 remain zero. Profile drafts validate, and fixed optics expose no zoom/gobo attributes.

The downloaded arm64 app was assigned local.lumendesk.liveboard, ad-hoc signed and verified with strict deep verification, and launched locally. The sample show opened with eight fixtures and the saved custom board. Native checks confirmed Live → Board, headings/buttons, activating Heads · left, Edit board, adding a button, changing its label to Opening look, increasing width to three grid columns, leaving edit mode, and board Blackout/Stop actions. Blackout was reset off and playback stopped. Output remained off. Drag placement and momentary pointer behavior are implemented but have not been verified through native automation. Hardware profile output remains untested; see LIVE-BOARD.md for unresolved mappings.

## Shared tempo — 2026-10-13

Build 38448046782 compiled commit 186d01492362c65b35e978ffda8ea04c2f590447 successfully and passed all 49 tests. New injected-clock tests cover tap averaging/rapid-tap filtering/gap reset, continuous beat position through BPM changes, Sync, full-cycle sine timing, chase fixture progression, saved tempo and legacy defaults, invalid timing rejection and board tempo actions. Release packaging passed. The downloaded arm64 delivery app was assigned local.lumendesk.tempo, ad-hoc signed and passed strict deep signature verification.

Native checks on macOS 15.6.1 confirmed Live BPM/Tap Tempo/Sync and the changing beat indicator, editing BPM from 120 to 100, opening Effects, separate Seconds/Beats selectors and switching Intensity wave to Beats with a four-beat cycle selector. The file picker automation could not complete loading the separate tempo demo; the demo was generated and its JSON inspected, but native demo-load verification is incomplete. After restarting the app, it was left open with the tempo/effects panel and output off. Hardware output and real-time tapping by native automation remain untested.

## Music Autopilot and movement paths — 2026-10-13

Build 38450532346 compiled f2bad2b2b372e443da8cc9b10d3fd9542d6449f6 on the macOS 26 Apple Silicon runner and passed all 56 tests. New tests cover synthetic 120 BPM detection and silence rejection, quieter-section/strong-return classification, drop brightness and travel compared with breaks, distinct Disco/Techno palettes, stale-audio darkness, Master/Blackout/Stop priority, open-path round-trip continuity, custom-path persistence and validation, waveform boundaries and deterministic bounded output from the new effects. Microphone permission metadata and build-script syntax passed local checks.

The downloaded arm64 app was assigned local.lumendesk.autopilot and a distinct delivery executable/display name to avoid input-routing conflicts with the older running builds. Strict deep ad-hoc signature verification passed. Native checks confirmed bottom-left BPM/Tap/Sync/Autopilot controls visible in Design and Live; the Autopilot panel and disabled lighting switch before listening; synthetic demo activation, a Drop state and roughly 120 BPM estimate; Disco style selection; stopping the demo; opening Effects; opening the path editor; changing a numeric pan offset; adding a point; dragging that point (pan changed to -0.36 and tilt to 0.25); resetting/closing the editor; the expanded effect menu and adding Color chase with palette controls. The Autopilot-effects-demo.lumendesk.json loaded successfully with eight fixtures, custom paths and new effect kinds, restoring 120 BPM with Autopilot off. Output stayed off throughout.

Actual microphone capture, recorded-song tempo/structure accuracy, trained genre recognition and real fixture output are not verified. The current Auto style is a tonal heuristic, not a trained AI classifier. Synthetic tests and demo results do not establish live DJ performance.

## Music Director, system audio and manual tempo — 2026-10-14

Build 38458894485 compiled 7ebe62b681ef974d7d6be3b206cdabda4f309750 and passed all 69 tests. Build 38526559436 compiled feed58ee9e3caea1c3e5996c0ec002ef81476c79 and passed all 70 tests; release build and packaging also succeeded. The additional tempo test exercises manual BPM stability during synthetic beat input, fractional one-BPM stepping, boundaries, invalid input and Tap Tempo disabling audio following.

The final downloaded Apple Silicon app was packaged as LumenDesk Director, ad-hoc re-signed locally and passed strict deep signature verification. Native UI checks confirmed +120→121, −121→120 and Follow detected BPM off afterward. The five-fixture template loaded with AYRA/N-GEAR groups and laser controls initially Off. Scan selector listed all six confirmed named patterns. Live Board showed Sound, Automatic, DMX Dynamic, six scan buttons and seven colour buttons. The preceding 69-test build also confirmed the microphone/computer-audio selector and computer-audio permission explanation. No real capture or permission was started. The final app is left with the rig on the live board, audio and output off.

Actual microphone/system-audio capture, musical recognition accuracy, physical fixture output and mechanical response remain unverified. The director is an energy-based heuristic, not a trained song recognizer or drop predictor. NEXT-STEPS.md records the shared-chat priorities and distinguishes proposals from shipped features. Movement changes during effect enable/disable, Sync and Autopilot section changes still require a final position/velocity controller; these are not claimed fixed by this tempo increment.

Build: https://github.com/revoltofficial/LumenDesk/actions/runs/38526559436


## Smooth final motion — 2026-10-14

Build 38529027105 compiled 0f87b361bc2700382ec7d1068ace93076ab6f0bb successfully and passed all 75 XCTest tests. Five new tests cover absolute travel, speed/acceleration bounds, settling, reversals, missed-frame capping, invalid input, effect/Sync/Autopilot target changes, preview/output equality, pure rendering reads, Blackout, Stop parking, fixture removal, interrupted instant cues and saved/legacy settings. The earlier fade-byte test explicitly disables smoothing to keep its exact interpolation/encoding assertions independent of motion dynamics; motion integration and output parity are verified separately.

The downloaded arm64 app was packaged as LumenDesk Motion with a distinct executable and bundle identifier, locally ad-hoc signed and verified with strict deep signature verification. The five-fixture rig opened. Design → Position displayed speed 90, acceleration 180 and current pan/tilt. Speed was temporarily set to 1 degree/second. Increasing the pan slider requested 54 degrees while the controlled-position readout showed 1.2 degrees, confirming gradual travel. Stop later parked at 25.3 degrees. A subsequent observation after restoring speed 90 showed the same parked position; acceleration remained 180. Audio and Art-Net output stayed off.

These checks verify software motion and native controls, not real motors. Physical travel and 8-bit DMX quantization remain hardware test items. Changing inversion while output is live can flip commands; calibration should be performed with output off. This delivery adds motion stability, not a new movement library or trained song recognition. See MOVEMENT.md.

Build: https://github.com/revoltofficial/LumenDesk/actions/runs/38529027105
