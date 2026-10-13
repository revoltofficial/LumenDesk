# LumenDesk — native macOS lighting app

Original SwiftUI source prototype, version 0.1. The working name is LumenDesk. It starts with the patch → design → live playback workflow selected by the user. No Lightkey code, fixture library, artwork or saved-show content is shipped with it.

## Current build status

Native Apple Silicon app builds successfully through GitHub Actions. The sequence build passed all 14 tests and local UI checks. The fixture-group build passed all 18 tests and local selection/group UI checks; details are recorded in VALIDATION.md. The presets/layers build passed all 25 tests and local capture, composition, activation and release checks. The moving-head calibration build passed all 39 tests plus local sweep, upward-tilt, zoom, profile-import and legacy-show checks. Hardware output remains untested.

## Implemented in source

- Patch generic dimmer (1 channel), RGB (3 channels), RGBW (4 channels), and moving-head (11 channel) fixtures within one 512-channel universe. Validate overlaps and footprint bounds.
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

This is a small first implementation, not full Lightkey parity. Missing: manufacturer fixture library/editor, multiple universes, custom fade curves, release fades, editable preset replacement, MIDI/OSC/DMX input, keyboard binding editor, sACN, USB/OLA output, Hue, node discovery, undo/autosave, and hardware/long-duration tests. Existing Lightkey project import is also not implemented.

