# Music director prototype

Open `Examples/AYRA-NGEAR-rig.lumendesk.json` with Open show. It patches AYRA MH1 at 1, N-GEAR MH3 at 10, N-GEAR MH4 at 19, AYRA MH2 at 28, all in 9-channel mode. Profiles are embedded and appear in Patch & Output. Match the physical fixtures' modes and addresses before enabling output. The two profiles remain provisional and need hardware checks.

The Laserworld EL-400RGB MK2 is patched at address 64 (channels 64–72), using the supplied nine-channel manual. Select LA1 in Design → Color for manual mode, pattern, position, speed, size and colour-slot controls. It starts Off, is always excluded from Autopilot regardless of its role setting, and sends zero laser channels on Blackout, Master zero or Stop. Pattern and colour slot names are not specified in the manual, so the UI exposes DMX numbers. Hardware verification is pending. Laser patterns are not simulated in the stage preview.

Patch & Output has an Autopilot role per fixture: Beam accents, Wash atmosphere, or Manual only. Old shows infer beam for moving heads and wash for other fixtures. Assign any subsequently added laser Manual only.

Autopilot cycles through mirrored sweep, outward fan, crossed beams, and alternating accents. Major looks and colours change every eight bars (32 beats), with four-beat movement/colour transitions. Beam pairs mirror each other; washes use calmer travel and steadier intensity. Break/drop energy estimates modulate the look. The phrase clock follows BPM; use Sync on a musical downbeat. It does not infer the track's true phrase start or predict future drops. Auto style remains a tonal heuristic, not a trained genre model.

Use Try demo to rehearse without the microphone, or Listen to microphone. Save this look creates an editable cue from the generated colours, intensity and movement, before Master/Blackout, so those controls are not baked into the cue. It saves a static look, not the motion animation. Turn Autopilot off before replaying it. Assign saved cues to buttons through Edit board. Master/Blackout/Stop retain priority.

Live microphone accuracy and hardware output need real-rig verification. Song-file analysis, natural-language scene generation, learned genre recognition, and predictive section planning are future work.
