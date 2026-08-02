extends SceneTree

const TIMEOUT_SECONDS := 55.0

func _init() -> void:
	var packed_scene := load("res://main.tscn") as PackedScene
	var scene := packed_scene.instantiate()
	root.add_child(scene)
	await process_frame
	scene.auto_spawn = true
	scene.spawn_interval = 1.4
	scene.call("_open_stop")
	var finished_before: int = scene.finished_ball_count
	var elapsed := 0.0
	while elapsed < TIMEOUT_SECONDS and scene.finished_ball_count == finished_before:
		await create_timer(0.25).timeout
		elapsed += 0.25
	assert(scene.portal_count > 0, "Auto-spawn flow never reached the portal")
	assert(scene.max_section_reached > 0, "Auto-spawn flow never advanced through a section")
	assert(scene.finished_ball_count > finished_before, "Auto-spawn flow deadlocked before the finish")
	assert(scene.section_completion_order == [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10], "Auto-spawn flow completed sections out of order")
	quit()
