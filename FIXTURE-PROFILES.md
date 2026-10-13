# Fixture-profile import

Use Patch & Output → Import profile… to import a LumenDesk profile JSON. This is a small original format, not GDTF, OFL or Lightkey import. The supplied GenericMovingHead-example-profile.json can be imported as a separate example library entry. Edit its identity and channel map from a fixture’s manufacturer manual before using it on hardware.

Required profile fields: id (unique non-empty string), name, footprint (1–512), channels, panDegrees, tiltDegrees, minimumBeamDegrees, maximumBeamDegrees, gobos, colorUsesDimmer. Physical movement ranges are total travel in degrees centered on normalized 0.5; the mounting convention is hanging, center tilt down and center pan toward the audience. Rotation/installation offsets and tilt inversion in the preview are not yet configurable. Output ranges can be reversed by swapping minimum/maximum; that is an output mapping, not a change to preview mounting orientation.

Every channel entry has attribute, offset, minimum, maximum and constant. Offsets are one-based within the footprint. Optional fineOffset encodes a 16-bit value: the main offset gets the high byte and fineOffset the low byte. Use maximum 65535 for the full 16-bit range; 255 for an 8-bit range. Gobo channels are 8-bit. Supported attributes: dimmer, red, green, blue, white, pan, tilt, zoom, gobo, constant. Unmapped channels send zero; constant channels send the supplied 0–255 value. Each nonconstant attribute may occur once. Offsets cannot overlap. Profile loading rejects malformed ranges, duplicate IDs and invalid geometry before patching.

colorUsesDimmer=true multiplies RGBW output by the virtual intensity. Set false when a dedicated master dimmer channel performs that function. A color-only profile must use virtual dimming. This prevents master/blackout from being ignored on color-only fixtures.

Gobos are a list of {name, dmx, pattern}; dmx is the manufacturer’s representative slot value (0–255). Supported preview patterns: open, dots, star, bars. Empty gobos are allowed only without a gobo channel. Gobo selection uses named slots, not interpolation through DMX wheel ranges. Shutter/strobe, reset and control channels have no interactive controls; use a fixed constant only if the manual specifies a safe normal operating value. Profiles are limited to 1 MiB; shows remain limited to 10 MiB.

The current library includes four original generic profiles. No branded fixture profiles or vendor assets are included. Importing a profile adds it to this show; it does not rewrite already patched fixture snapshots.
