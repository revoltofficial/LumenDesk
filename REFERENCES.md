# Workflow references

This original LumenDesk prototype uses public references to guide its workflow and layout. No Lightkey images, fixture profiles, or proprietary code are bundled in the app.

- [Official workspace overview](https://lightkeyapp.com/en): a persistent stage preview, preset palette, and lower Design/Live controls.
- [Official tutorials](https://www.lightkeyapp.com/en/help/videos): setup, fixture controls, presets, sequences, and live panels.
- [Official feature specifications](https://lightkeyapp.com/en/specs): cue lists, fade timing, effects, and patching.
- [Lightkey-Skill](https://github.com/jimhoggey/Lightkey-Skill), especially `docs/class-schemas.md`: unofficial project-format observations. Used as research; its code is not included. Format claims need verification against real projects before implementing import.

## This iteration

Persistent stage preview in both modes; searchable look palette; editable cue inspector; native color picker and eight color favorites; cue-colored live buttons; ordered cue list with Go Next; effect pattern previews; patch/output sheet with validation; update and delete cues.

The cue list plays the app's existing full-scene cues in their saved order and stops at the end. It has no automatic holds, cue layering, priority arbitration, or sequence scheduler. Effects remain global. Lightkey project import is not implemented.
