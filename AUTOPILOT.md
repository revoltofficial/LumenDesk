# Music Autopilot

BPM, Tap and Sync are always in the bottom-left corner, with Autopilot beneath them. Open Autopilot and choose Listen to microphone. macOS asks for microphone permission on the first use. Select the desired input in macOS Sound settings; this prototype uses the system default input.

Audio stays on the Mac. LumenDesk measures short audio windows in memory, keeps up to 12 seconds of onset features, and neither records files nor uploads audio. Stop listening removes the microphone tap. Opening another show also stops listening. Listening and Autopilot must be started again explicitly each session.

Follow detected BPM gradually adjusts the shared tempo when the estimate is confident. The initial estimate needs at least five seconds of a steady rhythm. It looks for tempo between about 60 and 176 BPM; half/double-time ambiguity, crowd noise, echoes, vocals and changing tracks can confuse it. Use Tap or a manual BPM when needed, and turn Follow detected BPM off to hold your own setting.

Autopilot lighting uses live energy and recent changes: breaks reduce brightness and movement, builds increase activity, and a strong return after a quieter section triggers a temporary Drop look. Silence or stale audio darkens the Autopilot look. No shutter/strobe channels are generated. Blackout and Master remain above Autopilot. Stop turns Autopilot off and parks movement.

Disco uses brighter multicolour palettes; Techno uses darker blue, violet and red palettes. Auto chooses from tonal balance. This is an experimental signal-based controller, not a trained AI genre classifier or a reliable predictor of musical structure. Real DJ recordings and physical fixtures need further evaluation.

Try demo runs a synthetic 120 BPM rhythm with alternating energetic and quiet sections, without using the microphone. This is useful for inspecting the lighting and interface, not evidence of accuracy on real music.

## Effect editing

Live → Effects → Add effect adds Pulse, Scanner, Sparkle and ColorChase alongside the original effects. Wave and Scanner offer sine, triangle, square and ramp shapes. Spread offsets fixtures through the cycle. ColorChase offers Disco and Techno palettes.

The orbit effect now offers Circle, Figure eight, Sweep and Custom paths. Edit path opens draggable points with add/remove/reset and closed-loop controls. Open paths return along the same points without jumping at the loop boundary. Coordinates are relative pan/tilt offsets around the current fixture position; Depth sets the travel distance. Paths and all effect parameters save in the show, including captured effect presets.
