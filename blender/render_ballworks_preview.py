import math
import os

import bpy
from mathutils import Vector


ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BLEND = os.path.join(ROOT, "assets", "ballworks_structure.blend")
OUTPUT = os.path.join(ROOT, "assets", "ballworks_preview.png")


def look_at(obj, target):
    direction = Vector(target) - obj.location
    obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def main():
    bpy.ops.wm.open_mainfile(filepath=BLEND)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 1280
    scene.render.resolution_y = 720
    scene.render.resolution_percentage = 100
    scene.render.filepath = OUTPUT
    scene.world.color = (0.015, 0.025, 0.05)

    camera_data = bpy.data.cameras.new("PreviewCamera")
    camera = bpy.data.objects.new("PreviewCamera", camera_data)
    camera.location = (20.0, 18.0, 24.0)
    look_at(camera, (0.0, 5.0, 2.0))
    scene.collection.objects.link(camera)
    scene.camera = camera

    light_data = bpy.data.lights.new("Key", type="AREA")
    light_data.energy = 1800
    light_data.shape = "DISK"
    light_data.size = 12
    light = bpy.data.objects.new("Key", light_data)
    light.location = (0.0, 18.0, 8.0)
    look_at(light, (0.0, 5.0, 2.0))
    scene.collection.objects.link(light)

    fill_data = bpy.data.lights.new("Fill", type="AREA")
    fill_data.energy = 900
    fill_data.size = 10
    fill = bpy.data.objects.new("Fill", fill_data)
    fill.location = (-18.0, 10.0, -8.0)
    look_at(fill, (0.0, 5.0, 2.0))
    scene.collection.objects.link(fill)

    bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    main()
