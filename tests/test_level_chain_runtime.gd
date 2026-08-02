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

	var arc_variant_values := {}
	var serpentine_variant_values := {}
	for generation in range(20):
		scene.call("_randomize_level")
		var attachments := get_nodes_in_group("attachments")
		assert(attachments.size() == 11, "Generation %d has the wrong section count" % generation)
		var seen_kinds := {}
		var seen_turns := {}
		var min_y := INF
		var max_y := -INF
		for index in range(attachments.size()):
			assert(attachments[index].get_node_or_null("EntryCollar") != null, "Generation %d is missing a visible entry collar" % generation)
			seen_kinds[attachments[index].get_meta("section_kind", -1)] = true
			var section_kind := int(attachments[index].get_meta("section_kind", -1))
			if section_kind in [2, 7]:
				var arc_radius := float(attachments[index].get_meta("arc_radius", 0.0))
				var arc_delta := float(attachments[index].get_meta("arc_vertical_delta", 0.0))
				assert(arc_radius >= 1.35 and arc_radius <= 1.75, "Generation %d produced an unsafe arc radius" % generation)
				assert(absf(arc_delta) >= 0.8 and absf(arc_delta) <= 1.2, "Generation %d produced an unsafe arc height" % generation)
				arc_variant_values[snapped(arc_radius, 0.001)] = true
			if section_kind == 10:
				var serpentine_length := float(attachments[index].get_meta("serpentine_length", 0.0))
				var serpentine_amplitude := float(attachments[index].get_meta("serpentine_amplitude", 0.0))
				assert(serpentine_length >= 4.8 and serpentine_length <= 5.6, "Generation %d produced an unsafe serpentine length" % generation)
				assert(serpentine_amplitude >= 0.85 and serpentine_amplitude <= 1.2, "Generation %d produced an unsafe serpentine amplitude" % generation)
				serpentine_variant_values[snapped(serpentine_length, 0.001)] = true
			if attachments[index].get_meta("section_kind", -1) in [2, 7]:
				seen_turns[attachments[index].get_meta("turn_sign", 0.0)] = true
			for port_name in ["Entry", "Exit"]:
				var port: Marker3D = attachments[index].get_node(port_name)
				min_y = minf(min_y, port.global_position.y)
				max_y = maxf(max_y, port.global_position.y)
			if index + 1 < attachments.size():
				var exit: Marker3D = attachments[index].get_node("Exit")
				var entry: Marker3D = attachments[index + 1].get_node("Entry")
				assert(exit.global_position.distance_to(entry.global_position) < 0.01, "Generation %d has a broken port join" % generation)
		assert(seen_kinds.size() == 11, "Generation %d did not include every module" % generation)
		var has_serpentine := false
		for attachment in attachments:
			if attachment.get_node_or_null("SmoothSerpentineHalfPipe") != null:
				has_serpentine = true
				break
		assert(has_serpentine, "Generation %d did not include the serpentine half-pipe" % generation)
		assert(seen_turns.size() == 2, "Generation %d did not produce both arc directions" % generation)
		assert(max_y - min_y >= 2.0, "Generation %d lacks vertical tower variation" % generation)
		if generation == 19:
			assert(arc_variant_values.size() >= 2, "Random generations did not vary arc geometry")
			assert(serpentine_variant_values.size() >= 2, "Random generations did not vary serpentine geometry")
		for ball in get_nodes_in_group("balls"):
			if is_instance_valid(ball):
				ball.free()
		scene.call("_spawn_ball")
		await process_frame
		var probe = get_nodes_in_group("balls")[0]
		var first_section: Node3D = scene.get_node("LevelChain").get_child(0)
		var entry: Marker3D = first_section.get_node("Entry")
		var exit: Marker3D = first_section.get_node("Exit")
		probe.global_position = entry.global_position + Vector3.UP * 0.7
		probe.linear_velocity = (exit.global_position - entry.global_position).normalized() * 4.0

		var boosts_before: int = scene.boost_count
		var elapsed := 0.0
		while elapsed < 24.0 and scene.max_section_reached < 11:
			await create_timer(0.25).timeout
			elapsed += 0.25
		assert(scene.max_section_reached == 11, "Generation %d lost the probe before section eleven" % generation)
		assert(scene.boost_count > boosts_before, "Generation %d did not activate a booster" % generation)
	for ball in get_nodes_in_group("balls"):
		if is_instance_valid(ball):
			ball.free()
	scene.call("_spawn_ball")
	var flap_probe = get_nodes_in_group("balls")[0]
	flap_probe.global_position = Vector3(8.0, 2.7, 0.0)
	flap_probe.linear_velocity = Vector3(4.0, 0.0, 0.0)
	var flap_elapsed := 0.0
	while flap_elapsed < 1.5 and scene.flap_hit_count == 0:
		await create_timer(0.1).timeout
		flap_elapsed += 0.1
	assert(scene.flap_hit_count > 0, "Moving wall did not contact a moving ball")
	assert(absf(flap_probe.linear_velocity.z) >= 1.2, "Moving wall did not redirect the ball")
	for ball in get_nodes_in_group("balls"):
		if is_instance_valid(ball):
			ball.free()
	scene.call("_spawn_ball")
	var conveyor_probe = get_nodes_in_group("balls")[0]
	var conveyor_area: Area3D = null
	for attachment in scene.get_node("LevelChain").get_children():
		if attachment.get_node_or_null("ConveyorArea") != null:
			conveyor_area = attachment.get_node("ConveyorArea")
			break
	assert(conveyor_area != null, "Straight section has no conveyor area")
	assert(conveyor_area.get_node_or_null("CollisionShape3D") != null, "Conveyor has no contact shape")
	var conveyor_basis: Basis = conveyor_area.global_transform.basis
	conveyor_probe.global_position = conveyor_area.global_position - conveyor_basis.x * 1.0 + Vector3.UP * 0.1
	conveyor_probe.linear_velocity = conveyor_basis.x * 1.0
	var conveyor_events_before: int = scene.conveyor_hit_count
	var conveyor_elapsed := 0.0
	while conveyor_elapsed < 1.5 and scene.conveyor_hit_count == conveyor_events_before:
		await create_timer(0.1).timeout
		conveyor_elapsed += 0.1
	assert(scene.conveyor_hit_count > conveyor_events_before, "Conveyor did not contact a moving ball")
	assert(conveyor_probe.linear_velocity.dot(conveyor_basis.x) >= 3.4, "Conveyor did not move the ball forward")
	for ball in get_nodes_in_group("balls"):
		if is_instance_valid(ball):
			ball.free()
	scene.call("_spawn_ball")
	var spinner_probe = get_nodes_in_group("balls")[0]
	var spinner: Node3D = null
	for attachment in scene.get_node("LevelChain").get_children():
		if int(attachment.get_meta("section_kind", -1)) == 3:
			spinner = attachment.get_node("Spinner")
			break
	assert(spinner != null, "Generated chain has no spinner attachment")
	var spinner_basis: Basis = spinner.global_transform.basis
	spinner_probe.global_position = spinner.global_position - spinner_basis.x * 1.0 + Vector3.UP * 0.15
	spinner_probe.linear_velocity = spinner_basis.x * 4.0
	var spinner_elapsed := 0.0
	while spinner_elapsed < 1.5 and scene.spinner_hit_count == 0:
		await create_timer(0.1).timeout
		spinner_elapsed += 0.1
	assert(scene.spinner_hit_count > 0, "Generated spinner did not contact a moving ball")
	assert(absf(spinner_probe.linear_velocity.dot(spinner_basis.z)) >= 1.7, "Generated spinner did not redirect the ball")
	for ball in get_nodes_in_group("balls"):
		if is_instance_valid(ball):
			ball.free()
	scene.call("_spawn_ball")
	var gate_probe = get_nodes_in_group("balls")[0]
	var gate: StaticBody3D = null
	for attachment in scene.get_node("LevelChain").get_children():
		if attachment.get_node_or_null("Gate") != null:
			gate = attachment.get_node("Gate")
			break
	assert(gate != null, "Generated chain has no gate attachment")
	assert(gate.get_node_or_null("GateLabel") != null, "Generated gate has no damage label")
	var gate_basis: Basis = gate.global_transform.basis
	gate_probe.global_position = gate.global_position - gate_basis.x * 1.0
	gate_probe.linear_velocity = gate_basis.x * 4.0
	var gate_elapsed := 0.0
	while gate_elapsed < 1.5 and scene.gate_hit_count == 0:
		await create_timer(0.1).timeout
		gate_elapsed += 0.1
	assert(scene.gate_hit_count > 0, "Generated gate did not contact a moving ball")
	assert(gate.get_meta("gate_open", false), "Generated gate did not open after damage")
	assert(gate.collision_layer == 0, "Generated gate collision remained active after opening")
	assert(gate.get_node("GateLabel").text == "OPEN", "Generated gate label did not update after opening")
	assert(is_instance_valid(gate_probe), "Gate removed the ball that opened it")
	assert(gate_probe.linear_velocity.dot(gate_basis.x) >= 4.0, "Opened gate did not hand the ball forward")
	var final_exit: Marker3D = scene.get_node("LevelChain").get_child(10).get_node("Exit")
	assert(scene.finish_marker.global_position.distance_to(final_exit.global_position + final_exit.global_transform.basis.y * 0.45) < 0.01, "Finish marker is not attached to the generated exit")
	var first_entry: Marker3D = scene.get_node("LevelChain").get_child(0).get_node("Entry")
	assert(scene.portal_destination_marker.global_position.distance_to(first_entry.global_position + first_entry.global_transform.basis.y * 0.28) < 0.01, "Portal destination is not attached to the generated entry")
	for ball in get_nodes_in_group("balls"):
		if is_instance_valid(ball):
			ball.free()
	scene.call("_spawn_ball")
	scene.call("_spawn_ball")
	var stack_probe_a = get_nodes_in_group("balls")[0]
	var stack_probe_b = get_nodes_in_group("balls")[1]
	var stack_area: Area3D = null
	for attachment in scene.get_node("LevelChain").get_children():
		if attachment.get_node_or_null("StackArea") != null:
			stack_area = attachment.get_node("StackArea")
			break
	assert(stack_area != null, "Generated chain has no stack area")
	var stack_basis: Basis = stack_area.global_transform.basis
	stack_probe_a.global_position = stack_area.global_position - stack_basis.z * 0.35 + Vector3.UP * 0.15
	stack_probe_b.global_position = stack_area.global_position + stack_basis.z * 0.35 + Vector3.UP * 0.15
	stack_probe_a.linear_velocity = stack_basis.x * 1.5
	stack_probe_b.linear_velocity = stack_basis.x * 1.5
	var stack_events_before: int = scene.stack_pressure_events
	var stack_elapsed := 0.0
	while stack_elapsed < 1.5 and scene.stack_pressure_events == stack_events_before:
		await create_timer(0.1).timeout
		stack_elapsed += 0.1
	assert(scene.stack_pressure_events > stack_events_before, "Two balls did not create stack pressure")
	for ball in get_nodes_in_group("balls"):
		if is_instance_valid(ball):
			ball.free()
	scene.call("_spawn_ball")
	var balance_probe = get_nodes_in_group("balls")[0]
	var balance_area: Area3D = null
	for attachment in scene.get_node("LevelChain").get_children():
		if attachment.get_node_or_null("BalanceArea") != null:
			balance_area = attachment.get_node("BalanceArea")
			break
	assert(balance_area != null, "Generated chain has no balance area")
	var balance_beam: AnimatableBody3D = null
	for attachment in scene.get_node("LevelChain").get_children():
		if attachment.get_node_or_null("BalanceBeam") != null:
			balance_beam = attachment.get_node("BalanceBeam")
			break
	assert(balance_beam != null and balance_beam.get_node_or_null("CollisionShape3D") != null, "Balance beam has no physical collision")
	var balance_attachment: Node3D = balance_area.get_parent()
	assert(balance_attachment.get_node_or_null("BalanceLeverCollider/CollisionShape3D") != null, "Balance lever has no physical collision")
	var balance_basis: Basis = balance_area.global_transform.basis
	balance_probe.global_position = balance_area.global_position - balance_basis.x * 1.0 + Vector3.UP * 0.1
	balance_probe.linear_velocity = balance_basis.x * 3.0
	var balance_events_before: int = scene.balance_hit_count
	var balance_elapsed := 0.0
	while balance_elapsed < 1.5 and scene.balance_hit_count == balance_events_before:
		await create_timer(0.1).timeout
		balance_elapsed += 0.1
	assert(scene.balance_hit_count > balance_events_before, "Balance section did not redirect a moving ball")
	for ball in get_nodes_in_group("balls"):
		if is_instance_valid(ball):
			ball.free()
	scene.call("_spawn_ball")
	var waterfall_probe = get_nodes_in_group("balls")[0]
	var waterfall_area: Area3D = null
	for attachment in scene.get_node("LevelChain").get_children():
		if attachment.get_node_or_null("WaterfallArea") != null:
			waterfall_area = attachment.get_node("WaterfallArea")
			break
	assert(waterfall_area != null, "Generated chain has no waterfall area")
	var waterfall_puck: AnimatableBody3D = null
	for attachment in scene.get_node("LevelChain").get_children():
		if attachment.get_node_or_null("WaterfallPuck0") != null:
			waterfall_puck = attachment.get_node("WaterfallPuck0")
			break
	assert(waterfall_puck != null and waterfall_puck.get_node_or_null("CollisionShape3D") != null, "Waterfall puck has no animated collision")
	var puck_rotation_before := waterfall_puck.rotation.y
	var waterfall_basis: Basis = waterfall_area.global_transform.basis
	waterfall_probe.global_position = waterfall_area.global_position - waterfall_basis.x * 1.0 + Vector3.UP * 0.1
	waterfall_probe.linear_velocity = waterfall_basis.x * 2.5
	var waterfall_events_before: int = scene.waterfall_hit_count
	var waterfall_elapsed := 0.0
	while waterfall_elapsed < 1.5 and scene.waterfall_hit_count == waterfall_events_before:
		await create_timer(0.1).timeout
		waterfall_elapsed += 0.1
	assert(scene.waterfall_hit_count > waterfall_events_before, "Waterfall did not redirect a moving ball")
	assert(absf(waterfall_puck.rotation.y - puck_rotation_before) > 0.1, "Waterfall puck did not animate")
	for ball in get_nodes_in_group("balls"):
		if is_instance_valid(ball):
			ball.free()
	scene.call("_spawn_ball")
	var portal_probe = get_nodes_in_group("balls")[0]
	portal_probe.global_position = Vector3(9.0, 2.3, 0.0)
	portal_probe.linear_velocity = Vector3(5.0, 0.0, 0.0)
	var portal_elapsed := 0.0
	while portal_elapsed < 2.0 and scene.portal_count == 0:
		await create_timer(0.1).timeout
		portal_elapsed += 0.1
	assert(scene.portal_count == 1, "Portal did not accept a moving ball")
	assert(portal_probe.global_position.distance_to(scene.get_node("LevelChain").get_child(0).get_node("Entry").global_position + Vector3.UP * 0.65) < 0.01, "Portal did not move the ball to the chain")
	assert(scene.feedback_label.text == "PORTAL", "Portal did not produce interaction feedback")
	scene.call("_on_section_exit_body_entered", portal_probe, 0)
	assert(scene.feedback_label.text == "SECTION 1", "Section exit did not produce progression feedback")
	scene.call("_on_portal_body_entered", portal_probe)
	assert(scene.portal_count == 1, "Portal accepted the same ball more than once")
	quit()
