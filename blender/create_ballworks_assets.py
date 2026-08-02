import math
import os

import bpy
from mathutils import Vector


PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSET_DIR = os.path.join(PROJECT_ROOT, "assets")
SOURCE_DIR = os.path.join(PROJECT_ROOT, "blender", "sources")
OUTPUT = os.path.join(ASSET_DIR, "ballworks_structure.glb")


def material(name, color, metallic=0.0, roughness=0.6, emission=None):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1.0)
    mat.use_nodes = True
    principled = mat.node_tree.nodes.get("Principled BSDF")
    principled.inputs["Base Color"].default_value = (*color, 1.0)
    principled.inputs["Metallic"].default_value = metallic
    principled.inputs["Roughness"].default_value = roughness
    if emission:
        principled.inputs["Emission Color"].default_value = (*emission, 1.0)
        principled.inputs["Emission Strength"].default_value = 2.0
    return mat


def add_cylinder(name, location, radius, depth, mat, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=32,
        radius=radius,
        depth=depth,
        location=location,
        rotation=rotation,
    )
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    return obj


def add_torus(name, location, major_radius, minor_radius, mat, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(
        major_radius=major_radius,
        minor_radius=minor_radius,
        major_segments=48,
        minor_segments=12,
        location=location,
        rotation=rotation,
    )
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    return obj


def add_pipe_between(name, start, end, radius, mat):
    start = Vector(start)
    end = Vector(end)
    midpoint = (start + end) * 0.5
    direction = end - start
    obj = add_cylinder(name, midpoint, radius, direction.length, mat)
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = direction.to_track_quat("Z", "Y")
    return obj


def add_panel(name, location, scale, mat, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    bevel = obj.modifiers.new("Edge bevel", "BEVEL")
    bevel.width = 0.08
    bevel.segments = 3
    return obj


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.meshes, bpy.data.curves, bpy.data.materials, bpy.data.cameras, bpy.data.lights):
        for datablock in list(datablocks):
            if datablock.users == 0:
                datablocks.remove(datablock)


def build():
    os.makedirs(ASSET_DIR, exist_ok=True)
    os.makedirs(SOURCE_DIR, exist_ok=True)
    clear_scene()

    tube = material("Wood", (0.26, 0.10, 0.035), metallic=0.0, roughness=0.78)
    tube_light = material("WoodLight", (0.52, 0.25, 0.07), metallic=0.0, roughness=0.68)
    gate = material("GateWood", (0.34, 0.13, 0.04), metallic=0.0, roughness=0.74)
    gold = material("Payment", (0.85, 0.55, 0.12), metallic=0.5, roughness=0.35, emission=(0.3, 0.12, 0.01))

    add_pipe_between("UpperTubeA", (-11, 8.6, 5), (-2, 11, 5), 1.2, tube)
    add_pipe_between("UpperTubeB", (-2, 11, 5), (7, 8.8, 5), 1.2, tube)
    add_pipe_between("UpperTubeC", (7, 8.8, 5), (13, 6.8, 2), 1.2, tube)

    add_torus("TubeLoopA", (-4, 10, 5), 3.0, 0.42, tube_light, rotation=(math.radians(90), 0, 0))
    add_torus("TubeLoopB", (4, 9.6, 5), 2.4, 0.34, tube_light, rotation=(math.radians(90), 0, 0))
    add_torus("PortalFrame", (10.3, 2.3, 0), 1.7, 0.24, tube_light, rotation=(0, math.radians(90), 0))

    for x in (-1.0, 2.0, 5.0, 8.0):
        add_panel(f"Support_{x}", (x, 0.8, 4.8), (0.22, 2.7, 0.22), tube)
        add_panel(f"Support_{x}_cross", (x, 3.3, 4.8), (1.8, 0.18, 0.18), tube)

    add_panel("MechanismHousing", (8.8, 3.8, 0), (2.8, 0.16, 2.2), tube)
    for z in (-0.9, 0.9):
        add_panel(f"Flap_{z}", (8.8, 2.9, z), (0.14, 0.9, 1.25), gate, rotation=(0, math.radians(25), 0))

    add_panel("PaymentArchTop", (7.0, 4.0, 0), (0.28, 0.18, 2.0), gold)
    add_panel("PaymentArchLeft", (7.0, 2.8, -1.8), (0.28, 1.2, 0.18), gold)
    add_panel("PaymentArchRight", (7.0, 2.8, 1.8), (0.28, 1.2, 0.18), gold)

    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(SOURCE_DIR, "ballworks_structure.blend"))
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(
        filepath=OUTPUT,
        export_format="GLB",
        use_selection=True,
        export_apply=True,
    )


if __name__ == "__main__":
    build()
