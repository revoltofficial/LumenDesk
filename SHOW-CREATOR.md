# Show Creator — first release

Select Show Creator in the workspace bar. Import a local song, or choose Try rehearsal for an original 30-second synthetic 120 BPM track. Import builds a representative waveform in the background. Audio decoding is chunked, with a two-hour duration limit; waveform data is capped at 1200 points. Unsupported/protected formats return an import error. Nothing is uploaded.

Play drives the timeline from the audio player's song position. Pause holds the timeline and controlled moving-head pose. Start seeks to zero. The Song position slider scrubs the song and previews lighting. Audio volume is separate from the lighting Master. Global Stop stops audio, resets the playhead, darkens fixtures and parks heads. Playback never enables physical output automatically.

Choose an existing lighting cue and Add cue at playhead. Drag its block or edit its seconds value; Go seeks to that event. Events reference existing cues, so edit a cue in Design to change its contents and fade time. Event times must be unique. Add section markers for Intro, Verse, Break, Build, Drop or Outro; edit their labels/times or remove them. Section markers are manual labels in this release, not automatic detections.

Cue fades are evaluated at the exact song position, including interrupted fades and backward seeks. Global colour/movement effects use song seconds or the song position multiplied by the manually selected BPM. The first beat is assumed to be at song time zero; beat-grid/downbeat offsets are a later feature. Moving heads obey their existing speed/acceleration limits, so seeking moves them smoothly toward the new target. Pause freezes their current controlled pose; seeking explicitly lets them settle to the new target.

Timeline control stops live audio Autopilot and cue sequences. Manual cue activation or direct fixture adjustment pauses audio and returns control to normal operation. Existing global effects can influence the timeline; choose/disable them deliberately. Lasers remain manual: scheduled cues do not change their direct channels, while Master zero, Blackout and Stop still turn them off.

Save Show stores cue references, marker times, audio name/duration and waveform. It does not embed or copy the audio recording or save an absolute file path. After reopening, Import / relink the same recording before playback. Relinking does not fingerprint-check the recording; choose the correct file. A shorter replacement is rejected if events/markers would lie outside it. The editor can arrange/scrub cues without an audio file, but Play requires linked audio.

At the end, playback holds its last look until Stop or another control is used. This release adds local playback and manual timeline editing. Automatic section analysis, show generation, song recognition and DJ sync are not implemented yet.
