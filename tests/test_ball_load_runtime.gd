extends SceneTree

func _init() -> void:
	var packed_scene := load("res://main.tscn") as PackedScene
	var scene := packed_scene.instantiate()
	root.add_child(scene)
	await process_frame
	scene.auto_spawn = false
	for ball in get_nodes_in_group("balls"):
		if is_instance_valid(ball):
			ball.free()
	for index in range(300):
		scene.call("_spawn_ball")
	var balls := get_nodes_in_group("balls")
	assert(balls.size() == 300, "Load test did not reach the 300-ball cap")
	var shadowed_count := 0
	for ball in balls:
		assert(ball.visual.mesh == scene.ball_mesh, "Load-test balls do not share their mesh")
		assert(ball.visual.material_override == scene.ball_material, "Load-test balls do not share their material")
		if ball.visual.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			shadowed_count += 1
	assert(shadowed_count <= 80, "Load test exceeded the shadow caster budget")
	await create_timer(2.0).timeout
	assert(get_nodes_in_group("balls").size() <= 300, "Ball load exceeded the active population cap")
	quit()
