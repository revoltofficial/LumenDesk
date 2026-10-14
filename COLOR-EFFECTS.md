# Colour effects library

Open Design → Color → Colour library, or Live → Effects → Colour library. Ten patterns are included: Palette fade, Palette chase, Ping-pong, Alternating pairs, Rainbow, Rainbow wave, Comet, Twinkle, Fire and Police. Ten editable palettes are supplied: Disco, Techno, Sunset, Ocean, Forest, Pastel, Ice, Warm glow, Police and Violet.

The preview strip shows eight example fixtures using the same renderer as output. Choosing a pattern starts the effect; the dimmer is preserved by default, so activate a cue or raise dimmer to light your fixtures. Disable Autopilot to see colour effects without its later colour override. Effects apply only to RGB/RGBW fixtures, in patch order; dimmer-only fixtures and lasers do not take up colour spread slots.

Timing supports seconds or 0.25–64-beat cycles, using the existing BPM/Tap/Sync controls. Reverse, Phase, Depth and Spread adjust the pattern. Fade/chase softness blends at the end of each palette step; zero gives a hard switch. Ping-pong and palette fades interpolate in RGB space. Rainbow patterns generate hue directly; editable palettes affect the other patterns. Alternating pairs use fixture index parity. Comet travels back and forth along patch order. Twinkle and Fire use reproducible variation rather than new random values on each redraw.

Animate intensity is off by default. Enabling it adds the brightness envelope for Comet, Twinkle, Fire or Police. Master and Blackout remain the final controls. RGBW white is mixed down with effect Depth so the colour remains saturated; zero Depth preserves the underlying RGB and white channels.

Use the swatches to edit individual colours, + to add a colour, and − beneath a swatch to remove it. Palettes support 1–16 colours. Save colour preset stores the pattern, palette and parameters in the current show; recall replaces the library's colour effect while preserving its identity. Save the show to retain presets. Up to 64 named presets are supported.

These are original deterministic lighting patterns. No song-recognition model is added. Hardware colour mixing and actual fixture response still need testing.
