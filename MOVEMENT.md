# Smooth moving-head travel

A shared motion controller runs once per engine tick after cue, layer, effect and Autopilot targets are calculated. Both stage preview and DMX output use its current position. Reading the preview or output frame never advances movement.

The default limits are 90 degrees/second and 180 degrees/second² on each axis. Change them in Design → Position under Smooth movement. Settings apply to all moving heads and are saved in the show. Older shows use the defaults. Pan and tilt follow absolute fixture travel; the controller does not take a modulo-360 shortcut.

Movement starts from the current controlled pose and keeps velocity through target changes, including instant cues, effect switches, Sync and Autopilot section changes. It decelerates before reversing. Stop immediately darkens and parks at the current pose, clearing velocity. Blackout immediately darkens while movement continues. Normal cue fade time still drives the target, but a fast fade/effect may take longer to reach that target because speed limits take priority.

A long UI pause advances at most 0.25 seconds of motion on the next tick. Missed travel is not replayed as a single jump. Physical travel endpoints clamp position and stop outward velocity immediately. The controller is a damped target follower; it is not an exact model of a fixture's motors, and rapid reversals can pass a moving target before settling.

Calibration inversion should be changed with physical output off. Inversion occurs in the fixture's output mapping; changing it live can flip the motor command. Mounting rotation changes the schematic preview direction. Speed and acceleration limits are software-command limits; 8-bit fixtures quantize positions to DMX steps, so actual motor response still needs testing.

Laserworld direct channels are excluded. No laser pattern is generated or smoothed by this controller.
