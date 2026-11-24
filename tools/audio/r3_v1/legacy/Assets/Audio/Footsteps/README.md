# Wet footsteps

Water footsteps use three short variations trimmed from the user-provided
`freesound_community-walk-wet-86710.mp3`, preserved as `wet_walk_source.mp3`.
The original file was supplied by the user; no additional license metadata was supplied.

Each mono clip is 0.48 seconds, with a 6 ms fade-in and 70 ms fade-out.
Playback uses the existing subtle footstep volume (-32 dB).

To regenerate, run `tools/prepare_water_steps.gd` with Godot, then
`tools/cut_water_steps.py` with Python and NumPy. The source recording is only
used during preparation; gameplay plays one short variation per footstep.
