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
	scene.call("_open_stop")
	await create_timer(1.0).timeout

	for generation in range(8):
		scene.call("_randomize_level")
		for ball in get_nodes_in_group("balls"):
			if is_instance_valid(ball):
				ball.free()
		var portal_before: int = scene.portal_count
		var finished_before: int = scene.finished_ball_count
		scene.call("_spawn_ball")
		var elapsed := 0.0
		while elapsed < 35.0 and scene.finished_ball_count == finished_before:
			await create_timer(0.25).timeout
			elapsed += 0.25
		assert(scene.portal_count > portal_before, "Generation %d never reached the portal from the funnel" % generation)
		assert(scene.max_section_reached == 11, "Generation %d did not traverse all sections from the funnel" % generation)
		assert(scene.finished_ball_count > finished_before, "Generation %d did not reach the finish" % generation)
	quit()
