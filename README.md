# LumenDesk — native macOS lighting app

Original SwiftUI source prototype, version 0.1. The working name is LumenDesk. It starts with the patch → design → live playback workflow selected by the user. No Lightkey code, fixture library, artwork or saved-show content is shipped with it.

## Current build status

Native Apple Silicon app builds successfully through GitHub Actions. The sequence build passed all 14 tests and local UI checks. The fixture-group update adds four regression tests; its verification is recorded in VALIDATION.md. Hardware output remains untested.

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

Tests cover ArtDMX byte order, patch validation, save/load compatibility, blackout, fade interpolation, sequence timing and pause/resume, fixture groups and selection edits. See VALIDATION.md for completed build and UI checks.

## Remaining scope

This is a small first implementation, not full Lightkey parity. Missing: fixture-profile editor/library, 16-bit attributes, pan/tilt/gobos, multiple universes, cue layering/priorities and release behavior, custom fade curves, per-cue effects, MIDI/OSC/DMX input, keyboard binding editor, sACN, USB/OLA output, Hue, node discovery, undo/autosave, and hardware/long-duration tests. Existing Lightkey project import is also not implemented.

Use manufacturer-authored fixture specifications or suitably licensed libraries when expanding profiles. Art-Net protocol reference and product requirements: [Artistic Licence Art-Net](https://art-net.org.uk/). Product release requirements need to be checked before distribution. Art-Net™ Designed by and Copyright Artistic Licence Engineering Ltd.

## Timed playback

Open Live and click Run sequence. Each cue fades for its Fade duration, then holds for its Hold duration (default three seconds). Choose Forward, Reverse, or Ping-pong and optionally Repeat before starting. Pause freezes the current fade and sequence countdown; global effects continue. Resume continues from the same point. Manual cue activation or fixture edits cancel automatic playback. Stop darkens all fixture states and disables effects. On normal completion, the last cue remains visible. Timing/levels are captured at run start; edits apply on restart. Settings and holds are saved in the show file, and older show files remain readable.

## Fixture groups and selection

Command-click or Shift-click fixture icons to add/remove them from the selection. Select all and Clear are in the Fixture Groups area. Its + button opens a named group editor with a checkbox per fixture. Click a saved group to recall its members; its menu edits its name/membership, replaces membership with the current selection, or deletes it. Groups save in show files; older shows load with no groups. Removing a fixture removes it from all groups, and empty groups are removed.

Dimmer affects every selected fixture. RGB controls affect only RGB/RGBW fixtures; White affects RGBW fixtures only. Changing one channel preserves other channels and unselected fixtures. Mixed channel values are labelled Mixed; sliders show their average until set to a shared absolute level. Color picking and favorites preserve intensity. Manual level edits cancel timed playback as before. Selection alone does not change light output. Fixture dragging still moves one fixture at a time.
