# Workflow references

This original LumenDesk prototype uses public references to guide its workflow and layout. No Lightkey images, fixture profiles, or proprietary code are bundled in the app.

- [Official workspace overview](https://lightkeyapp.com/en): a persistent stage preview, preset palette, and lower Design/Live controls.
- [Official tutorials](https://www.lightkeyapp.com/en/help/videos): setup, fixture controls, presets, sequences, and live panels.
- [Official feature specifications](https://lightkeyapp.com/en/specs): cue lists, fade timing, effects, and patching.
- [Lightkey-Skill](https://github.com/jimhoggey/Lightkey-Skill), especially `docs/class-schemas.md`: unofficial project-format observations. Used as research; its code is not included. Format claims need verification against real projects before implementing import.

## This iteration

Persistent stage preview in both modes; searchable look palette; editable cue inspector; native color picker and eight color favorites; cue-colored live buttons; ordered cue list with Go Next; effect pattern previews; patch/output sheet with validation; update and delete cues.

The cue list plays the app's existing full-scene cues in their saved order and stops at the end. Timed sequence playback now runs that list with per-cue fade/hold durations, pause/resume, repeat, and forward/reverse/ping-pong order. It has no cue layering or priority arbitration. Effects remain global. Lightkey project import is not implemented.

## Timed sequences

In Live, choose an order and Repeat, then Run sequence. Set each cue’s Hold in the inspector; its fade runs first, followed by the hold. Pause freezes the sequence and its current fade while global effects continue. Manual cue activation or fixture edits cancel the sequence. Stop cancels playback and darkens the preview. A completed non-repeating run holds its last look. Timing and cue levels are captured at start; edits apply on restart. Delayed UI ticks advance one cue at a time without sending a burst of skipped cues. Older show files load with a three-second hold and forward, non-repeating defaults.
