# LumenDesk development priorities

Updated 14 October 2026 after reading the shared LumenDesk Introduction conversation.

## Current increment

Manual BPM entry and the new −/+ buttons switch off automatic tempo following. Each button adjusts by 1 BPM, preserving fractional values and clamping to 30–300. Tap Tempo also selects manual tempo. Re-enable Follow detected BPM explicitly in the Autopilot panel when desired. Sync keeps the selected tempo and restarts the shared beat phase.

The delivered director also includes microphone/computer-audio input, the five-fixture rig, manual Laserworld mode/colour/scan controls, beam/wash roles, eight-bar look changes and capture of a generated static look as a cue. Real audio capture and fixture output still need testing.

## Next: movement stability

Existing cue fades interpolate absolute positions, and Stop parks the rendered pose. Effects can still change their positional offset immediately when enabled, changed or synchronized; Autopilot energy-section changes also alter travel immediately. These require a shared final motion controller, updated once per engine tick and used by both preview and DMX output. It should track current position/velocity, enforce degree-based speed and acceleration limits, remain inside calibrated travel, and avoid angular wrap shortcuts. Reads of renderedState must not advance motion: drawing multiple views must not change output. Stop must park the filtered pose. Test mode changes, path changes, tempo Sync, cue interruption, reversals, long frames, fixture removal and calibration before hardware testing.

## Then: movement library

Extend the existing Circle, Figure eight, Sweep and Custom paths with fans, waves, spirals, crosses and reproducible smooth wandering. Provide path previews, direction, phase, size, speed, spread and saved favourites. Keep saved show compatibility and support seconds or beat timing. Movement stability comes first so choosing a preset does not cause a jump.

## Show Creator: prepared songs

Import audio, analyze it locally, and present an editable timeline with the waveform, beat grid, sections and lighting events. Analysis should be replaceable and versioned; editing a section must not regenerate the rest of the show. A chorus label alone is not proof of an EDM drop. Evaluate energy, bass return, onset density and preceding context separately.

All-In-One predicts tempo, beats, downbeats and section boundaries/labels and emits timestamped JSON. Its repository documents Python/PyTorch and additional dependencies, so first evaluate a separate optional local analyzer rather than adding a large runtime to the lightweight Swift app.
Source: https://github.com/mir-aidj/all-in-one

## Track recognition and DJ Sync

Build a local reference library from user-imported songs. Evaluate audfprint for matching excerpts and estimating reference offsets. Add confidence, repeated-match confirmation, tempo-aware position tracking and smooth fallback to live Autopilot. Recognition is not guaranteed continuous timecode, especially during mixes, loops, pitch changes and effects. Investigate supported DJ-software interfaces separately.
Source: https://github.com/dpwe/audfprint

EfficientAT supplies audio-tagging models and embeddings. Consider it only if measured tagging results improve lighting decisions; it does not itself provide complete song structure or precise playback synchronization.
Source: https://github.com/fschmid56/EfficientAT

Before incorporating any third-party code or model, review its exact code/model licenses and resource requirements. No external code or model has been incorporated in this increment, and the analyzer/recognition stages above are proposals, not shipped features.

Shared conversation: https://chatgpt.com/share/6ace9acb-d3cc-83ed-b3fe-ae9fe71fc5e4
