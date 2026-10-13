# Custom live board

Live → Board → Edit board adds buttons and text headings. Drag controls on a 12-column grid; select a control to edit label, font size, color, width, height, action and target. Layers and effects offer trigger, toggle or momentary behavior. Scene cues trigger; blackout toggles; Stop parks and darkens fixtures. Configure fade and priority in the target layered cue. Changes save with the show. Momentary controls release on pointer-up or leaving the board; holding an already active target leaves that target active. Missing/deleted targets are inert.

This first board version has no arbitrary fonts, group-exclusive buttons, per-button timing overrides, keyboard assignments or standalone faders. Layers release immediately.

# Hardware profile drafts

Import the supplied 9-channel JSON profiles using Patch & Output → Import profile. Both have fixed optics, RGBW and 8-bit position, without zoom or gobos. They are provisional and require hardware verification.

Ayra ERO Micro Beam FX: manufacturer manual page 10 provides the 9-channel order. Pan/tilt 540°/270°, fixed main beam 4°. Strobe channel 2 is fixed at 0 based on the user's DMX-monitor screenshot, since the manual does not identify a steady-open value. Movement-speed channel 5 is fixed at 255 according to the manual's slow-to-fast direction; verify physically. Extended mode is omitted because the manual contradicts itself. The separate LED ring is not independently controllable in this draft or represented in the preview.

N-GEAR MOVE WASH LIGHT 7: derived from the user-provided profile screenshot. Pan 1, tilt 2, intensity 3 mapped only to 0–134, RGBW 4–7. This avoids the depicted strobe range 135–239. Channels 8/9 send zero because their functions are not supplied. Fixed 25° wash, 540°/270° travel. The preview approximates seven emitters as one combined wash, pending a manufacturer manual and hardware checks. No fixture artwork or library data was extracted.
