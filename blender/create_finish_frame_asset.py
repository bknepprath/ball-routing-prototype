import math
import os

import bpy


PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSET_DIR = os.path.join(PROJECT_ROOT, "assets")
OUTPUT = os.path.join(ASSET_DIR, "finish_frame.glb")


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)


def make_material(name, color, metallic=0.0, roughness=0.6, emission=None):
    material = bpy.data.materials.new(name)
    material.diffuse_color = (*color, 1.0)
    material.use_nodes = True
    principled = material.node_tree.nodes.get("Principled BSDF")
    principled.inputs["Base Color"].default_value = (*color, 1.0)
    principled.inputs["Metallic"].default_value = metallic
    principled.inputs["Roughness"].default_value = roughness
    if emission:
        principled.inputs["Emission Color"].default_value = (*emission, 1.0)
        principled.inputs["Emission Strength"].default_value = 1.4
    return material


def build():
    os.makedirs(ASSET_DIR, exist_ok=True)
    clear_scene()
    frame_material = make_material("FinishFrame", (0.82, 0.42, 0.07), metallic=0.35, roughness=0.32, emission=(0.18, 0.05, 0.005))
    bpy.ops.mesh.primitive_torus_add(
        major_radius=1.25,
        minor_radius=0.18,
        major_segments=48,
        minor_segments=12,
        rotation=(0.0, math.radians(90.0), 0.0),
    )
    frame = bpy.context.object
    frame.name = "FinishFrame"
    frame.data.materials.append(frame_material)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ASSET_DIR, "finish_frame.blend"))
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=OUTPUT, export_format="GLB", use_selection=True, export_apply=True)


if __name__ == "__main__":
    build()
