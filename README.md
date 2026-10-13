# LumenDesk — native macOS lighting app

Original SwiftUI source prototype, version 0.1. The working name is LumenDesk. It starts with the patch → design → live playback workflow selected by the user. No Lightkey code, fixture library, artwork or saved-show content is shipped with it.

## Current build status

Native Apple Silicon app builds successfully through GitHub Actions. The sequence build passed all 14 tests and local UI checks. The fixture-group build passed all 18 tests and local selection/group UI checks; details are recorded in VALIDATION.md. Hardware output remains untested.

## Implemented in source

- Patch generic dimmer (1 channel), RGB (3 channels) and RGBW (4 channels) fixtures within one 512-channel universe. Validate overlaps and footprint bounds.
- Arrange fixtures on a draggable 2D stage plan and adjust intensity/color.
- Capture looks as cues, rename cues, and trigger timed linear fades.
- Apply global sine, chase and rainbow effects, master level and blackout.
- Save/open versioned JSON show files with stable fixture/cue IDs and a 10 MiB load limit.
- Send ArtDMX packets to a configured unicast Art-Net node at a target 30 Hz. Output defaults OFF with a loopback destination. Display universe 1 corresponds to Art-Net port-address 0.

The implementation uses original semantics: cues replace the whole programmer state, unspecified fixtures fade to zero, layered presets override selected channels above scene fades, effects resolve per fixture, master affects intensities, and blackout zeros rendered intensity. These choices have not been established as Lightkey-equivalent.

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

This is a small first implementation, not full Lightkey parity. Missing: fixture-profile editor/library, 16-bit attributes, pan/tilt/gobos, multiple universes, custom fade curves, release fades, editable preset replacement, MIDI/OSC/DMX input, keyboard binding editor, sACN, USB/OLA output, Hue, node discovery, undo/autosave, and hardware/long-duration tests. Existing Lightkey project import is also not implemented.

Use manufacturer-authored fixture specifications or suitably licensed libraries when expanding profiles. Art-Net protocol reference and product requirements: [Artistic Licence Art-Net](https://art-net.org.uk/). Product release requirements need to be checked before distribution. Art-Net™ Designed by and Copyright Artistic Licence Engineering Ltd.

## Timed playback

Open Live and click Run sequence. Each cue fades for its Fade duration, then holds for its Hold duration (default three seconds). Choose Forward, Reverse, or Ping-pong and optionally Repeat before starting. Pause freezes the current fade and sequence countdown; global effects continue. Resume continues from the same point. Manual cue activation or fixture edits cancel automatic playback. Stop darkens all fixture states and disables effects. On normal completion, the last cue remains visible. Timing/levels are captured at run start; edits apply on restart. Settings and holds are saved in the show file, and older show files remain readable.

## Fixture groups and selection

Turn on Multi-select in Design, then click fixture icons to add/remove them from the selection. Modifier-key selection is also present, but was not confirmed through native automation. Select all and Clear are in the Fixture Groups area. Its + button opens a named group editor with a checkbox per fixture. Click a saved group to recall its members; its menu edits its name/membership, replaces membership with the current selection, or deletes it. Groups save in show files; older shows load with no groups. Removing a fixture removes it from all groups, and empty groups are removed.

Dimmer affects every selected fixture. RGB controls affect only RGB/RGBW fixtures; White affects RGBW fixtures only. Changing one channel preserves other channels and unselected fixtures. Mixed channel values are labelled Mixed; sliders show their average until set to a shared absolute level. Color picking and favorites preserve intensity. Manual level edits cancel timed playback as before. Selection alone does not change light output. Fixture dragging still moves one fixture at a time.

## Presets and layered cues

In Design, select fixtures and set their levels. Open Presets and Capture preset: Intensity saves dimmer only; Color saves RGB and RGBW white only; Effects saves the currently enabled global effect settings for the selected fixtures; Look saves levels and that effect bundle. An effects preset with no enabled effects intentionally suppresses underlying effects on its fixtures.

New layer combines any saved presets in palette order, with later presets replacing overlapping values. Set priority (0–100) and fade-in time. Click its Activate button to overlay the scene; click Release to reveal the scene and remaining layers immediately. Higher priority wins per channel; equal priority uses latest activation. Independent color and intensity layers coexist. Effect bundles replace one another per fixture and switch immediately. Effect pattern phase remains global across the rig.

Scenes and timed sequences continue underneath layers. Manual level edits take over the visible channel values, clear all active layers, and cancel the sequence. Stop clears layers, darkens the scene, and disables global effects. Capture cue saves visible channel levels, not effect bundles. Presets and layered cue definitions save in show files; active playback does not. Older show files still open. Deleting a preset also deletes its dependent layered cues. Removing a fixture removes it from presets; presets left empty and their dependent cues are deleted. Active layer definitions are snapshots until released and reactivated. Layer fades interpolate over the currently changing underlying look. Releases are immediate; release fades are not yet implemented.
