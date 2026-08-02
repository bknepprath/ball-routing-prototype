extends RigidBody3D

var value: int = 1
var damage: float = 1.0
var paid: bool = false
var visual: MeshInstance3D
var fading := false

func fade_out() -> void:
	if fading:
		return
	fading = true
	collision_layer = 0
	collision_mask = 0
	freeze = true
	if visual == null:
		queue_free()
		return
	var material := visual.material_override as StandardMaterial3D
	if material == null:
		queue_free()
		return
	material = material.duplicate() as StandardMaterial3D
	visual.material_override = material
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var target_color := material.albedo_color
	target_color.a = 0.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(material, "albedo_color", target_color, 0.35)
	tween.tween_property(material, "emission_energy_multiplier", 0.0, 0.35)
	tween.chain().tween_callback(queue_free)
