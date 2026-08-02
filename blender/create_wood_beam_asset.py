import os

import bpy


PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSET_DIR = os.path.join(PROJECT_ROOT, "assets")
OUTPUT = os.path.join(ASSET_DIR, "wood_beam.glb")


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)


def make_material():
    material = bpy.data.materials.new("WoodBeamMaterial")
    material.diffuse_color = (0.38, 0.13, 0.035, 1.0)
    material.use_nodes = True
    principled = material.node_tree.nodes.get("Principled BSDF")
    principled.inputs["Base Color"].default_value = (0.38, 0.13, 0.035, 1.0)
    principled.inputs["Roughness"].default_value = 0.78
    return material


def build():
    os.makedirs(ASSET_DIR, exist_ok=True)
    clear_scene()
    bpy.ops.mesh.primitive_cube_add(size=1.0)
    beam = bpy.context.object
    beam.name = "WoodBeam"
    beam.data.materials.append(make_material())
    bevel = beam.modifiers.new("Rounded plank edges", "BEVEL")
    bevel.width = 0.06
    bevel.segments = 3
    bevel.limit_method = "ANGLE"
    bpy.context.view_layer.objects.active = beam
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    weighted_normal = beam.modifiers.new("Weighted corner normals", "WEIGHTED_NORMAL")
    weighted_normal.keep_sharp = True
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ASSET_DIR, "wood_beam.blend"))
    bpy.ops.object.select_all(action="DESELECT")
    beam.select_set(True)
    bpy.context.view_layer.objects.active = beam
    bpy.ops.export_scene.gltf(filepath=OUTPUT, export_format="GLB", use_selection=True, export_apply=True)


if __name__ == "__main__":
    build()
