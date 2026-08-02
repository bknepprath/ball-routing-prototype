# Ball Routing Prototype

Godot 4.5.1 project for a desktop-sized 3D vertical slice.

Open `project.godot` in Godot and run the main scene.

Controls:

- Space: drop a ball
- 1: buy spawn-rate upgrade
- 2: buy ball-value upgrade
- 3: buy ball-damage upgrade
- T: toggle automatic spawning
- G: randomize the eleven-section level
- W/S: move camera forward/back
- A/D: slide viewpoint left/right
- E/C: elevate/lower viewpoint
- Middle-drag: orbit viewpoint
- Shift + middle-drag: pan camera
- Mouse wheel: zoom camera
- Tab: hide/show interface
- R: reset camera

Blender source assets are generated with:

`C:\Program Files\Blender Foundation\Blender 4.0\blender.exe --background --python blender\create_ballworks_assets.py`

The finish frame is generated with:

`C:\Program Files\Blender Foundation\Blender 4.0\blender.exe --background --python blender\create_finish_frame_asset.py`

The beveled wood beam is generated with:

`C:\Program Files\Blender Foundation\Blender 4.0\blender.exe --background --python blender\create_wood_beam_asset.py`

The randomized traversal check is run with:

`godot --headless --path . --script tests\test_traversability_stress.gd`
