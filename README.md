# LumenDesk — native macOS lighting app

Original SwiftUI source prototype, version 0.1. The working name is LumenDesk. It starts with the patch → design → live playback workflow selected by the user. No Lightkey code, fixture library, artwork or saved-show content is shipped with it.

## Current build status

**Source prepared; compilation, automated tests, visual QA and hardware output are unverified.** This Mac has an incomplete Apple Command Line Tools installation. The system Swift launcher cannot run. The direct REA analysis bridge works without those tools; compiling a native Swift app still needs a working Swift compiler and macOS SDK, locally or on another Mac.

## Implemented in source

- Patch generic dimmer (1 channel), RGB (3 channels) and RGBW (4 channels) fixtures within one 512-channel universe. Validate overlaps and footprint bounds.
- Arrange fixtures on a draggable 2D stage plan and adjust intensity/color.
- Capture looks as cues, rename cues, and trigger timed linear fades.
- Apply global sine, chase and rainbow effects, master level and blackout.
- Save/open versioned JSON show files with stable fixture/cue IDs and a 10 MiB load limit.
- Send ArtDMX packets to a configured unicast Art-Net node at a target 30 Hz. Output defaults OFF with a loopback destination. Display universe 1 corresponds to Art-Net port-address 0.

The implementation uses original semantics: cues replace the whole programmer state, unspecified fixtures fade to zero, effects apply globally after cue fades, master affects intensities, and blackout zeros rendered intensity. These choices have not been established as Lightkey-equivalent.

## Build on a Mac with Command Line Tools or Xcode

```sh
cd /path/to/LumenDesk
zsh build-app.sh
open dist/LumenDesk.app
```

The script runs tests before building and creates an ad-hoc-signed app for local use. It does not provide a Developer ID signature or notarization. Alternatively, open Package.swift in Xcode. No external dependencies or package downloads are required.

## First use

1. Leave output stopped while exploring the six original demo fixtures and two cues.
2. In Patch, set the fixture types, DMX addresses and the node's unicast IP address.
3. In Design, select fixtures, set a look and capture a cue.
4. In Live, trigger cues and adjust effects, master and blackout.
5. After receiver/simulator verification, start output explicitly. Blackout keeps sending zero intensity while output runs; stopping output attempts a final dark frame, but UDP delivery cannot guarantee the receiver's final state.

## Validation supplied

Six XCTest tests cover ArtDMX byte order and universe boundaries, patch collisions/end bounds, JSON identity round trips, master/blackout, unsupported project versions and interpolation. They have **not run** because the compiler is unavailable. Source review corrected UI/output universe numbering and stage preview rendering. See VALIDATION.md for the current verification record.

## Remaining scope

This is a small first implementation, not full Lightkey parity. Missing: fixture-profile editor/library, 16-bit attributes, pan/tilt/gobos, multiple universes, cue layering/priorities and release behavior, sequences/cue lists, custom fade curves, per-cue effects, MIDI/OSC/DMX input, keyboard binding editor, sACN, USB/OLA output, Hue, node discovery, undo/autosave, and hardware/long-duration tests. Existing Lightkey project import is also not implemented.

Use manufacturer-authored fixture specifications or suitably licensed libraries when expanding profiles. Art-Net protocol reference and product requirements: [Artistic Licence Art-Net](https://art-net.org.uk/). Product release requirements need to be checked before distribution. Art-Net™ Designed by and Copyright Artistic Licence Engineering Ltd.

## Timed playback

Open Live and click Run sequence. Each cue fades for its Fade duration, then holds for its Hold duration (default three seconds). Choose Forward, Reverse, or Ping-pong and optionally Repeat before starting. Pause freezes the current fade and sequence countdown; global effects continue. Resume continues from the same point. Manual cue activation or fixture edits cancel automatic playback. Stop darkens all fixture states and disables effects. On normal completion, the last cue remains visible. Timing/levels are captured at run start; edits apply on restart. Settings and holds are saved in the show file, and older show files remain readable.
