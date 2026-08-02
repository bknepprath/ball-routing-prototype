extends SceneTree

func _init() -> void:
	var packed_scene := load("res://main.tscn") as PackedScene
	var scene := packed_scene.instantiate()
	root.add_child(scene)
	await process_frame
	await create_timer(5.0).timeout

	var balls := get_nodes_in_group("balls")
	assert(balls.size() > 0, "Room did not spawn balls")
	var moving_walls := get_nodes_in_group("moving_walls")
	assert(moving_walls.size() == 1, "Room is missing the moving wall")
	assert(moving_walls[0].get_node_or_null("CollisionShape3D") != null, "Moving wall has no collision shape")
	var moving_wall_bevel_found := false
	for candidate in moving_walls[0].find_children("*", "MeshInstance3D", true, false):
		var moving_visual := candidate as MeshInstance3D
		if moving_visual != null and moving_visual.mesh == scene.wood_beam_mesh:
			moving_wall_bevel_found = true
			break
	assert(moving_wall_bevel_found, "Moving wall is not using the Blender wood beam")
	assert(scene.get_node_or_null("MovingWallArea/CollisionShape3D") != null, "Moving wall has no contact trigger")
	assert(scene.get_node_or_null("RedStopWall/CollisionShape3D") != null, "Red stop wall has no collision shape")
	assert(scene.get_node_or_null("StopFrame") != null, "Stop gate has no visible support gantry")
	assert(scene.get_node("StopFrame").get_child_count() >= 5, "Stop gate support gantry is incomplete")
	assert(scene.get_node_or_null("FunnelBackGuardrail/CollisionShape3D") != null, "Funnel has no back guardrail")
	assert(scene.get_node_or_null("HopperSupports") != null, "Hopper has no visible support frame")
	assert(scene.get_node("HopperSupports").get_child_count() >= 9, "Hopper support frame is incomplete")
	var island_top := scene.get_node("SkyIsland/IslandTop") as MeshInstance3D
	assert(island_top != null, "Sky island has no top surface")
	var island_mesh := island_top.mesh as CylinderMesh
	var island_top_surface_y := island_top.global_position.y + island_mesh.height * island_top.scale.y * 0.5
	assert(absf(island_top_surface_y - scene.TOWER_BASE_Y) < 0.12, "Sky island top is not aligned with the tower base plane")
	assert(scene.get_node("SkyIsland/IslandClouds").get_child_count() == 8, "Sky island has no underside cloud bank")
	var platform_diagonal := Vector2(scene.sky_island_bounds.size.x, scene.sky_island_bounds.size.z).length()
	assert(island_top.scale.x * 14.2 >= platform_diagonal + 3.9, "Sky island does not cover the complete route footprint")
	assert(island_top.scale.z * 14.2 >= platform_diagonal + 3.9, "Sky island depth does not cover the complete route footprint")
	assert(scene.get_node_or_null("PortalArea/CollisionShape3D") != null, "Portal has no trigger")
	assert(scene.get_node_or_null("Portal") != null, "Portal has no visible ring")
	assert(absf(scene.portal_marker.global_transform.basis.y.dot(Vector3.RIGHT)) > 0.9, "Portal ring is not oriented across the path")
	assert(scene.get_node_or_null("PortalDestination") != null, "Portal has no visible destination")
	assert(scene.get_node_or_null("PaymentLine") != null, "Payment trigger has no visible line")
	assert(scene.get_node_or_null("FinishMarker") != null, "Generated finish marker is missing")
	assert(scene.get_node_or_null("FinishLabel") != null, "Generated finish label is missing")
	assert(scene.finish_marker_from_blender, "Finish marker did not load the Blender-authored asset")
	assert(scene.wood_beam_mesh != null, "Blender-authored wood beam did not load")
	var beveled_visual_found := false
	for candidate in scene.get_node("LevelChain").get_child(0).find_children("*", "MeshInstance3D", true, false):
		var mesh_visual := candidate as MeshInstance3D
		if mesh_visual != null and mesh_visual.mesh == scene.wood_beam_mesh:
			beveled_visual_found = true
			break
	assert(beveled_visual_found, "Generated wood pieces are not using the Blender beam mesh")
	var hidden_curve_collision_visual_found := false
	for piece in scene.get_node("LevelChain").get_children():
		if int(piece.get_meta("section_kind", -1)) not in [2, 7, 10]:
			continue
		for candidate in piece.find_children("*", "MeshInstance3D", true, false):
			var candidate_visual := candidate as MeshInstance3D
			if candidate_visual != null and not candidate_visual.visible:
				hidden_curve_collision_visual_found = true
				break
		if hidden_curve_collision_visual_found:
			break
	assert(hidden_curve_collision_visual_found, "Curved collision-only rails are still rendering")
	var support_visual: MeshInstance3D = null
	var tower_base_member_found := false
	for candidate in scene.get_node("TowerStructure").find_children("*", "MeshInstance3D", true, false):
		var tower_mesh_visual := candidate as MeshInstance3D
		if tower_mesh_visual != null and tower_mesh_visual.mesh == scene.wood_beam_mesh:
			if support_visual == null:
				support_visual = tower_mesh_visual
			assert(tower_mesh_visual.global_position != Vector3.ZERO, "Tower support mesh is still at the origin")
			if tower_mesh_visual.global_position.y < -5.0:
				tower_base_member_found = true
	assert(support_visual != null and support_visual.mesh == scene.wood_beam_mesh, "Tower supports are missing the beveled wood mesh")
	assert(support_visual.material_override == scene.support_material, "Tower supports are not using the support wood finish")
	assert(support_visual.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON, "Tower supports do not cast shadows")
	assert(tower_base_member_found, "Tower support frame does not reach the sky island base")
	assert(scene.get_node("TowerStructure").find_children("SupportFoot*", "MeshInstance3D", true, false).size() >= 22, "Primary tower legs have no grounded footings")
	assert(scene.get_node("TowerStructure").find_children("FoundationFoot*", "MeshInstance3D", true, false).size() == 4, "Foundation rails have no anchored corners")
	var foundation_deck := scene.get_node("TowerStructure/TowerFoundationDeck") as MeshInstance3D
	assert(foundation_deck != null and foundation_deck.material_override == scene.wood_material, "Tower foundation deck is missing its wood finish")
	assert(scene.get_node_or_null("Clouds").get_child_count() == 6, "Sky does not contain six grouped clouds")
	assert(scene.get_node_or_null("Clouds/Cloud0/CloudUnderbelly") != null, "Clouds have no shaded underbelly")
	assert(scene.get_node_or_null("FeedbackLabel") != null, "Interaction feedback label is missing")
	assert(scene.stop_label.no_depth_test and scene.stop_label.pixel_size >= 0.01, "Damage label is not configured for readability")
	assert(not scene.stop_progress.show_percentage, "HUD health strip still shows the default percentage text")
	assert(scene.stop_progress.get_theme_stylebox("fill") != null, "HUD health strip has no themed fill style")
	var options_button := scene.find_child("OptionsButton", true, false)
	assert(options_button != null, "Compact options button is missing")
	var options_container := scene.find_child("Options", true, false)
	assert(options_container != null and not options_container.visible, "Options are expanded by default")
	var first_session_prompt := scene.find_child("FirstSessionPrompt", true, false) as Label
	assert(first_session_prompt != null, "First-session instructions are missing")
	assert(first_session_prompt.text == "Space drops a ball.\nBall impacts open the STOP gate.", "First-session instructions do not explain how to drop a ball and open the STOP gate")
	assert(first_session_prompt.visible, "First-session instructions are hidden by default")
	var drop_ball_button := scene.find_child("DropBallButton", true, false) as Button
	assert(drop_ball_button != null and drop_ball_button.visible, "Primary drop-ball action is hidden by default")
	assert(not options_container.is_ancestor_of(first_session_prompt), "First-session instructions are inside optional controls")
	assert(not options_container.is_ancestor_of(drop_ball_button), "Primary drop-ball action is inside optional controls")
	for required_control in [first_session_prompt, drop_ball_button]:
		var control_rect := required_control.get_global_rect()
		assert(control_rect.position.x >= 0.0 and control_rect.position.y >= 0.0, "%s extends above or left of the 1440x900 viewport" % required_control.name)
		assert(control_rect.end.x <= 1440.0 and control_rect.end.y <= 900.0, "%s extends beyond the 1440x900 viewport" % required_control.name)
	var damage_button := scene.find_child("DamageButton", true, false)
	assert(damage_button != null, "Ball damage upgrade is missing")
	var damage_before: float = scene.ball_damage
	scene.credits = scene.damage_upgrade_cost
	scene.call("_buy_damage_upgrade")
	assert(scene.ball_damage > damage_before, "Ball damage upgrade did not improve damage")
	await process_frame
	assert("Ball damage" in scene.credits_label.text, "HUD does not report current ball damage")
	scene.call("_toggle_ui_options")
	assert(options_container.visible and options_button.text == "Hide options", "Options button did not expand the controls")
	scene.call("_toggle_ui_options")
	assert(not options_container.visible and options_button.text == "Options", "Options button did not collapse the controls")
	assert(scene.get_node_or_null("LevelChain") != null, "Level chain is missing")
	assert(scene.get_node_or_null("LevelSupports") == null, "Level still contains removed support clutter")
	var attachments := get_nodes_in_group("attachments")
	assert(attachments.size() == 11, "Room is missing the eleven generated sections")
	for attachment in attachments:
		assert(attachment.get_node_or_null("Entry") != null, "Attachment has no entry port")
		assert(attachment.get_node_or_null("Exit") != null, "Attachment has no exit port")
		assert(attachment.get_node_or_null("EntryMarker") == null, "Attachment still has a visible debug entry marker")
		assert(attachment.get_node_or_null("ExitMarker") == null, "Attachment still has a visible debug exit marker")
	assert(attachments[1].get_node("Entry").global_position.distance_to(attachments[0].get_node("Exit").global_position) < 0.01, "Attachments are not chained at their ports")
	for index in range(attachments.size() - 1):
		var exit: Marker3D = attachments[index].get_node("Exit")
		var entry: Marker3D = attachments[index + 1].get_node("Entry")
		assert(exit.global_position.distance_to(entry.global_position) < 0.01, "Section %d is not chained at its ports" % index)

	var reached_route := false
	for ball in balls:
		if is_instance_valid(ball) and ball.global_position.x > -8.5:
			reached_route = true
		assert(ball.global_position.x > -10.7, "A ball escaped through the left side of the funnel")
	assert(reached_route, "Balls are not leaving the funnel toward the ramp")
	assert(scene.stop_health < scene.stop_max_health, "Balls are not reaching the red stop wall")
	assert(scene.faded_ball_count > 0, "Red stop wall did not complete a ball fade")
	scene.auto_spawn = false
	for ball in get_nodes_in_group("balls"):
		if is_instance_valid(ball):
			ball.free()
	scene.stop_health = 1
	scene.stop_open = false
	scene.stop_area.monitoring = true
	scene.call("_spawn_ball")
	var stop_probe = get_nodes_in_group("balls")[0]
	stop_probe.global_position = scene.stop_area.global_position - Vector3.RIGHT * 1.0
	stop_probe.linear_velocity = Vector3.RIGHT * 4.0
	await create_timer(0.8).timeout
	assert(scene.stop_open, "Lethal stop hit did not open the entry gate")
	assert(is_instance_valid(stop_probe), "Lethal stop hit removed the traversing ball")
	assert(stop_probe.linear_velocity.x >= 3.8, "Lethal stop hit did not hand the ball forward")
	for ball in get_nodes_in_group("balls"):
		if is_instance_valid(ball):
			ball.free()
	for index in range(320):
		scene.call("_spawn_ball")
	var capped_balls := get_nodes_in_group("balls")
	assert(capped_balls.size() == 300, "Ball physics cap is not enforced")
	assert(capped_balls[0].continuous_cd, "Balls do not use continuous collision detection")
	assert(capped_balls[0].visual.material_override == capped_balls[1].visual.material_override, "Active balls do not share their material")
	assert(capped_balls[0].visual.mesh == capped_balls[1].visual.mesh, "Active balls do not share their mesh")
	assert(capped_balls[0].get_node("CollisionShape3D").shape == capped_balls[1].get_node("CollisionShape3D").shape, "Active balls do not share their collision shape")
	assert(capped_balls[0].physics_material_override == capped_balls[1].physics_material_override, "Active balls do not share their physics material")
	var shadowed_ball_count := 0
	for capped_ball in capped_balls:
		if capped_ball.visual.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			shadowed_ball_count += 1
	assert(shadowed_ball_count <= 80, "High ball counts do not reduce per-ball shadow cost")
	capped_balls[0].call("fade_out")
	assert(capped_balls[0].visual.material_override != capped_balls[1].visual.material_override, "Fading one ball changes the shared material")
	scene.call("_randomize_level")
	await process_frame
	assert(get_nodes_in_group("balls").is_empty(), "Randomizing a level left stale balls in the old route")
	assert(get_nodes_in_group("attachments").size() == 11, "Randomized level does not contain eleven sections")
	assert(scene.get_node("LevelChain").get_child_count() == 11, "Randomized level did not rebuild the chain")
	quit()