Use manufacturer-authored fixture specifications or suitably licensed libraries when expanding profiles. Art-Net protocol reference and product requirements: [Artistic Licence Art-Net](https://art-net.org.uk/). Product release requirements need to be checked before distribution. Art-Net™ Designed by and Copyright Artistic Licence Engineering Ltd.

## Timed playback

Open Live and click Run sequence. Each cue fades for its Fade duration, then holds for its Hold duration (default three seconds). Choose Forward, Reverse, or Ping-pong and optionally Repeat before starting. Pause freezes the current fade and sequence countdown; global effects continue. Resume continues from the same point. Manual cue activation or fixture edits cancel automatic playback. Stop darkens all fixture states and disables effects. On normal completion, the last cue remains visible. Timing/levels are captured at run start; edits apply on restart. Settings and holds are saved in the show file, and older show files remain readable.

## Fixture groups and selection

Turn on Multi-select in Design, then click fixture icons to add/remove them from the selection. Modifier-key selection is also present, but was not confirmed through native automation. Select all and Clear are in the Fixture Groups area. Its + button opens a named group editor with a checkbox per fixture. Click a saved group to recall its members; its menu edits its name/membership, replaces membership with the current selection, or deletes it. Groups save in show files; older shows load with no groups. Removing a fixture removes it from all groups, and empty groups are removed.

Dimmer affects every selected fixture. RGB controls affect only RGB/RGBW fixtures; White affects RGBW fixtures only. Changing one channel preserves other channels and unselected fixtures. Mixed channel values are labelled Mixed; sliders show their average until set to a shared absolute level. Color picking and favorites preserve intensity. Manual level edits cancel timed playback as before. Selection alone does not change light output. Fixture dragging still moves one fixture at a time.

## Presets and layered cues

In Design, select fixtures and set their levels. Open Presets and Capture preset: Intensity saves dimmer only; Color saves RGB and RGBW white only; Effects saves the currently enabled global effect settings for the selected fixtures; Look saves levels and that effect bundle. An effects preset with no enabled effects intentionally suppresses underlying effects on its fixtures.

New layer combines any saved presets in palette order, with later presets replacing overlapping values. Set priority (0–100) and fade-in time. Click its Activate button to overlay the scene; click Release to reveal the scene and remaining layers immediately. Higher priority wins per channel; equal priority uses latest activation. Independent color and intensity layers coexist. Effect bundles replace one another per fixture and switch immediately. Effect pattern phase remains global across the rig.

Scenes and timed sequences continue underneath layers. Manual level edits take over the visible channel values, clear all active layers, and cancel the sequence. Stop clears layers, darkens the scene, parks heads at their current rendered position, and disables global effects. Capture cue saves visible channel levels, not effect bundles. Presets and layered cue definitions save in show files; active playback does not. Older show files still open. Deleting a preset also deletes its dependent layered cues. Removing a fixture removes it from presets; presets left empty and their dependent cues are deleted. Active layer definitions are snapshots until released and reactivated. Layer fades interpolate over the currently changing underlying look. Releases are immediate; release fades are not yet implemented.

## Moving heads and fixture profiles

Patch & Output contains the generic fixture library, profile import, and an Add moving-head demo button. The demo adds two heads and two four-second sweep cues to the current show. In Design choose Position for the pan/tilt pad or sliders, and Beam for zoom and a gobo selector. Pan/tilt and zoom act on supporting selected fixtures; gobo acts on the named fixture because wheels differ by profile. Position and Beam presets can be layered over ordinary scenes. Live Effects includes Pan / Tilt orbit.

The generic 11-channel profile is an original demonstration mode: pan coarse/fine (1/2), tilt coarse/fine (3/4), dimmer (5), RGB (6–8), zoom (9), gobo (10: open=0, dots=32, star=64, bars=96), fixed open shutter (11=255). It has 540° pan, 270° tilt and 8–40° beam angle. It is not a manufacturer fixture mode. Real fixtures need a profile matching their exact manual/mode, including shutter-open values and physical ranges.

The preview is a schematic top-down 12×8 metre floor with hanging heads (default height 3m, editable in Patch). Center pan faces the audience; center tilt points down. Head/yoke pose and cone intersection use the same rendered attributes as output. Full pan travel is linear across cues, not shortest-path circular rotation. Zoom changes the cone opening angle. Above-horizon rays have no floor spot; cones straddling the horizon have no bounded ellipse and are omitted. Gobo changes occur at the end of cue/preset fades and use original approximate patterns. This is not a calibrated photometric simulation: motor inertia, collision/occlusion, real gobo artwork and gobo rotation are not simulated. Blackout gates intensity while retaining movement channel values.

See FIXTURE-PROFILES.md for the import format. Imported library entries and each patched fixture’s profile snapshot are saved in the show. Older shows default movement attributes to center and retain their previous RGB channel maps.

### Try the movement demo

1. Open Moving-heads-demo.lumendesk.json from the folder beside the app, or use Patch & Output → Add moving-head demo.
2. Activate Heads · left, then Heads · right in the cue inspector to watch the four-second sweeps.
3. Select a head and choose Design → Position. Drag the pad, or use Center and Aim forward. Choose Beam to change zoom and gobo.
4. In Live, Effects → Pan / Tilt orbit animates the moving heads. Keep output off while exploring.

The demo contains the two original movement cue definitions; current live edits and active playback are not saved. It is intended for preview, not a substitute for a hardware fixture’s exact channel map.

## Fixture calibration

In Patch & Output, each moving head has Mount rotation (-180 to 180 degrees), Invert pan output and Invert tilt output. Rotation aligns the preview's hanging mount with the physical installation; positive 90 degrees turns the neutral audience direction toward stage right. Inversion reverses the outgoing normalized position before profile channel mapping, while cues and position controls retain logical values. Enable inversion only when compensating for reversed hardware movement. Mount rotation changes preview geometry, not DMX bytes. Settings are saved per fixture; older shows default to zero rotation and no inversion. Floor-mounted fixtures and motor-response simulation are not yet supported.

## Custom live board

Live → Board opens a configurable control surface. Edit board lets you add buttons/text, drag controls on a grid, resize them and change labels, font sizes, colors, assigned targets and layer/effect behavior. Open Custom-live-board-demo.lumendesk.json beside the app for a populated example. Layout saves in show files. See LIVE-BOARD.md for operation, limitations and the supplied provisional Ayra/N-GEAR 9-channel profile drafts.

The custom-board build passed all 44 tests and local editing/scene/blackout checks. Its delivered app is LumenDesk-LiveBoard.app.

## Tempo

Live now includes BPM, Tap Tempo, Sync and a beat indicator. Each effect can follow seconds or a shared beat count; these settings save with the show. Tap Tempo and Sync can also be placed on the custom board. See TEMPO.md.
