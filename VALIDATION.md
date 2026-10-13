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
