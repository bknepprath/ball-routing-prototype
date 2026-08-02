extends SceneTree

const GENERATION_COUNT := 96

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
	await create_timer(0.4).timeout

	var route_heading_values := {}
	for generation in range(GENERATION_COUNT):
		scene.call("_randomize_level")
		assert(get_nodes_in_group("attachments").size() == 11, "Generation %d did not build eleven sections" % generation)
		var island_top := scene.get_node("SkyIsland/IslandTop") as MeshInstance3D
		var platform_diagonal := Vector2(scene.sky_island_bounds.size.x, scene.sky_island_bounds.size.z).length()
		assert(island_top.scale.x * 14.2 >= platform_diagonal + 3.9, "Generation %d left the route outside the sky platform" % generation)
		var first_entry: Marker3D = scene.get_node("LevelChain").get_child(0).get_node("Entry")
		var route_heading := atan2(first_entry.global_transform.basis.x.z, first_entry.global_transform.basis.x.x)
		route_heading_values[snapped(route_heading, 0.001)] = true
		var finished_before: int = scene.finished_ball_count
		var portal_before: int = scene.portal_count
		scene.call("_spawn_ball")
		var elapsed := 0.0
		while elapsed < 35.0 and scene.finished_ball_count == finished_before:
			await create_timer(0.25).timeout
			elapsed += 0.25
		assert(scene.portal_count > portal_before, "Generation %d never reached the portal" % generation)
		assert(scene.max_section_reached == 11, "Generation %d stopped at section %d" % [generation, scene.max_section_reached])
		assert(scene.section_completion_order.size() == 11, "Generation %d did not complete every section exactly once" % generation)
		for section_index in range(11):
			assert(scene.section_completion_order[section_index] == section_index, "Generation %d completed section %d out of order" % [generation, section_index])
		assert(scene.finished_ball_count > finished_before, "Generation %d never reached the finish" % generation)
	assert(route_heading_values.size() >= 2, "Stress run did not vary the tower heading")
	quit()
