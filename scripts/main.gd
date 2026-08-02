extends Node3D

const Ball = preload("res://scripts/ball.gd")
const Attachment = preload("res://scripts/attachment.gd")
const LEVEL_SECTION_COUNT := 11
const SECTION_KIND_BAG := [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
const MAX_ACTIVE_BALLS := 300
const MAX_BALL_SHADOWS := 80
const ARC_SWEEP := PI
const TOWER_BASE_Y := -5.5

const TRACK_POINTS := [
	Vector3(-9.2, 4.6, 0.0),
	Vector3(-6.0, 4.0, 0.0),
	Vector3(-1.0, 2.5, 0.0),
	Vector3(4.0, 2.0, 0.0),
	Vector3(8.0, 1.8, 0.0),
	Vector3(12.0, 1.6, 0.0),
]
const CHAIN_ANCHOR := Vector3(12.0, 7.2, 0.0)

const STOP_AREA_POSITION := Vector3(4.15, 2.7, 0.0)
const PAYMENT_AREA_POSITION := Vector3(7.0, 2.1, 0.0)
const PORTAL_POSITION := Vector3(10.3, 2.3, 0.0)
const FINISH_AREA_POSITION := Vector3(12.0, 1.7, 0.0)

var ball_root: Node3D
var camera: Camera3D
var stop_area: Area3D
var payment_area: Area3D
var portal_area: Area3D
var flap_area: Area3D
var finish_area: Area3D
var finish_marker: MeshInstance3D
var finish_marker_root: Node3D
var finish_marker_from_blender := false
var finish_label: Label3D
var stop_panel: MeshInstance3D
var stop_wall: StaticBody3D
var stop_label: Label3D
var payment_label: Label3D
var payment_marker: MeshInstance3D
var portal_marker: MeshInstance3D
var portal_destination_marker: MeshInstance3D
var feedback_label: Label3D
var feedback_tween: Tween
var goal_ball: MeshInstance3D
var goal_ball_time := 0.0
var level_chain: Node3D
var max_section_reached := 0
var section_completion_order: Array[int] = []
var boost_count := 0
var portal_count := 0
var flap_hit_count := 0
var conveyor_hit_count := 0
var spinner_hit_count := 0
var gate_hit_count := 0
var stack_pressure_events := 0
var balance_hit_count := 0
var waterfall_hit_count := 0
var finished_ball_count := 0
var faded_ball_count := 0
var motion_assist_count := 0
var section_recovery_count := 0
var booster_markers: Array[Node3D] = []
var section_collars: Array[MeshInstance3D] = []
var balance_beams: Array[Node3D] = []
var flaps: Array[Node3D] = []
var conveyor_rollers: Array[Node3D] = []
var waterfall_pucks: Array[Node3D] = []
var stack_areas: Array[Area3D] = []
var wood_material: Material
var ball_material: Material
var water_material: Material
var ball_mesh: SphereMesh
var ball_shape: SphereShape3D
var ball_physics: PhysicsMaterial
var cloud_groups: Array[Node3D] = []
var sky_island_root: Node3D
var island_cloud_root: Node3D
var sky_island_bounds := AABB()
var tower_root: Node3D
var tower_base_bounds := AABB()
var port_material: Material
var support_material: Material
var port_mesh: TorusMesh
var wood_beam_mesh: Mesh

var camera_focus := Vector3(8.0, 3.6, 0.0)
var camera_distance := 34.0
var camera_yaw := deg_to_rad(38.0)
var camera_pitch := deg_to_rad(30.0)

var spawn_timer := 0.0
var cleanup_timer := 0.0
var spawn_interval := 1.2
var ball_value := 1
var credits := 0
var stop_health := 20
var stop_max_health := 20
var stop_open := false
var auto_spawn := true
var spawn_upgrade_level := 0
var value_upgrade_level := 0
var damage_upgrade_level := 0
var spawn_upgrade_cost := 20
var value_upgrade_cost := 35
var damage_upgrade_cost := 50
var ball_damage := 1.0

var credits_label: Label
var status_label: Label
var section_status_label: Label
var stop_progress: ProgressBar
var stop_progress_fill: StyleBoxFlat
var stop_button: Button
var value_button: Button
var damage_button: Button
var auto_button: Button
var randomize_button: Button
var ui_layer: CanvasLayer
var ui_options: VBoxContainer
var ui_options_button: Button

func _ready() -> void:
	_build_materials()
	_build_world()
	_build_track()
	_build_hopper()
	_build_mechanisms()
	_build_attachments()
	_build_camera()
	_build_ui()
	_spawn_ball()

func _process(delta: float) -> void:
	var travel_input := 0.0
	if Input.is_key_pressed(KEY_W):
		travel_input += 1.0
	if Input.is_key_pressed(KEY_S):
		travel_input -= 1.0
	if travel_input != 0.0 and camera != null:
		var camera_forward := -camera.global_transform.basis.z
		camera_forward.y = 0.0
		camera_focus += camera_forward.normalized() * travel_input * delta * 16.0
	var elevate_input := 0.0
	if Input.is_key_pressed(KEY_E):
		elevate_input += 1.0
	if Input.is_key_pressed(KEY_C):
		elevate_input -= 1.0
	if elevate_input != 0.0:
		camera_focus.y = clamp(camera_focus.y + elevate_input * delta * 10.0, -14.0, 18.0)
	var slide_input := 0.0
	if Input.is_key_pressed(KEY_A):
		slide_input -= 1.0
	if Input.is_key_pressed(KEY_D):
		slide_input += 1.0
	if slide_input != 0.0 and camera != null:
		var camera_right := camera.global_transform.basis.x
		camera_right.y = 0.0
		camera_focus += camera_right.normalized() * slide_input * delta * 10.0

	spawn_timer += delta
	if auto_spawn and spawn_timer >= spawn_interval:
		spawn_timer = 0.0
		_spawn_ball()
	cleanup_timer += delta
	if cleanup_timer >= 0.75:
		cleanup_timer = 0.0
		_cleanup_balls()
	if payment_label != null:
		payment_label.position.y = PAYMENT_AREA_POSITION.y + 2.0 + sin(Time.get_ticks_msec() * 0.004) * 0.14
	if payment_marker != null:
		var payment_pulse := 1.0 + sin(Time.get_ticks_msec() * 0.004) * 0.06
		payment_marker.scale = Vector3.ONE * payment_pulse
	if portal_destination_marker != null:
		var portal_pulse := 1.0 + sin(Time.get_ticks_msec() * 0.004 + PI) * 0.06
		portal_destination_marker.scale = Vector3.ONE * portal_pulse
	if goal_ball != null:
		goal_ball_time = fmod(goal_ball_time + delta, 2.4)
		var goal_progress := goal_ball_time / 2.4
		var feeder_floor_y := lerpf(1.8, 1.66, goal_progress)
		goal_ball.position = Vector3(9.25 + goal_progress * 2.1, feeder_floor_y + 0.46 + sin(goal_progress * PI) * 0.04, 0.0)
	if finish_marker != null:
		var finish_pulse := 1.0 + sin(Time.get_ticks_msec() * 0.004) * 0.06
		var finish_node: Node3D = finish_marker_root if finish_marker_root != null else finish_marker
		finish_node.scale = Vector3.ONE * finish_pulse
	var cloud_time := Time.get_ticks_msec() * 0.00005
	for index in range(cloud_groups.size()):
		var cloud_group := cloud_groups[index]
		if not is_instance_valid(cloud_group):
			continue
		var base_position: Vector3 = cloud_group.get_meta("base_position", cloud_group.position)
		var phase := float(index) * 0.8
		cloud_group.position = base_position + Vector3(sin(cloud_time + phase) * 0.6, sin(cloud_time * 0.7 + phase) * 0.08, 0.0)
	for index in range(booster_markers.size()):
		var marker := booster_markers[index]
		if is_instance_valid(marker):
			var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.006 - float(index) * 0.7) * 0.08
			marker.scale = Vector3(pulse, 1.0, pulse)
	for index in range(section_collars.size()):
		var collar := section_collars[index]
		if not is_instance_valid(collar):
			continue
		var collar_material := collar.material_override as StandardMaterial3D
		if collar_material != null and collar_material.albedo_color.is_equal_approx(Color("65e8f2")):
			var collar_pulse := 1.0 + sin(Time.get_ticks_msec() * 0.005) * 0.07
			collar.scale = Vector3.ONE * collar_pulse
		else:
			collar.scale = Vector3.ONE

	_update_camera(delta)
	_update_ui()

func _physics_process(delta: float) -> void:
	for flap in flaps:
		flap.rotate_y(delta * 1.8)
	for balance_beam in balance_beams:
		if is_instance_valid(balance_beam):
			balance_beam.rotation.x = sin(Time.get_ticks_msec() * 0.003 + balance_beam.get_instance_id() * 0.01) * 0.18
	for roller in conveyor_rollers:
		if is_instance_valid(roller):
			roller.rotate_z(delta * 5.0)
	for puck in waterfall_pucks:
		if is_instance_valid(puck):
			puck.rotate_y(delta * 2.4)
			var puck_base: Vector3 = puck.get_meta("base_position", puck.position)
			var puck_phase := float(puck.get_meta("phase", 0.0))
			puck.position = puck_base + Vector3(sin(Time.get_ticks_msec() * 0.004 + puck_phase) * 0.08, 0.0, 0.0)
	var active_stack_areas: Array[Area3D] = []
	for stack_area in stack_areas:
		if not is_instance_valid(stack_area):
			continue
		active_stack_areas.append(stack_area)
		var stack_balls: Array[RigidBody3D] = []
		# ponytail: cap pile inspection at eight bodies; use a pooled tracker only if larger piles matter.
		for body in stack_area.get_overlapping_bodies():
			if body.is_in_group("balls"):
				var ball := body as RigidBody3D
				if ball != null:
					stack_balls.append(ball)
				if stack_balls.size() >= 8:
					break
		if stack_balls.size() < 2:
			continue
		stack_pressure_events += 1
		var lift_force := minf(float(stack_balls.size() - 1), 4.0) * 3.5
		for ball in stack_balls:
			ball.apply_central_force(Vector3.UP * lift_force)
	stack_areas = active_stack_areas
	_apply_motion_assist(delta)

func _apply_motion_assist(delta: float) -> void:
	for body in get_tree().get_nodes_in_group("balls"):
		var ball := body as RigidBody3D
		if ball == null or ball.collision_layer == 0:
			continue
		var position := ball.global_position
		if position.x >= -8.8 and position.x <= 9.6 and position.y >= 1.0 and position.y <= 9.8 and absf(position.z) <= 2.8:
			# The feeder is a long gravity ramp. This small drive prevents a crowded
			# queue from cancelling its forward motion while preserving lateral bumps.
			ball.apply_central_force(Vector3.RIGHT * 1.8)
			if position.x > -7.8 and ball.linear_velocity.x < 2.1:
				ball.linear_velocity.x = minf(2.1, ball.linear_velocity.x + delta * 3.2)
			if absf(position.z) > 1.35:
				ball.apply_central_force(Vector3(0.0, 0.0, -signf(position.z) * 1.4))

		if not ball.get_meta("portal_used", false) or level_chain == null:
			ball.set_meta("assist_stall_time", 0.0)
			continue
		var expected_index := int(ball.get_meta("expected_section", 0))
		if expected_index < 0 or expected_index >= level_chain.get_child_count():
			continue
		var piece: Node3D = level_chain.get_child(expected_index)
		var path_sample := _section_path_sample(piece, piece.to_local(position))
		var progress := float(path_sample.get("progress", -1.0))
		if progress < 0.0:
			var fallback_tangent := _section_fallback_tangent(piece, position)
			if fallback_tangent.length_squared() < 0.001:
				ball.set_meta("assist_stall_time", 0.0)
				continue
			path_sample = {"progress": 0.5, "tangent": fallback_tangent}
			progress = 0.5
		var tangent_local: Vector3 = path_sample.get("tangent", Vector3.RIGHT)
		var tangent := (piece.global_transform.basis * tangent_local).normalized()
		var forward_speed := ball.linear_velocity.dot(tangent)
		var stall_time := float(ball.get_meta("assist_stall_time", 0.0))
		if forward_speed < 1.75:
			stall_time += delta
		else:
			stall_time = maxf(0.0, stall_time - delta * 2.0)
		ball.set_meta("assist_stall_time", stall_time)
		if stall_time < 0.4:
			continue
		var target_velocity := tangent * 3.4 + Vector3.UP * 0.08
		ball.linear_velocity = ball.linear_velocity.lerp(target_velocity, minf(delta * 8.0, 1.0))
		ball.sleeping = false
		motion_assist_count += 1
		if stall_time >= 1.8:
			ball.global_position += tangent * 0.18 + Vector3.UP * 0.06
			ball.linear_velocity = tangent * 3.5 + Vector3.UP * 0.12
			ball.set_meta("assist_stall_time", 0.0)
			section_recovery_count += 1

func _section_path_sample(piece: Node3D, local_position: Vector3) -> Dictionary:
	var kind := int(piece.get_meta("section_kind", -1))
	if kind in [2, 7]:
		var radius := float(piece.get_meta("arc_radius", 1.5))
		var vertical_delta := float(piece.get_meta("arc_vertical_delta", 0.0))
		var turn_sign := float(piece.get_meta("turn_sign", 1.0))
		var radial_z := (local_position.z - turn_sign * radius) * turn_sign
		var theta := atan2(radial_z, local_position.x)
		if theta < -PI * 0.5 - 0.35 or theta > PI * 0.5 + 0.35:
			return {"progress": -1.0, "tangent": Vector3.RIGHT}
		var progress := clampf((theta + PI * 0.5) / PI, 0.0, 1.0)
		var expected_point := _arc_point(radius, vertical_delta, progress, turn_sign)
		if absf(local_position.y - expected_point.y) > 1.45 or absf(Vector2(local_position.x, local_position.z - turn_sign * radius).length() - radius) > 1.0:
			return {"progress": -1.0, "tangent": Vector3.RIGHT}
		var tangent := _arc_point(radius, vertical_delta, minf(progress + 0.02, 1.0), turn_sign) - _arc_point(radius, vertical_delta, maxf(progress - 0.02, 0.0), turn_sign)
		return {"progress": progress, "tangent": tangent.normalized()}
	if kind == 10:
		var serpentine_length := float(piece.get_meta("serpentine_length", 5.2))
		var serpentine_amplitude := float(piece.get_meta("serpentine_amplitude", 1.0))
		if local_position.x < -0.8 or local_position.x > serpentine_length + 0.8:
			return {"progress": -1.0, "tangent": Vector3.RIGHT}
		var progress := clampf(local_position.x / serpentine_length, 0.0, 1.0)
		var expected_point := _serpentine_point(progress, serpentine_length, serpentine_amplitude)
		if absf(local_position.y - expected_point.y) > 1.45 or absf(local_position.z - expected_point.z) > 1.8:
			return {"progress": -1.0, "tangent": Vector3.RIGHT}
		var tangent := _serpentine_point(minf(progress + 0.02, 1.0), serpentine_length, serpentine_amplitude) - _serpentine_point(maxf(progress - 0.02, 0.0), serpentine_length, serpentine_amplitude)
		return {"progress": progress, "tangent": tangent.normalized()}
	var exit_port := piece.get_node("Exit") as Marker3D
	var exit_position := exit_port.position
	var route_length := maxf(exit_position.x, 2.6)
	if local_position.x < -0.8 or local_position.x > route_length + 0.8 or absf(local_position.z) > 1.8 or absf(local_position.y) > 2.5:
		return {"progress": -1.0, "tangent": Vector3.RIGHT}
	return {"progress": clampf(local_position.x / route_length, 0.0, 1.0), "tangent": exit_position.normalized()}

func _section_fallback_tangent(piece: Node3D, world_position: Vector3) -> Vector3:
	var local_position := piece.to_local(world_position)
	var kind := int(piece.get_meta("section_kind", -1))
	var local_span := 2.6
	if kind in [2, 7]:
		local_span = maxf(4.5, float(piece.get_meta("arc_radius", 1.5)) * 2.0 + 1.2)
	elif kind == 10:
		local_span = float(piece.get_meta("serpentine_length", 5.2)) + 1.2
	if local_position.x < -1.2 or local_position.x > local_span or absf(local_position.y) > 3.2 or absf(local_position.z) > 3.0:
		return Vector3.ZERO
	var exit_port := piece.get_node("Exit") as Marker3D
	var to_exit := exit_port.global_position - world_position
	if to_exit.length_squared() < 0.01:
		return piece.global_transform.basis.x.normalized()
	return to_exit.normalized()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE) and Input.is_key_pressed(KEY_SHIFT):
			var pan_scale := camera_distance * 0.002
			camera_focus += (-camera.global_transform.basis.x * event.relative.x + camera.global_transform.basis.y * event.relative.y) * pan_scale
		elif Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
			camera_yaw -= event.relative.x * 0.008
			camera_pitch = clamp(camera_pitch + event.relative.y * 0.008, deg_to_rad(12.0), deg_to_rad(72.0))
		return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera_distance = maxf(10.0, camera_distance - 2.0)
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera_distance = minf(52.0, camera_distance + 2.0)
			return

	if event is not InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_SPACE:
			_spawn_ball()
		KEY_1:
			_buy_spawn_upgrade()
		KEY_2:
			_buy_value_upgrade()
		KEY_3:
			_buy_damage_upgrade()
		KEY_T:
			_toggle_auto_spawn()
		KEY_G:
			_randomize_level()
		KEY_TAB:
			if ui_layer != null:
				ui_layer.visible = not ui_layer.visible
		KEY_R:
			_reset_camera()

func _build_materials() -> void:
	var wood_shader := Shader.new()
	wood_shader.code = """
shader_type spatial;
render_mode cull_disabled;

void fragment() {
	float grain = sin(UV.y * 26.0 + sin(UV.x * 6.0) * 1.5) * 0.5 + 0.5;
	float fine_grain = sin(UV.y * 96.0 + UV.x * 3.0) * 0.5 + 0.5;
	float knots = sin(UV.y * 7.0 + sin(UV.x * 4.0) * 2.0) * 0.5 + 0.5;
	vec3 dark_wood = vec3(0.07, 0.022, 0.006);
	vec3 light_wood = vec3(0.30, 0.105, 0.022);
	float tone = clamp(0.48 + (grain - 0.5) * 0.28 + (fine_grain - 0.5) * 0.05 + (knots - 0.5) * 0.09, 0.0, 1.0);
	ALBEDO = mix(dark_wood, light_wood, tone);
	ROUGHNESS = 0.86;
}
"""
	var wood := ShaderMaterial.new()
	wood.shader = wood_shader
	wood_material = wood
	var wood_beam_scene := load("res://assets/wood_beam.glb") as PackedScene
	if wood_beam_scene != null:
		var imported_root := wood_beam_scene.instantiate() as Node3D
		if imported_root != null:
			var imported_beam := imported_root as MeshInstance3D
			if imported_beam == null:
				imported_beam = imported_root.find_child("WoodBeam", true, false) as MeshInstance3D
			if imported_beam != null:
				wood_beam_mesh = imported_beam.mesh
			imported_root.free()
	port_material = _make_material(Color("d39a45"), Color("3d1d05"))
	support_material = _make_material(Color("48230f"), Color("0b0301"))
	port_mesh = TorusMesh.new()
	port_mesh.inner_radius = 0.82
	port_mesh.outer_radius = 0.94
	var polished_ball := _make_material(_ball_color())
	polished_ball.roughness = 0.28
	polished_ball.metallic = 0.08
	polished_ball.clearcoat = 0.32
	polished_ball.clearcoat_roughness = 0.16
	polished_ball.emission_enabled = true
	polished_ball.emission = Color("4f0b16")
	polished_ball.emission_energy_multiplier = 0.3
	ball_material = polished_ball
	var water_shader := Shader.new()
	water_shader.code = """
shader_type spatial;
render_mode cull_disabled;

void fragment() {
	float flow = sin(UV.x * 16.0 - TIME * 4.0 + sin(UV.y * 5.0) * 2.0) * 0.5 + 0.5;
	float sparkle = sin(UV.y * 30.0 + TIME * 6.0) * 0.5 + 0.5;
	vec3 deep_water = vec3(0.03, 0.35, 0.52);
	vec3 bright_water = vec3(0.25, 0.88, 0.96);
	ALBEDO = mix(deep_water, bright_water, flow * 0.65 + sparkle * 0.35);
	EMISSION = ALBEDO * 0.35;
	ROUGHNESS = 0.24;
}
"""
	var water := ShaderMaterial.new()
	water.shader = water_shader
	water_material = water
	ball_mesh = SphereMesh.new()
	ball_mesh.radius = 0.45
	ball_mesh.height = 0.9
	ball_shape = SphereShape3D.new()
	ball_shape.radius = 0.45
	ball_physics = PhysicsMaterial.new()
	ball_physics.bounce = 0.28
	ball_physics.friction = 0.2

func _build_world() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("1b609b")
	sky_material.sky_horizon_color = Color("79c8e9")
	sky_material.ground_horizon_color = Color("5b9fbe")
	sky_material.ground_bottom_color = Color("315f80")
	sky_material.sun_angle_max = 18.0
	sky_material.sun_curve = 0.08
	var sky := Sky.new()
	sky.sky_material = sky_material
	environment.sky = sky
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 0.78
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("a2c9df")
	environment.ambient_light_energy = 0.52
	environment.fog_enabled = true
	environment.fog_light_color = Color("b9e8ff")
	environment.fog_density = 0.0018
	world.environment = environment
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	sun.light_energy = 0.95
	sun.shadow_enabled = true
	add_child(sun)

	_build_clouds()
	_build_sky_island()

	ball_root = Node3D.new()
	ball_root.name = "Balls"
	add_child(ball_root)

func _build_sky_island() -> void:
	var island_root := Node3D.new()
	sky_island_root = island_root
	island_root.name = "SkyIsland"
	add_child(island_root)
	var island_material := _make_material(Color("31536a"), Color("102332"))
	var island := MeshInstance3D.new()
	island.name = "IslandUnderside"
	var island_mesh := CylinderMesh.new()
	island_mesh.top_radius = 8.0
	island_mesh.bottom_radius = 6.3
	island_mesh.height = 1.1
	island.mesh = island_mesh
	island.position = Vector3(8.0, TOWER_BASE_Y - 0.8, 0.0)
	island.material_override = island_material
	island.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	island_root.add_child(island)
	var island_top := MeshInstance3D.new()
	island_top.name = "IslandTop"
	var top_mesh := CylinderMesh.new()
	top_mesh.top_radius = 7.1
	top_mesh.bottom_radius = 7.1
	top_mesh.height = 0.16
	island_top.mesh = top_mesh
	island_top.position = Vector3(8.0, TOWER_BASE_Y, 0.0)
	var island_top_shader := Shader.new()
	island_top_shader.code = """
shader_type spatial;
render_mode cull_disabled;

void fragment() {
	vec2 centered_uv = UV - vec2(0.5);
	float broad_rings = sin(length(centered_uv) * 28.0) * 0.5 + 0.5;
	float soft_grain = sin(UV.x * 34.0 + sin(UV.y * 8.0) * 1.4) * 0.5 + 0.5;
	vec3 deep_teal = vec3(0.12, 0.28, 0.32);
	vec3 light_teal = vec3(0.26, 0.48, 0.49);
	float tone = clamp(0.34 + broad_rings * 0.12 + soft_grain * 0.08, 0.0, 1.0);
	ALBEDO = mix(deep_teal, light_teal, tone);
	ROUGHNESS = 0.9;
}
"""
	var island_top_material := ShaderMaterial.new()
	island_top_material.shader = island_top_shader
	island_top.material_override = island_top_material
	island_root.add_child(island_top)
	var island_cloud_material := _make_material(Color("eaf8ff"))
	for index in range(5):
		var cloud := MeshInstance3D.new()
		var cloud_mesh := SphereMesh.new()
		cloud_mesh.radius = 1.55
		cloud_mesh.height = 1.8
		cloud.mesh = cloud_mesh
		cloud.scale = Vector3(1.2, 0.38, 0.85)
		cloud.position = Vector3(3.4 + float(index) * 2.25, TOWER_BASE_Y - 1.55 - float(index % 2) * 0.25, -1.0 + float(index % 3) * 0.75)
		cloud.material_override = island_cloud_material
		cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		island_root.add_child(cloud)

	island_cloud_root = Node3D.new()
	island_cloud_root.name = "IslandClouds"
	island_cloud_root.position = Vector3(8.0, TOWER_BASE_Y - 1.35, 0.0)
	island_root.add_child(island_cloud_root)
	var island_cloud_offsets: Array[Vector2] = [
		Vector2(-0.78, 0.46),
		Vector2(-0.38, 0.7),
		Vector2(0.05, 0.78),
		Vector2(0.48, 0.62),
		Vector2(0.78, 0.34),
		Vector2(-0.56, -0.52),
		Vector2(0.12, -0.72),
		Vector2(0.66, -0.5),
	]
	for index in range(island_cloud_offsets.size()):
		var cloud := MeshInstance3D.new()
		cloud.name = "IslandCloud%d" % index
		var cloud_mesh := SphereMesh.new()
		cloud_mesh.radius = 1.55
		cloud_mesh.height = 1.9
		cloud.mesh = cloud_mesh
		cloud.scale = Vector3(1.35 + float(index % 3) * 0.18, 0.42 + float(index % 2) * 0.08, 0.9)
		cloud.set_meta("radial_offset", island_cloud_offsets[index])
		cloud.material_override = island_cloud_material
		cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		island_cloud_root.add_child(cloud)

func _build_clouds() -> void:
	var cloud_root := Node3D.new()
	cloud_root.name = "Clouds"
	add_child(cloud_root)
	var cloud_material := _make_material(Color("f4fbff"))
	var cloud_shadow_material := _make_material(Color("c5e1ee"))
	var cloud_positions: Array[Vector3] = [
		Vector3(-13.0, 11.0, -18.0),
		Vector3(-3.0, 14.0, -24.0),
		Vector3(9.0, 10.0, -20.0),
		Vector3(21.0, 15.0, -26.0),
		Vector3(34.0, 11.5, -18.0),
		Vector3(46.0, 16.0, -24.0),
	]
	var puff_offsets: Array[Vector3] = [Vector3(-1.1, 0.0, 0.0), Vector3(0.0, 0.42, 0.0), Vector3(1.2, 0.05, 0.0)]
	for index in range(cloud_positions.size()):
		var cloud_group := Node3D.new()
		cloud_group.name = "Cloud%d" % index
		cloud_group.position = cloud_positions[index]
		cloud_group.set_meta("base_position", cloud_positions[index])
		cloud_root.add_child(cloud_group)
		cloud_groups.append(cloud_group)
		var underbelly := MeshInstance3D.new()
		underbelly.name = "CloudUnderbelly"
		var underbelly_mesh := SphereMesh.new()
		underbelly_mesh.radius = 1.5
		underbelly_mesh.height = 2.0
		underbelly.mesh = underbelly_mesh
		underbelly.position = Vector3(0.0, -0.2, 0.08)
		underbelly.scale = Vector3(1.55 + (index % 2) * 0.15, 0.28, 0.96)
		underbelly.material_override = cloud_shadow_material
		underbelly.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cloud_group.add_child(underbelly)
		for puff_index in range(puff_offsets.size()):
			var cloud := MeshInstance3D.new()
			var cloud_mesh := SphereMesh.new()
			cloud_mesh.radius = 1.5
			cloud_mesh.height = 2.0
			cloud.mesh = cloud_mesh
			cloud.position = puff_offsets[puff_index]
			var puff_height := 0.95 if puff_index == 1 else 0.7
			cloud.scale = Vector3(1.35 + (index % 3) * 0.2, puff_height, 0.9)
			cloud.material_override = cloud_material
			cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			cloud_group.add_child(cloud)

func _build_track() -> void:
	for index in range(TRACK_POINTS.size() - 1):
		_create_track_segment(TRACK_POINTS[index], TRACK_POINTS[index + 1])
	_build_ramp_visual()
	_build_track_supports()

func _create_track_segment(start: Vector3, finish: Vector3) -> void:
	var direction := finish - start
	var length := direction.length()
	var body := StaticBody3D.new()
	body.position = (start + finish) * 0.5
	body.basis = Basis.looking_at(direction.normalized(), Vector3.UP)
	add_child(body)

	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(3.4, 0.45, length)
	floor_shape.shape = floor_box
	floor_shape.position = Vector3(0.0, -0.2, 0.0)
	body.add_child(floor_shape)

	for side in [-1.0, 1.0]:
		var wall_shape := CollisionShape3D.new()
		var wall_box := BoxShape3D.new()
		wall_box.size = Vector3(0.3, 1.2, length)
		wall_shape.shape = wall_box
		wall_shape.position = Vector3(side * 1.65, 0.4, 0.0)
		body.add_child(wall_shape)


func _build_ramp_visual() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(TRACK_POINTS.size() - 1):
		var start: Vector3 = TRACK_POINTS[index]
		var finish: Vector3 = TRACK_POINTS[index + 1]
		var left_start: Vector3 = start + Vector3(0.0, 0.0, -1.65)
		var right_start: Vector3 = start + Vector3(0.0, 0.0, 1.65)
		var left_finish: Vector3 = finish + Vector3(0.0, 0.0, -1.65)
		var right_finish: Vector3 = finish + Vector3(0.0, 0.0, 1.65)
		_add_mesh_quad(surface, left_start, right_start, right_finish, left_finish)
		_add_mesh_quad(surface, left_start - Vector3.UP * 0.35, left_finish - Vector3.UP * 0.35, right_finish - Vector3.UP * 0.35, right_start - Vector3.UP * 0.35)
		_add_mesh_quad(surface, left_start, left_finish, left_finish + Vector3.UP * 1.2, left_start + Vector3.UP * 1.2)
		_add_mesh_quad(surface, right_start, right_start + Vector3.UP * 1.2, right_finish + Vector3.UP * 1.2, right_finish)

	surface.generate_normals()
	var visual := MeshInstance3D.new()
	visual.mesh = surface.commit()
	visual.material_override = wood_material
	visual.name = "ContinuousRamp"
	add_child(visual)
	var plank_root := Node3D.new()
	plank_root.name = "FeederPlanks"
	add_child(plank_root)
	for index in range(TRACK_POINTS.size() - 1):
		var start: Vector3 = TRACK_POINTS[index]
		var finish: Vector3 = TRACK_POINTS[index + 1]
		var segment := finish - start
		var plank_count := maxi(1, int(segment.length() / 1.25))
		for plank_index in range(plank_count):
			var progress := (float(plank_index) + 0.5) / float(plank_count)
			var point := start.lerp(finish, progress) + Vector3.UP * 0.03
			_add_visual_beam(plank_root, point, Vector3(0.12, 0.08, 3.05), _basis_from_tangent(segment), wood_material)

func _build_track_supports() -> void:
	var support_root := Node3D.new()
	support_root.name = "FeederSupports"
	add_child(support_root)
	for index in range(1, TRACK_POINTS.size(), 2):
		var point: Vector3 = TRACK_POINTS[index]
		var support_top := point - Vector3.UP * 0.28
		for side in [-1.0, 1.0]:
			var top := support_top + Vector3(0.0, 0.0, side * 1.35)
			var bottom := Vector3(top.x, TOWER_BASE_Y + 0.12, top.z)
			_add_visual_beam_between(support_root, bottom, top, 0.2, support_material)
			_add_visual_beam(support_root, bottom, Vector3(0.82, 0.18, 0.82), Basis.IDENTITY, support_material)
		_add_visual_beam(support_root, support_top, Vector3(0.22, 0.22, 3.1), Basis.IDENTITY, support_material)
	for side in [-1.0, 1.0]:
		var previous := TRACK_POINTS[0] + Vector3(0.0, 0.68, side * 1.55)
		for index in range(1, TRACK_POINTS.size()):
			var next_point: Vector3 = TRACK_POINTS[index] + Vector3(0.0, 0.68, side * 1.55)
			_add_visual_beam_between(support_root, previous, next_point, 0.18, wood_material)
			previous = next_point

func _add_mesh_quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	surface.set_uv(Vector2(0.0, 0.0))
	surface.add_vertex(a)
	surface.set_uv(Vector2(1.0, 0.0))
	surface.add_vertex(b)
	surface.set_uv(Vector2(1.0, 1.0))
	surface.add_vertex(c)
	surface.set_uv(Vector2(0.0, 0.0))
	surface.add_vertex(a)
	surface.set_uv(Vector2(1.0, 1.0))
	surface.add_vertex(c)
	surface.set_uv(Vector2(0.0, 1.0))
	surface.add_vertex(d)

func _build_hopper() -> void:
	var hopper_support_root := Node3D.new()
	hopper_support_root.name = "HopperSupports"
	add_child(hopper_support_root)
	for x_side in [-1.0, 1.0]:
		for z_side in [-1.0, 1.0]:
			var top := Vector3(-9.2 + x_side * 1.2, 5.45, z_side * 1.35)
			var bottom := Vector3(top.x, TOWER_BASE_Y + 0.12, top.z)
			_add_visual_beam_between(hopper_support_root, bottom, top, 0.2, support_material)
			_add_visual_beam(hopper_support_root, bottom, Vector3(0.82, 0.18, 0.82), Basis.IDENTITY, support_material)
	_add_visual_beam(hopper_support_root, Vector3(-9.2, 5.35, 0.0), Vector3(2.7, 0.22, 0.22), Basis.IDENTITY, support_material)

	var funnel_body := StaticBody3D.new()
	funnel_body.name = "OpenFunnel"
	add_child(funnel_body)

	_add_funnel_panel(funnel_body, Vector3(-9.2, 6.5, 1.8), Vector3(3.4, 4.6, 0.18), Vector3(deg_to_rad(20.0), 0.0, 0.0))
	_add_funnel_panel(funnel_body, Vector3(-9.2, 6.5, -1.8), Vector3(3.4, 4.6, 0.18), Vector3(deg_to_rad(-20.0), 0.0, 0.0))
	_add_funnel_panel(funnel_body, Vector3(-10.85, 6.3, 0.0), Vector3(0.18, 4.4, 5.2), Vector3.ZERO)
	var guardrail := _add_attachment_box(self, Vector3(-9.85, 5.2, 0.0), Vector3(0.3, 1.3, 3.8), Vector3.ZERO, wood_material)
	guardrail.name = "FunnelBackGuardrail"

	var funnel_visual := MeshInstance3D.new()
	var funnel_mesh := CylinderMesh.new()
	funnel_mesh.top_radius = 2.4
	funnel_mesh.bottom_radius = 0.7
	funnel_mesh.height = 3.0
	funnel_mesh.cap_top = false
	funnel_mesh.cap_bottom = false
	funnel_visual.mesh = funnel_mesh
	funnel_visual.position = Vector3(-9.2, 6.9, 0.0)
	funnel_visual.material_override = wood_material
	add_child(funnel_visual)

	var funnel_lip := MeshInstance3D.new()
	var funnel_lip_mesh := TorusMesh.new()
	funnel_lip_mesh.inner_radius = 2.2
	funnel_lip_mesh.outer_radius = 2.4
	funnel_lip.mesh = funnel_lip_mesh
	funnel_lip.position = Vector3(-9.2, 8.5, 0.0)
	funnel_lip.material_override = wood_material
	add_child(funnel_lip)

	var spawn_marker := MeshInstance3D.new()
	var spawn_marker_mesh := TorusMesh.new()
	spawn_marker_mesh.inner_radius = 0.55
	spawn_marker_mesh.outer_radius = 0.72
	spawn_marker.mesh = spawn_marker_mesh
	spawn_marker.position = Vector3(-9.2, 9.0, 0.0)
	spawn_marker.material_override = _make_material(Color("c92d3b"), Color("5c1018"))
	add_child(spawn_marker)

func _add_funnel_panel(body: StaticBody3D, position: Vector3, size: Vector3, rotation: Vector3) -> void:
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.position = position
	collision.rotation = rotation
	body.add_child(collision)


func _build_mechanisms() -> void:
	stop_area = _make_area(STOP_AREA_POSITION, Vector3(1.0, 2.5, 3.0))
	stop_area.body_entered.connect(_on_stop_body_entered)

	stop_panel = MeshInstance3D.new()
	var panel_mesh := BoxMesh.new()
	panel_mesh.size = Vector3(0.45, 2.1, 3.2)
	stop_panel.mesh = panel_mesh
	stop_panel.position = Vector3(4.7, 3.0, 0.0)
	stop_panel.material_override = _make_material(Color("c92d3b"), Color("5c1018"))
	add_child(stop_panel)

	stop_wall = StaticBody3D.new()
	stop_wall.name = "RedStopWall"
	stop_wall.position = stop_panel.position
	var stop_collision := CollisionShape3D.new()
	var stop_shape := BoxShape3D.new()
	stop_shape.size = panel_mesh.size
	stop_collision.shape = stop_shape
	stop_wall.add_child(stop_collision)
	var stop_physics := PhysicsMaterial.new()
	stop_physics.bounce = 0.82
	stop_physics.friction = 0.12
	stop_wall.physics_material_override = stop_physics
	add_child(stop_wall)

	stop_label = Label3D.new()
	stop_label.text = "DAMAGE"
	stop_label.position = Vector3(4.7, 4.35, 0.0)
	stop_label.font_size = 64
	stop_label.pixel_size = 0.01
	stop_label.outline_size = 8
	stop_label.no_depth_test = true
	stop_label.modulate = Color("ff8a8a")
	stop_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(stop_label)

	var stop_frame := Node3D.new()
	stop_frame.name = "StopFrame"
	add_child(stop_frame)
	for side in [-1.0, 1.0]:
		var frame_bottom := Vector3(stop_panel.position.x, TOWER_BASE_Y + 0.12, side * 1.62)
		var frame_top := Vector3(stop_panel.position.x, 8.45, side * 1.62)
		_add_visual_beam_between(stop_frame, frame_bottom, frame_top, 0.2, support_material)
		_add_visual_beam(stop_frame, frame_bottom, Vector3(0.82, 0.18, 0.82), Basis.IDENTITY, support_material)
	_add_visual_beam_between(
		stop_frame,
		Vector3(stop_panel.position.x, 8.35, -1.62),
		Vector3(stop_panel.position.x, 8.35, 1.62),
		0.2,
		support_material
	)

	payment_area = _make_area(PAYMENT_AREA_POSITION, Vector3(0.35, 2.5, 3.0))
	payment_area.body_entered.connect(_on_payment_body_entered)

	payment_marker = MeshInstance3D.new()
	payment_marker.name = "PaymentLine"
	var payment_mesh := TorusMesh.new()
	payment_mesh.inner_radius = 1.08
	payment_mesh.outer_radius = 1.2
	payment_marker.mesh = payment_mesh
	payment_marker.rotation.z = PI * 0.5
	payment_marker.position = PAYMENT_AREA_POSITION
	payment_marker.material_override = _make_material(Color("f3bf4f"), Color("8a4e05"))
	add_child(payment_marker)

	payment_label = Label3D.new()
	payment_label.name = "PaymentLabel"
	payment_label.text = "$ +1"
	payment_label.position = PAYMENT_AREA_POSITION + Vector3(0.0, 2.0, 0.0)
	payment_label.font_size = 48
	payment_label.pixel_size = 0.01
	payment_label.outline_size = 8
	payment_label.no_depth_test = true
	payment_label.modulate = Color("f3bf4f")
	payment_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(payment_label)

	feedback_label = Label3D.new()
	feedback_label.name = "FeedbackLabel"
	feedback_label.font_size = 64
	feedback_label.pixel_size = 0.01
	feedback_label.outline_size = 8
	feedback_label.no_depth_test = true
	feedback_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	feedback_label.visible = false
	add_child(feedback_label)

	finish_area = _make_area(FINISH_AREA_POSITION, Vector3(1.0, 2.5, 3.0))
	finish_area.body_entered.connect(_on_finish_body_entered)
	var finish_asset_scene := load("res://assets/finish_frame.glb") as PackedScene
	if finish_asset_scene != null:
		var imported_root := finish_asset_scene.instantiate() as Node3D
		if imported_root != null:
			var imported_marker := imported_root as MeshInstance3D
			if imported_marker == null:
				imported_marker = imported_root.find_child("FinishFrame", true, false) as MeshInstance3D
			if imported_marker != null:
				finish_marker_root = imported_root
				finish_marker = imported_marker
				finish_marker_from_blender = true
				finish_marker_root.name = "FinishMarker"
				add_child(finish_marker_root)
	if finish_marker == null:
		finish_marker = MeshInstance3D.new()
		finish_marker_root = finish_marker
		finish_marker.name = "FinishMarker"
		var finish_mesh := TorusMesh.new()
		finish_mesh.inner_radius = 1.15
		finish_mesh.outer_radius = 1.38
		finish_marker.mesh = finish_mesh
		finish_marker.material_override = _make_material(Color("f3bf4f"), Color("9b5f12"))
		add_child(finish_marker)
	finish_label = Label3D.new()
	finish_label.name = "FinishLabel"
	finish_label.text = "FINISH"
	finish_label.font_size = 42
	finish_label.pixel_size = 0.01
	finish_label.outline_size = 7
	finish_label.no_depth_test = true
	finish_label.modulate = Color("ffd363")
	finish_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(finish_label)

	var flap_root := AnimatableBody3D.new()
	flap_root.position = Vector3(8.8, 2.9, 0.0)
	flap_root.add_to_group("moving_walls")
	add_child(flap_root)
	for offset in [-0.9, 0.9]:
		var flap := MeshInstance3D.new()
		var flap_mesh := BoxMesh.new()
		flap_mesh.size = Vector3(0.25, 1.8, 2.5)
		if wood_beam_mesh != null:
			flap.mesh = wood_beam_mesh
			flap.scale = flap_mesh.size
		else:
			flap.mesh = flap_mesh
		flap.position = Vector3(0.0, 0.0, offset)
		flap.material_override = wood_material
		flap_root.add_child(flap)

		var flap_collision := CollisionShape3D.new()
		var flap_shape := BoxShape3D.new()
		flap_shape.size = flap_mesh.size
		flap_collision.shape = flap_shape
		flap_collision.position = flap.position
		flap_root.add_child(flap_collision)
	flaps.append(flap_root)

	flap_area = Area3D.new()
	flap_area.name = "MovingWallArea"
	flap_area.collision_layer = 0
	flap_area.collision_mask = 1
	var flap_area_collision := CollisionShape3D.new()
	var flap_area_shape := BoxShape3D.new()
	flap_area_shape.size = Vector3(0.9, 2.4, 4.4)
	flap_area_collision.shape = flap_area_shape
	flap_area.add_child(flap_area_collision)
	flap_area.position = flap_root.position
	flap_area.body_entered.connect(_on_flap_body_entered)
	add_child(flap_area)

	portal_marker = MeshInstance3D.new()
	portal_marker.name = "Portal"
	var portal_mesh := TorusMesh.new()
	portal_mesh.inner_radius = 1.45
	portal_mesh.outer_radius = 1.7
	portal_marker.mesh = portal_mesh
	portal_marker.rotation.z = PI * 0.5
	portal_marker.position = PORTAL_POSITION
	portal_marker.material_override = _make_material(Color("61d2e8"), Color("146c85"))
	add_child(portal_marker)

	portal_area = Area3D.new()
	portal_area.name = "PortalArea"
	portal_area.collision_layer = 0
	portal_area.collision_mask = 1
	var portal_collision := CollisionShape3D.new()
	var portal_shape := BoxShape3D.new()
	portal_shape.size = Vector3(0.8, 3.0, 3.0)
	portal_collision.shape = portal_shape
	portal_area.add_child(portal_collision)
	portal_area.position = PORTAL_POSITION
	portal_area.body_entered.connect(_on_portal_body_entered)
	add_child(portal_area)

	portal_destination_marker = MeshInstance3D.new()
	portal_destination_marker.name = "PortalDestination"
	var destination_mesh := TorusMesh.new()
	destination_mesh.inner_radius = 1.08
	destination_mesh.outer_radius = 1.22
	portal_destination_marker.mesh = destination_mesh
	portal_destination_marker.material_override = _make_material(Color("61d2e8"), Color("146c85"))
	add_child(portal_destination_marker)

	goal_ball = MeshInstance3D.new()
	goal_ball.name = "GoalBall"
	var goal_mesh := SphereMesh.new()
	goal_mesh.radius = 0.34
	goal_mesh.height = 0.68
	goal_ball.mesh = goal_mesh
	goal_ball.material_override = ball_material.duplicate()
	goal_ball.position = Vector3(9.25, 2.26, 0.0)
	add_child(goal_ball)

func _build_attachments() -> void:
	level_chain = Node3D.new()
	level_chain.name = "LevelChain"
	add_child(level_chain)
	_randomize_level()

func _randomize_level() -> void:
	_clear_active_balls()
	_clear_level_chain()
	var kinds: Array[int] = []
	for kind in SECTION_KIND_BAG:
		kinds.append(kind)
	kinds.shuffle()
	max_section_reached = 0
	section_completion_order = []
	var route_direction: Vector3 = TRACK_POINTS[TRACK_POINTS.size() - 1] - TRACK_POINTS[TRACK_POINTS.size() - 2]
	route_direction = Basis(Vector3.UP, deg_to_rad(randf_range(-18.0, 18.0))) * route_direction
	var route_basis: Basis = _make_forward_basis(route_direction)
	var route_anchor := Transform3D(route_basis, CHAIN_ANCHOR)
	var previous: Node3D = null
	for index in range(LEVEL_SECTION_COUNT):
		var piece := _make_attachment("GeneratedAttachment%d" % index, kinds[index])
		piece.add_to_group("attachments")
		level_chain.add_child(piece)
		if previous == null:
			piece.global_transform = route_anchor
		else:
			previous.call("chain_to", piece)
		_add_section_exit(piece, index)
		var collar := piece.get_node_or_null("EntryCollar") as MeshInstance3D
		if collar != null:
			section_collars.append(collar)
		previous = piece
	_update_section_collars(0)
	if previous != null and finish_area != null:
		var finish_port: Marker3D = previous.get_node("Exit")
		finish_area.global_transform = finish_port.global_transform
		_update_finish_marker(finish_port)
		_update_portal_destination_marker(level_chain.get_child(0).get_node("Entry"))
	_build_tower_structure()
	_frame_level_chain()

func _update_portal_destination_marker(entry_port: Marker3D) -> void:
	if portal_destination_marker == null or entry_port == null:
		return
	var entry_transform := entry_port.global_transform
	portal_destination_marker.global_transform = Transform3D(
		entry_transform.basis * Basis(Vector3.BACK, PI * 0.5),
		entry_transform.origin + entry_transform.basis.y * 0.28
	)

func _update_finish_marker(finish_port: Marker3D) -> void:
	if finish_marker == null or finish_label == null:
		return
	var finish_transform := finish_port.global_transform
	var finish_node: Node3D = finish_marker_root if finish_marker_root != null else finish_marker
	finish_node.global_transform = Transform3D(
		finish_transform.basis * Basis(Vector3.UP, PI * 0.5),
		finish_transform.origin + finish_transform.basis.y * 0.45
	)
	finish_label.global_position = finish_transform.origin + finish_transform.basis.y * 2.0

func _clear_active_balls() -> void:
	# ponytail: restart the simulation instead of reconciling stale per-ball route metadata.
	for ball in get_tree().get_nodes_in_group("balls"):
		if is_instance_valid(ball):
			ball.free()

func _clear_level_chain() -> void:
	if level_chain == null:
		return
	if tower_root != null and is_instance_valid(tower_root):
		tower_root.free()
		tower_root = null
	tower_base_bounds = AABB()
	sky_island_bounds = AABB()
	stack_areas = []
	var remaining_flaps: Array[Node3D] = []
	for flap in flaps:
		if is_instance_valid(flap) and not level_chain.is_ancestor_of(flap):
			remaining_flaps.append(flap)
	flaps = remaining_flaps
	var remaining_rollers: Array[Node3D] = []
	for roller in conveyor_rollers:
		if is_instance_valid(roller) and not level_chain.is_ancestor_of(roller):
			remaining_rollers.append(roller)
	conveyor_rollers = remaining_rollers
	var remaining_pucks: Array[Node3D] = []
	for puck in waterfall_pucks:
		if is_instance_valid(puck) and not level_chain.is_ancestor_of(puck):
			remaining_pucks.append(puck)
	waterfall_pucks = remaining_pucks
	booster_markers = []
	section_collars = []
	balance_beams = []
	for child in level_chain.get_children():
		child.free()

func _build_tower_structure() -> void:
	tower_root = Node3D.new()
	tower_root.name = "TowerStructure"
	add_child(tower_root)
	if level_chain == null or level_chain.get_child_count() == 0:
		return

	var route_bounds := AABB()
	var first_piece: Node3D = level_chain.get_child(0)
	var first_entry: Marker3D = first_piece.get_node("Entry")
	route_bounds = AABB(first_entry.global_position, Vector3.ZERO)
	for piece in level_chain.get_children():
		var entry: Marker3D = piece.get_node("Entry")
		var exit: Marker3D = piece.get_node("Exit")
		route_bounds = route_bounds.expand(entry.global_position)
		route_bounds = route_bounds.expand(exit.global_position)
	var base_margin := Vector3(2.6, 0.0, 2.6)
	tower_base_bounds = AABB(
		Vector3(route_bounds.position.x - base_margin.x, TOWER_BASE_Y, route_bounds.position.z - base_margin.z),
		Vector3(route_bounds.size.x + base_margin.x * 2.0, 0.3, route_bounds.size.z + base_margin.z * 2.0)
	)
	if sky_island_root != null:
		var platform_bounds := tower_base_bounds
		for track_point in TRACK_POINTS:
			platform_bounds = platform_bounds.expand(Vector3(track_point.x, TOWER_BASE_Y, track_point.z))
		var platform_margin := Vector3(2.8, 0.0, 2.8)
		platform_bounds.position.x -= platform_margin.x
		platform_bounds.position.z -= platform_margin.z
		platform_bounds.size.x += platform_margin.x * 2.0
		platform_bounds.size.z += platform_margin.z * 2.0
		sky_island_bounds = platform_bounds
		var island_center := platform_bounds.position + platform_bounds.size * 0.5
		sky_island_root.position = Vector3(island_center.x - 8.0, 0.0, island_center.z)
		var platform_diagonal := Vector2(platform_bounds.size.x, platform_bounds.size.z).length()
		var island_diameter := platform_diagonal + 4.0
		var island_scale := Vector3(maxf(1.0, island_diameter / 14.2), 1.0, maxf(1.0, island_diameter / 14.2))
		for surface_name in ["IslandUnderside", "IslandTop"]:
			var island_surface := sky_island_root.get_node_or_null(surface_name) as Node3D
			if island_surface != null:
				island_surface.scale = island_scale
		if island_cloud_root != null:
			island_cloud_root.position = Vector3(8.0, TOWER_BASE_Y - 1.35, 0.0)
			var island_radius := 7.1 * island_scale.x
			for cloud in island_cloud_root.get_children():
				var radial_offset: Vector2 = cloud.get_meta("radial_offset", Vector2.ZERO)
				cloud.position = Vector3(radial_offset.x * island_radius, 0.0, radial_offset.y * island_radius)
	_add_visual_beam(tower_root, tower_base_bounds.position + Vector3(0.0, -0.08, 0.0), Vector3(tower_base_bounds.size.x, 0.34, 0.32), Basis.IDENTITY, support_material)
	_add_visual_beam(tower_root, tower_base_bounds.position + Vector3(0.0, -0.08, tower_base_bounds.size.z), Vector3(tower_base_bounds.size.x, 0.34, 0.32), Basis.IDENTITY, support_material)
	_add_visual_beam(tower_root, tower_base_bounds.position + Vector3(0.0, -0.08, 0.0), Vector3(0.32, 0.34, tower_base_bounds.size.z), Basis.IDENTITY, support_material)
	_add_visual_beam(tower_root, tower_base_bounds.position + Vector3(tower_base_bounds.size.x, -0.08, 0.0), Vector3(0.32, 0.34, tower_base_bounds.size.z), Basis.IDENTITY, support_material)
	var foundation_corners := [
		Vector3(tower_base_bounds.position.x, TOWER_BASE_Y + 0.05, tower_base_bounds.position.z),
		Vector3(tower_base_bounds.position.x + tower_base_bounds.size.x, TOWER_BASE_Y + 0.05, tower_base_bounds.position.z),
		Vector3(tower_base_bounds.position.x, TOWER_BASE_Y + 0.05, tower_base_bounds.position.z + tower_base_bounds.size.z),
		Vector3(tower_base_bounds.position.x + tower_base_bounds.size.x, TOWER_BASE_Y + 0.05, tower_base_bounds.position.z + tower_base_bounds.size.z)
	]
	for corner_index in range(foundation_corners.size()):
		var foundation_foot := _add_visual_beam(tower_root, foundation_corners[corner_index], Vector3(0.78, 0.2, 0.78), Basis.IDENTITY, support_material)
		foundation_foot.name = "FoundationFoot%d" % corner_index
	var foundation_deck := MeshInstance3D.new()
	foundation_deck.name = "TowerFoundationDeck"
	var foundation_deck_mesh := BoxMesh.new()
	foundation_deck_mesh.size = Vector3(tower_base_bounds.size.x, 0.24, tower_base_bounds.size.z)
	foundation_deck.mesh = foundation_deck_mesh
	foundation_deck.position = Vector3(
		tower_base_bounds.position.x + tower_base_bounds.size.x * 0.5,
		TOWER_BASE_Y + 0.06,
		tower_base_bounds.position.z + tower_base_bounds.size.z * 0.5
	)
	foundation_deck.material_override = wood_material
	foundation_deck.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	tower_root.add_child(foundation_deck)

	var support_count := 0
	var previous_leg_tops: Array[Vector3] = []
	for piece_index in range(level_chain.get_child_count()):
		var piece: Node3D = level_chain.get_child(piece_index)
		var entry: Marker3D = piece.get_node("Entry")
		var exit: Marker3D = piece.get_node("Exit")
		var midpoint := (entry.global_position + exit.global_position) * 0.5
		var basis: Basis = piece.global_transform.basis
		var current_leg_tops: Array[Vector3] = []
		for side in [-1.0, 1.0]:
			var leg_top: Vector3 = midpoint + basis.z * side * 1.46 + Vector3.UP * (-0.18)
			current_leg_tops.append(leg_top)
			_add_support_column(leg_top, support_count, true)
			support_count += 1
		if previous_leg_tops.size() == 2:
			for side_index in range(2):
				_add_visual_beam_between(
					tower_root,
					previous_leg_tops[side_index] + Vector3.DOWN * 0.18,
					current_leg_tops[side_index] + Vector3.DOWN * 0.18,
					0.12,
					support_material
				)
		previous_leg_tops = current_leg_tops
		var crossbar_center := midpoint + Vector3.DOWN * 0.34
		_add_visual_beam(tower_root, crossbar_center, Vector3(3.45, 0.22, 0.22), basis, support_material)
		_add_visual_beam_between(
			tower_root,
			midpoint - basis.z * 1.46 + Vector3.DOWN * 0.18,
			midpoint + basis.z * 1.46 + Vector3.DOWN * 0.18,
			0.16,
			support_material
		)
		var lower_anchor := Vector3(midpoint.x, TOWER_BASE_Y + 0.08, midpoint.z)
		for side in [-1.0, 1.0]:
			var top_anchor: Vector3 = midpoint + basis.z * side * 1.46 + Vector3.DOWN * 0.18
			_add_visual_beam_between(tower_root, lower_anchor + basis.z * side * 1.46, top_anchor, 0.14, support_material)
		var kind := int(piece.get_meta("section_kind", -1))
		if kind in [2, 7, 10]:
			_add_curve_ribs(piece, piece_index, kind)

	# A short central mast makes the stacked path read as one structure and gives the island a clear load path.
	var mast_center := Vector3(route_bounds.position.x + route_bounds.size.x * 0.5, (TOWER_BASE_Y + route_bounds.end.y) * 0.5, route_bounds.end.z + 1.65)
	_add_visual_beam(tower_root, mast_center, Vector3(0.42, maxf(route_bounds.end.y - TOWER_BASE_Y, 1.0), 0.42), Basis.IDENTITY, support_material)

func _add_support_column(top: Vector3, index: int, with_footing: bool = false) -> void:
	var bottom := Vector3(top.x, TOWER_BASE_Y + 0.12, top.z)
	var height := maxf(top.y - bottom.y, 0.42)
	_add_visual_beam(tower_root, Vector3(top.x, bottom.y + height * 0.5, top.z), Vector3(0.24, height, 0.24), Basis.IDENTITY, support_material)
	if with_footing:
		var footing := _add_visual_beam(tower_root, bottom + Vector3.UP * 0.02, Vector3(0.62, 0.16, 0.62), Basis.IDENTITY, support_material)
		footing.name = "SupportFoot%d" % index
	var cap := MeshInstance3D.new()
	cap.name = "SupportCap%d" % index
	var cap_mesh := BoxMesh.new()
	cap_mesh.size = Vector3(0.5, 0.12, 0.5)
	cap.mesh = cap_mesh
	cap.position = top
	cap.material_override = wood_material
	tower_root.add_child(cap)

func _add_curve_ribs(piece: Node3D, piece_index: int, kind: int) -> void:
	var rib_count := 4
	for rib_index in range(rib_count):
		var progress := (float(rib_index) + 0.5) / float(rib_count)
		var local_point: Vector3
		var local_tangent: Vector3
		if kind in [2, 7]:
			var radius := float(piece.get_meta("arc_radius", 1.5))
			var vertical_delta := float(piece.get_meta("arc_vertical_delta", 0.0))
			var turn_sign := float(piece.get_meta("turn_sign", 1.0))
			local_point = _arc_point(radius, vertical_delta, progress, turn_sign)
			local_tangent = _arc_point(radius, vertical_delta, minf(progress + 0.02, 1.0), turn_sign) - _arc_point(radius, vertical_delta, maxf(progress - 0.02, 0.0), turn_sign)
		else:
			var serpentine_length := float(piece.get_meta("serpentine_length", 5.2))
			var serpentine_amplitude := float(piece.get_meta("serpentine_amplitude", 1.0))
			local_point = _serpentine_point(progress, serpentine_length, serpentine_amplitude)
			local_tangent = _serpentine_point(minf(progress + 0.02, 1.0), serpentine_length, serpentine_amplitude) - _serpentine_point(maxf(progress - 0.02, 0.0), serpentine_length, serpentine_amplitude)
		var world_basis: Basis = piece.global_transform.basis * _basis_from_tangent(local_tangent)
		var world_point: Vector3 = piece.to_global(local_point) + Vector3.DOWN * 0.38
		_add_visual_beam(tower_root, world_point, Vector3(0.18, 0.18, 2.95), world_basis, support_material)
		for side in [-1.0, 1.0]:
			_add_support_column(world_point + world_basis.z * side * 1.3, piece_index * 10 + rib_index * 2 + int(side + 1.0))

func _add_visual_beam(parent: Node3D, position: Vector3, size: Vector3, basis: Basis, material: Material) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	if wood_beam_mesh != null:
		visual.mesh = wood_beam_mesh
		visual.scale = size
	else:
		var mesh := BoxMesh.new()
		mesh.size = size
		visual.mesh = mesh
	if wood_beam_mesh == null:
		visual.scale = Vector3.ONE
	visual.position = position
	visual.basis = basis
	visual.material_override = material
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(visual)
	return visual

func _add_visual_beam_between(parent: Node3D, start: Vector3, finish: Vector3, thickness: float, material: Material) -> MeshInstance3D:
	var direction := finish - start
	var basis := _basis_from_tangent(direction)
	return _add_visual_beam(parent, (start + finish) * 0.5, Vector3(direction.length(), thickness, thickness), basis, material)

func _make_forward_basis(direction: Vector3) -> Basis:
	return _basis_from_tangent(direction)

func _basis_from_tangent(direction: Vector3) -> Basis:
	var x_axis := direction.normalized()
	if x_axis.length_squared() < 0.001:
		x_axis = Vector3.RIGHT
	var z_axis := x_axis.cross(Vector3.UP)
	if z_axis.length_squared() < 0.001:
		z_axis = Vector3.FORWARD
	z_axis = z_axis.normalized()
	var y_axis := z_axis.cross(x_axis).normalized()
	return Basis(x_axis, y_axis, z_axis)

func _add_section_exit(piece: Node3D, index: int) -> void:
	var area := Area3D.new()
	area.name = "SectionExit%d" % index
	area.collision_layer = 0
	area.collision_mask = 1
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.5, 2.2, 2.6)
	collision.shape = shape
	area.add_child(collision)
	area.transform = piece.get_node("Exit").transform
	area.body_entered.connect(_on_section_exit_body_entered.bind(index))
	piece.add_child(area)

func _on_section_exit_body_entered(body: Node3D, index: int) -> void:
	if not body.is_in_group("balls"):
		return
	var expected_index := int(body.get_meta("expected_section", 0))
	if index != expected_index:
		return
	var current_index := int(body.get_meta("max_section_reached", -1))
	if index <= current_index:
		return
	body.set_meta("max_section_reached", index)
	body.set_meta("expected_section", index + 1)
	max_section_reached = maxi(max_section_reached, index + 1)
	if section_completion_order.size() == index:
		section_completion_order.append(index)
		_show_feedback("SECTION %d" % (index + 1), body.global_position + Vector3.UP * 0.7, Color("9be8f4"))
	_update_section_collars(index + 1)
	var ball := body as RigidBody3D
	if ball == null or level_chain == null or index >= level_chain.get_child_count():
		return
	var exit_port: Marker3D = level_chain.get_child(index).get_node("Exit")
	var handoff_direction := exit_port.global_transform.basis.x.normalized()
	var handoff_speed := clampf(maxf(ball.linear_velocity.dot(handoff_direction), 3.6), 3.6, 9.0)
	ball.linear_velocity = handoff_direction * handoff_speed
	ball.sleeping = false

func _update_section_collars(reached_index: int) -> void:
	for index in range(section_collars.size()):
		var collar := section_collars[index]
		if not is_instance_valid(collar):
			continue
		var material := collar.material_override as StandardMaterial3D
		if material == null:
			continue
		if index < reached_index:
			material.albedo_color = Color("62d58b")
			material.emission = Color("1d6b43")
			material.emission_energy_multiplier = 1.6
		elif index == reached_index:
			material.albedo_color = Color("65e8f2")
			material.emission = Color("146c85")
			material.emission_energy_multiplier = 2.8
		else:
			material.albedo_color = Color("d39a45")
			material.emission = Color("3d1d05")
			material.emission_energy_multiplier = 2.0

func _make_attachment(attachment_name: String, kind: int) -> Node3D:
	var attachment = Attachment.new()
	attachment.name = attachment_name
	attachment.set_meta("section_kind", kind)
	var exit_position: Vector3 = Vector3(2.6, 0.0, 0.0)
	var exit_rotation: Vector3 = Vector3.ZERO
	var turn_sign := -1.0 if randi() % 2 == 0 else 1.0
	attachment.set_meta("turn_sign", turn_sign)
	match kind:
		0:
			_add_attachment_box(attachment, Vector3(1.3, -0.2, 0.0), Vector3(2.6, 0.3, 2.4), Vector3.ZERO, wood_material)
			_add_attachment_box(attachment, Vector3(1.3, 0.35, -1.1), Vector3(2.6, 1.1, 0.2), Vector3.ZERO, wood_material)
			_add_attachment_box(attachment, Vector3(1.3, 0.35, 1.1), Vector3(2.6, 1.1, 0.2), Vector3.ZERO, wood_material)
			_add_conveyor_attachment(attachment)
		1:
			var slope_rotation := Vector3(0.0, 0.0, deg_to_rad(-16.0))
			_add_attachment_box(attachment, Vector3(1.3, -0.36, 0.0), Vector3(2.6, 0.3, 2.4), slope_rotation, wood_material)
			_add_attachment_box(attachment, Vector3(1.3, 0.2, -1.1), Vector3(2.6, 1.0, 0.2), slope_rotation, wood_material)
			_add_attachment_box(attachment, Vector3(1.3, 0.2, 1.1), Vector3(2.6, 1.0, 0.2), slope_rotation, wood_material)
			exit_position = Vector3(2.6, -0.72, 0.0)
			exit_rotation = slope_rotation
		2:
			var arc_radius := randf_range(1.35, 1.75)
			var arc_rise := randf_range(0.8, 1.2)
			attachment.set_meta("arc_radius", arc_radius)
			attachment.set_meta("arc_vertical_delta", arc_rise)
			_add_arc_attachment(attachment, arc_radius, arc_rise, turn_sign)
			exit_position = _arc_point(arc_radius, arc_rise, 1.0, turn_sign)
			exit_rotation = _arc_exit_rotation(arc_radius, arc_rise, turn_sign)
		3:
			_add_attachment_box(attachment, Vector3(1.3, -0.2, 0.0), Vector3(2.6, 0.3, 2.4), Vector3.ZERO, wood_material)
			_add_attachment_box(attachment, Vector3(1.3, 0.35, -1.1), Vector3(2.6, 1.1, 0.2), Vector3.ZERO, wood_material)
			_add_attachment_box(attachment, Vector3(1.3, 0.35, 1.1), Vector3(2.6, 1.1, 0.2), Vector3.ZERO, wood_material)
			_add_attachment_spinner(attachment)
		4:
			_add_gate_attachment(attachment)
		5:
			_add_waterfall_attachment(attachment)
			exit_position = Vector3(2.6, -1.55, 0.0)
			exit_rotation = Vector3.ZERO
		6:
			_add_stack_ramp_attachment(attachment)
			exit_position = Vector3(2.6, 1.0, 0.0)
			exit_rotation = Vector3(0.0, 0.0, deg_to_rad(22.0))
		7:
			var arc_radius := randf_range(1.35, 1.75)
			var arc_drop := -randf_range(0.8, 1.2)
			attachment.set_meta("arc_radius", arc_radius)
			attachment.set_meta("arc_vertical_delta", arc_drop)
			_add_arc_attachment(attachment, arc_radius, arc_drop, turn_sign)
			exit_position = _arc_point(arc_radius, arc_drop, 1.0, turn_sign)
			exit_rotation = _arc_exit_rotation(arc_radius, arc_drop, turn_sign)
		8:
			_add_booster_attachment(attachment)
		9:
			_add_balance_attachment(attachment)
		10:
			var serpentine_length := randf_range(4.8, 5.6)
			var serpentine_amplitude := randf_range(0.85, 1.2)
			attachment.set_meta("serpentine_length", serpentine_length)
			attachment.set_meta("serpentine_amplitude", serpentine_amplitude)
			_add_serpentine_attachment(attachment, serpentine_length, serpentine_amplitude)
			exit_position = _serpentine_point(1.0, serpentine_length, serpentine_amplitude)
			exit_rotation = _serpentine_exit_rotation(serpentine_length, serpentine_amplitude)

	attachment.call("set_exit", exit_position, exit_rotation)
	_add_port_collar(attachment)
	return attachment

func _add_conveyor_attachment(parent: Node3D) -> void:
	var roller_mesh := CylinderMesh.new()
	roller_mesh.top_radius = 0.27
	roller_mesh.bottom_radius = 0.27
	roller_mesh.height = 2.0
	var roller_shape := CylinderShape3D.new()
	roller_shape.radius = 0.27
	roller_shape.height = 2.0
	var roller_material := _make_material(Color("66717c"), Color("1f2b34"))
	var roller_physics := PhysicsMaterial.new()
	roller_physics.bounce = 0.18
	roller_physics.friction = 0.55
	for index in range(5):
		var roller := AnimatableBody3D.new()
		roller.name = "ConveyorRoller%d" % index
		roller.position = Vector3(0.3 + float(index) * 0.5, 0.08, 0.0)
		roller.rotation.x = PI * 0.5
		var roller_visual := MeshInstance3D.new()
		roller_visual.mesh = roller_mesh
		roller_visual.material_override = roller_material
		roller.add_child(roller_visual)
		var roller_collision := CollisionShape3D.new()
		roller_collision.shape = roller_shape
		roller.add_child(roller_collision)
		roller.physics_material_override = roller_physics
		parent.add_child(roller)
		conveyor_rollers.append(roller)
	var conveyor_area := Area3D.new()
	conveyor_area.name = "ConveyorArea"
	conveyor_area.collision_layer = 0
	conveyor_area.collision_mask = 1
	var conveyor_collision := CollisionShape3D.new()
	var conveyor_shape := BoxShape3D.new()
	conveyor_shape.size = Vector3(2.6, 1.2, 2.4)
	conveyor_collision.shape = conveyor_shape
	conveyor_area.position = Vector3(1.3, 0.25, 0.0)
	conveyor_area.add_child(conveyor_collision)
	conveyor_area.body_entered.connect(_on_conveyor_body_entered.bind(parent))
	parent.add_child(conveyor_area)

func _add_arc_attachment(parent: Node3D, radius: float, vertical_drop: float, turn_sign: float) -> void:
	var segment_count := 16
	var cross_count := 6
	for index in range(segment_count):
		var t0: float = float(index) / float(segment_count)
		var t1: float = float(index + 1) / float(segment_count)
		var point0 := _arc_point(radius, vertical_drop, t0, turn_sign)
		var point1 := _arc_point(radius, vertical_drop, t1, turn_sign)
		var tangent: Vector3 = point1 - point0
		var center := (point0 + point1) * 0.5
		var normal := Vector3(-tangent.z, 0.0, tangent.x).normalized()
		for cross_index in range(cross_count):
			var cross0 := lerpf(-1.2, 1.2, float(cross_index) / float(cross_count))
			var cross1 := lerpf(-1.2, 1.2, float(cross_index + 1) / float(cross_count))
			var cross_mid := (cross0 + cross1) * 0.5
			var edge_height := 0.18 * pow(absf(cross_mid) / 1.2, 2.0)
			_add_oriented_attachment_box(
				parent,
				center + normal * cross_mid + Vector3.UP * (edge_height - 0.2),
				Vector3(tangent.length() + 0.18, 0.3, (cross1 - cross0) + 0.05),
				tangent,
				wood_material,
				false
			)
		for side in [-1.0, 1.0]:
			var rail_position: Vector3 = center + normal * side * 1.1 + Vector3.UP * 0.38
			_add_oriented_attachment_box(parent, rail_position, Vector3(tangent.length() + 0.18, 1.0, 0.2), tangent, wood_material, false)
	_add_smooth_arc_visual(parent, radius, vertical_drop, turn_sign)

func _arc_point(radius: float, vertical_drop: float, progress: float, turn_sign: float) -> Vector3:
	var theta: float = -PI * 0.5 + progress * ARC_SWEEP
	return Vector3(radius * cos(theta), vertical_drop * progress, turn_sign * (radius + radius * sin(theta)))

func _arc_exit_rotation(radius: float, vertical_drop: float, turn_sign: float) -> Vector3:
	var tangent := _arc_point(radius, vertical_drop, 1.0, turn_sign) - _arc_point(radius, vertical_drop, 0.875, turn_sign)
	var horizontal_length: float = Vector2(tangent.x, tangent.z).length()
	return Vector3(atan2(tangent.y, maxf(horizontal_length, 0.01)), atan2(tangent.z, tangent.x), 0.0)

func _add_smooth_arc_visual(parent: Node3D, radius: float, vertical_drop: float, turn_sign: float) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segment_count := 64
	var cross_count := 10
	for index in range(segment_count):
		var t0: float = float(index) / float(segment_count)
		var t1: float = float(index + 1) / float(segment_count)
		for cross_index in range(cross_count):
			var u0: float = float(cross_index) / float(cross_count)
			var u1: float = float(cross_index + 1) / float(cross_count)
			_add_mesh_quad(
				surface,
				_arc_surface_point(radius, vertical_drop, t0, lerpf(-1.2, 1.2, u0), turn_sign),
				_arc_surface_point(radius, vertical_drop, t1, lerpf(-1.2, 1.2, u0), turn_sign),
				_arc_surface_point(radius, vertical_drop, t1, lerpf(-1.2, 1.2, u1), turn_sign),
				_arc_surface_point(radius, vertical_drop, t0, lerpf(-1.2, 1.2, u1), turn_sign)
			)
		var left0 := _arc_surface_point(radius, vertical_drop, t0, -1.2, turn_sign)
		var left1 := _arc_surface_point(radius, vertical_drop, t1, -1.2, turn_sign)
		var right0 := _arc_surface_point(radius, vertical_drop, t0, 1.2, turn_sign)
		var right1 := _arc_surface_point(radius, vertical_drop, t1, 1.2, turn_sign)
		_add_mesh_quad(surface, left0, left1, left1 + Vector3.UP * 0.9, left0 + Vector3.UP * 0.9)
		_add_mesh_quad(surface, right0 + Vector3.UP * 0.9, right1 + Vector3.UP * 0.9, right1, right0)
		var thickness := Vector3.UP * 0.28
		_add_mesh_quad(surface, left0 - thickness, left1 - thickness, right1 - thickness, right0 - thickness)
		_add_mesh_quad(surface, left0, left0 - thickness, left1 - thickness, left1)
		_add_mesh_quad(surface, right1, right1 - thickness, right0 - thickness, right0)
	surface.index()
	surface.generate_normals()
	var visual := MeshInstance3D.new()
	visual.name = "SmoothHalfPipe"
	visual.mesh = surface.commit()
	visual.material_override = wood_material
	parent.add_child(visual)

func _arc_surface_point(radius: float, vertical_drop: float, progress: float, cross_offset: float, turn_sign: float) -> Vector3:
	var theta: float = -PI * 0.5 + progress * ARC_SWEEP
	var center := _arc_point(radius, vertical_drop, progress, turn_sign)
	var tangent := Vector3(-sin(theta), 0.0, turn_sign * cos(theta)).normalized()
	var side := Vector3(-tangent.z, 0.0, tangent.x)
	var edge_height: float = 0.18 * pow(absf(cross_offset) / 1.2, 2.0)
	return center + side * cross_offset + Vector3.UP * edge_height

func _add_serpentine_attachment(parent: Node3D, length: float, amplitude: float) -> void:
	var segment_count := 24
	var cross_count := 6
	for index in range(segment_count):
		var t0: float = float(index) / float(segment_count)
		var t1: float = float(index + 1) / float(segment_count)
		var point0 := _serpentine_point(t0, length, amplitude)
		var point1 := _serpentine_point(t1, length, amplitude)
		var tangent: Vector3 = point1 - point0
		var center := (point0 + point1) * 0.5
		var normal := Vector3(-tangent.z, 0.0, tangent.x).normalized()
		for cross_index in range(cross_count):
			var cross0 := lerpf(-1.2, 1.2, float(cross_index) / float(cross_count))
			var cross1 := lerpf(-1.2, 1.2, float(cross_index + 1) / float(cross_count))
			var cross_mid := (cross0 + cross1) * 0.5
			var edge_height := 0.18 * pow(absf(cross_mid) / 1.2, 2.0)
			_add_oriented_attachment_box(
				parent,
				center + normal * cross_mid + Vector3.UP * (edge_height - 0.2),
				Vector3(tangent.length() + 0.18, 0.3, (cross1 - cross0) + 0.05),
				tangent,
				wood_material,
				false
			)
		for side in [-1.0, 1.0]:
			var rail_position: Vector3 = center + normal * side * 1.1 + Vector3.UP * 0.38
			_add_oriented_attachment_box(parent, rail_position, Vector3(tangent.length() + 0.18, 1.0, 0.2), tangent, wood_material, false)
	_add_smooth_serpentine_visual(parent, length, amplitude)

func _serpentine_point(progress: float, length: float, amplitude: float) -> Vector3:
	return Vector3(progress * length, -0.58 * progress, sin(progress * PI * 2.0) * amplitude)

func _serpentine_exit_rotation(length: float, amplitude: float) -> Vector3:
	var tangent := _serpentine_point(1.0, length, amplitude) - _serpentine_point(0.875, length, amplitude)
	var horizontal_length: float = Vector2(tangent.x, tangent.z).length()
	return Vector3(atan2(tangent.y, maxf(horizontal_length, 0.01)), atan2(tangent.z, tangent.x), 0.0)

func _add_smooth_serpentine_visual(parent: Node3D, length: float, amplitude: float) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segment_count := 64
	var cross_count := 10
	for index in range(segment_count):
		var t0: float = float(index) / float(segment_count)
		var t1: float = float(index + 1) / float(segment_count)
		for cross_index in range(cross_count):
			var u0: float = float(cross_index) / float(cross_count)
			var u1: float = float(cross_index + 1) / float(cross_count)
			_add_mesh_quad(
				surface,
				_serpentine_surface_point(t0, lerpf(-1.2, 1.2, u0), length, amplitude),
				_serpentine_surface_point(t1, lerpf(-1.2, 1.2, u0), length, amplitude),
				_serpentine_surface_point(t1, lerpf(-1.2, 1.2, u1), length, amplitude),
				_serpentine_surface_point(t0, lerpf(-1.2, 1.2, u1), length, amplitude)
			)
		var left0 := _serpentine_surface_point(t0, -1.2, length, amplitude)
		var left1 := _serpentine_surface_point(t1, -1.2, length, amplitude)
		var right0 := _serpentine_surface_point(t0, 1.2, length, amplitude)
		var right1 := _serpentine_surface_point(t1, 1.2, length, amplitude)
		_add_mesh_quad(surface, left0, left1, left1 + Vector3.UP * 0.9, left0 + Vector3.UP * 0.9)
		_add_mesh_quad(surface, right0 + Vector3.UP * 0.9, right1 + Vector3.UP * 0.9, right1, right0)
		var thickness := Vector3.UP * 0.28
		_add_mesh_quad(surface, left0 - thickness, left1 - thickness, right1 - thickness, right0 - thickness)
		_add_mesh_quad(surface, left0, left0 - thickness, left1 - thickness, left1)
		_add_mesh_quad(surface, right1, right1 - thickness, right0 - thickness, right0)
	surface.index()
	surface.generate_normals()
	var visual := MeshInstance3D.new()
	visual.name = "SmoothSerpentineHalfPipe"
	visual.mesh = surface.commit()
	visual.material_override = wood_material
	parent.add_child(visual)

func _serpentine_surface_point(progress: float, cross_offset: float, length: float, amplitude: float) -> Vector3:
	var point := _serpentine_point(progress, length, amplitude)
	var sample0 := _serpentine_point(maxf(progress - 0.01, 0.0), length, amplitude)
	var sample1 := _serpentine_point(minf(progress + 0.01, 1.0), length, amplitude)
	var tangent := (sample1 - sample0).normalized()
	var side := Vector3(-tangent.z, 0.0, tangent.x).normalized()
	var edge_height: float = 0.18 * pow(absf(cross_offset) / 1.2, 2.0)
	return point + side * cross_offset + Vector3.UP * edge_height

func _add_waterfall_attachment(parent: Node3D) -> void:
	var puck_material := _make_material(Color("6c9fc3"), Color("275878"))
	var step_count := 4
	for index in range(step_count):
		var center_x: float = 0.35 + float(index) * 0.65
		var center_y: float = -0.2 - float(index) * 0.45
		_add_attachment_box(parent, Vector3(center_x, center_y, 0.0), Vector3(0.8, 0.3, 2.4), Vector3.ZERO, wood_material)
		_add_attachment_box(parent, Vector3(center_x, center_y + 0.17, 0.0), Vector3(0.68, 0.035, 2.05), Vector3.ZERO, water_material)
		_add_attachment_box(parent, Vector3(center_x, center_y + 0.38, -1.1), Vector3(0.8, 1.0, 0.2), Vector3.ZERO, wood_material, false)
		_add_attachment_box(parent, Vector3(center_x, center_y + 0.38, 1.1), Vector3(0.8, 1.0, 0.2), Vector3.ZERO, wood_material, false)
		_add_waterfall_puck(parent, Vector3(center_x, center_y + 0.33, 0.0), puck_material)
	var rail_rotation := Vector3(0.0, 0.0, atan2(-1.35, 1.95))
	_add_attachment_box(parent, Vector3(1.3, -0.5, -1.1), Vector3(2.8, 0.85, 0.2), rail_rotation, wood_material)
	_add_attachment_box(parent, Vector3(1.3, -0.5, 1.1), Vector3(2.8, 0.85, 0.2), rail_rotation, wood_material)
	var waterfall_area := Area3D.new()
	waterfall_area.name = "WaterfallArea"
	waterfall_area.collision_layer = 0
	waterfall_area.collision_mask = 1
	var waterfall_collision := CollisionShape3D.new()
	var waterfall_shape := BoxShape3D.new()
	waterfall_shape.size = Vector3(2.8, 2.4, 2.4)
	waterfall_collision.shape = waterfall_shape
	waterfall_area.position = Vector3(1.3, -0.75, 0.0)
	waterfall_area.add_child(waterfall_collision)
	waterfall_area.body_entered.connect(_on_waterfall_body_entered.bind(parent))
	parent.add_child(waterfall_area)

func _add_gate_attachment(parent: Node3D) -> void:
	_add_attachment_box(parent, Vector3(1.3, -0.2, 0.0), Vector3(2.6, 0.3, 2.4), Vector3.ZERO, wood_material)
	_add_attachment_box(parent, Vector3(1.3, 0.35, -1.1), Vector3(2.6, 1.1, 0.2), Vector3.ZERO, wood_material)
	_add_attachment_box(parent, Vector3(1.3, 0.35, 1.1), Vector3(2.6, 1.1, 0.2), Vector3.ZERO, wood_material)
	_add_attachment_box(parent, Vector3(1.3, 0.5, -0.95), Vector3(0.25, 1.0, 0.2), Vector3.ZERO, wood_material)
	_add_attachment_box(parent, Vector3(1.3, 0.5, 0.95), Vector3(0.25, 1.0, 0.2), Vector3.ZERO, wood_material)
	var gate_material := _make_material(Color("c92d3b"), Color("5c1018"))
	var gate := _add_attachment_box(parent, Vector3(1.3, 0.65, 0.0), Vector3(0.25, 1.4, 1.8), Vector3.ZERO, gate_material)
	gate.name = "Gate"
	gate.set_meta("gate_health", 1)
	var gate_label := Label3D.new()
	gate_label.name = "GateLabel"
	gate_label.text = "DAMAGE 1"
	gate_label.font_size = 36
	gate_label.pixel_size = 0.01
	gate_label.outline_size = 6
	gate_label.no_depth_test = true
	gate_label.modulate = Color("ff8585")
	gate_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	gate_label.position = Vector3(0.0, 1.05, 0.0)
	gate.add_child(gate_label)
	var gate_physics := PhysicsMaterial.new()
	gate_physics.bounce = 0.82
	gate_physics.friction = 0.12
	gate.physics_material_override = gate_physics
	var area := Area3D.new()
	area.name = "GateArea"
	area.collision_layer = 0
	area.collision_mask = 1
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.8, 2.0, 2.2)
	collision.shape = shape
	area.position = Vector3(1.3, 0.65, 0.0)
	area.add_child(collision)
	area.body_entered.connect(_on_gate_body_entered.bind(gate, area))
	parent.add_child(area)

func _add_stack_ramp_attachment(parent: Node3D) -> void:
	var segment_count := 18
	for index in range(segment_count):
		var t0: float = float(index) / float(segment_count)
		var t1: float = float(index + 1) / float(segment_count)
		var point0 := _stack_ramp_surface_point(t0, 0.0)
		var point1 := _stack_ramp_surface_point(t1, 0.0)
		var tangent := point1 - point0
		_add_oriented_attachment_box(parent, (point0 + point1) * 0.5 - Vector3.UP * 0.2, Vector3(tangent.length() + 0.08, 0.3, 2.4), tangent, wood_material, false)
	_add_smooth_stack_ramp_visual(parent)
	var rail_rotation := Vector3(0.0, 0.0, atan2(1.0, 2.6))
	_add_attachment_box(parent, Vector3(1.3, 0.5, -1.1), Vector3(2.8, 0.9, 0.2), rail_rotation, wood_material)
	_add_attachment_box(parent, Vector3(1.3, 0.5, 1.1), Vector3(2.8, 0.9, 0.2), rail_rotation, wood_material)
	var stack_area := Area3D.new()
	stack_area.name = "StackArea"
	stack_area.collision_layer = 0
	stack_area.collision_mask = 1
	var stack_collision := CollisionShape3D.new()
	var stack_shape := BoxShape3D.new()
	stack_shape.size = Vector3(1.8, 1.6, 2.4)
	stack_collision.shape = stack_shape
	stack_area.position = Vector3(0.9, 0.35, 0.0)
	stack_area.add_child(stack_collision)
	parent.add_child(stack_area)
	stack_areas.append(stack_area)

func _add_balance_attachment(parent: Node3D) -> void:
	_add_attachment_box(parent, Vector3(1.3, -0.2, 0.0), Vector3(2.6, 0.3, 2.4), Vector3.ZERO, wood_material)
	_add_attachment_box(parent, Vector3(1.3, 0.35, -1.1), Vector3(2.6, 1.1, 0.2), Vector3.ZERO, wood_material)
	_add_attachment_box(parent, Vector3(1.3, 0.35, 1.1), Vector3(2.6, 1.1, 0.2), Vector3.ZERO, wood_material)
	for side in [-1.0, 1.0]:
		_add_attachment_box(parent, Vector3(1.3, 0.62, side * 0.86), Vector3(0.28, 1.35, 0.42), Vector3.ZERO, wood_material)
	var beam := AnimatableBody3D.new()
	beam.name = "BalanceBeam"
	beam.position = Vector3(1.3, 1.12, 0.0)
	var beam_visual := MeshInstance3D.new()
	var beam_mesh := BoxMesh.new()
	beam_mesh.size = Vector3(0.22, 0.18, 1.95)
	beam_visual.mesh = beam_mesh
	beam_visual.material_override = _make_material(Color("e8b34b"), Color("8b5710"))
	beam.add_child(beam_visual)
	var beam_collision := CollisionShape3D.new()
	var beam_shape := BoxShape3D.new()
	beam_shape.size = beam_mesh.size
	beam_collision.shape = beam_shape
	beam.add_child(beam_collision)
	var beam_physics := PhysicsMaterial.new()
	beam_physics.bounce = 0.38
	beam_physics.friction = 0.2
	beam.physics_material_override = beam_physics
	parent.add_child(beam)
	balance_beams.append(beam)
	var lever := MeshInstance3D.new()
	lever.name = "BalanceLever"
	var lever_mesh := BoxMesh.new()
	lever_mesh.size = Vector3(0.18, 1.0, 0.18)
	lever.mesh = lever_mesh
	lever.position = Vector3(1.3, 0.72, -1.0)
	lever.rotation.z = deg_to_rad(-28.0)
	lever.material_override = _make_material(Color("e8b34b"), Color("8b5710"))
	parent.add_child(lever)
	var lever_body := StaticBody3D.new()
	lever_body.name = "BalanceLeverCollider"
	lever_body.position = lever.position
	lever_body.rotation = lever.rotation
	var lever_collision := CollisionShape3D.new()
	var lever_shape := BoxShape3D.new()
	lever_shape.size = lever_mesh.size
	lever_collision.shape = lever_shape
	lever_body.add_child(lever_collision)
	var lever_physics := PhysicsMaterial.new()
	lever_physics.bounce = 0.32
	lever_physics.friction = 0.2
	lever_body.physics_material_override = lever_physics
	parent.add_child(lever_body)
	var area := Area3D.new()
	area.name = "BalanceArea"
	area.collision_layer = 0
	area.collision_mask = 1
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.8, 1.0, 1.4)
	collision.shape = shape
	area.position = Vector3(1.3, 0.42, 0.0)
	area.add_child(collision)
	area.body_entered.connect(_on_balance_body_entered.bind(parent))
	parent.add_child(area)

func _add_smooth_stack_ramp_visual(parent: Node3D) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segment_count := 20
	var cross_count := 8
	for index in range(segment_count):
		var t0: float = float(index) / float(segment_count)
		var t1: float = float(index + 1) / float(segment_count)
		for cross_index in range(cross_count):
			var u0: float = float(cross_index) / float(cross_count)
			var u1: float = float(cross_index + 1) / float(cross_count)
			_add_mesh_quad(
				surface,
				_stack_ramp_surface_point(t0, lerpf(-1.2, 1.2, u0)),
				_stack_ramp_surface_point(t1, lerpf(-1.2, 1.2, u0)),
				_stack_ramp_surface_point(t1, lerpf(-1.2, 1.2, u1)),
				_stack_ramp_surface_point(t0, lerpf(-1.2, 1.2, u1))
			)
		var left0 := _stack_ramp_surface_point(t0, -1.2)
		var left1 := _stack_ramp_surface_point(t1, -1.2)
		var right0 := _stack_ramp_surface_point(t0, 1.2)
		var right1 := _stack_ramp_surface_point(t1, 1.2)
		var thickness := Vector3.UP * 0.35
		_add_mesh_quad(surface, left0 - thickness, left1 - thickness, right1 - thickness, right0 - thickness)
		_add_mesh_quad(surface, left0, left0 - thickness, left1 - thickness, left1)
		_add_mesh_quad(surface, right1, right1 - thickness, right0 - thickness, right0)
	surface.index()
	surface.generate_normals()
	var visual := MeshInstance3D.new()
	visual.name = "SmoothStackRamp"
	visual.mesh = surface.commit()
	visual.material_override = wood_material
	parent.add_child(visual)

func _stack_ramp_surface_point(progress: float, cross_offset: float) -> Vector3:
	var edge_height: float = 0.16 * pow(absf(cross_offset) / 1.2, 2.0)
	return Vector3(progress * 2.6, lerpf(0.0, 1.0, progress), cross_offset) + Vector3.UP * edge_height

func _add_booster_attachment(parent: Node3D) -> void:
	_add_attachment_box(parent, Vector3(1.3, -0.2, 0.0), Vector3(2.6, 0.3, 2.4), Vector3.ZERO, wood_material)
	_add_attachment_box(parent, Vector3(1.3, 0.35, -1.1), Vector3(2.6, 1.1, 0.2), Vector3.ZERO, wood_material)
	_add_attachment_box(parent, Vector3(1.3, 0.35, 1.1), Vector3(2.6, 1.1, 0.2), Vector3.ZERO, wood_material)
	var booster_material := _make_material(Color("48d7e8"), Color("1b768c"))
	_add_attachment_box(parent, Vector3(0.95, 0.02, -0.45), Vector3(0.75, 0.08, 0.35), Vector3.ZERO, booster_material)
	_add_attachment_box(parent, Vector3(1.65, 0.02, 0.45), Vector3(0.75, 0.08, 0.35), Vector3.ZERO, booster_material)
	for index in range(3):
		var chevron_root := Node3D.new()
		chevron_root.name = "BoosterChevron%d" % index
		chevron_root.position = Vector3(0.58 + float(index) * 0.7, 0.12, 0.0)
		var chevron_a := MeshInstance3D.new()
		var chevron_mesh_a := BoxMesh.new()
		chevron_mesh_a.size = Vector3(0.42, 0.07, 0.12)
		chevron_a.mesh = chevron_mesh_a
		chevron_a.rotation.y = deg_to_rad(34.0)
		chevron_a.material_override = booster_material
		chevron_root.add_child(chevron_a)
		var chevron_b := MeshInstance3D.new()
		var chevron_mesh_b := BoxMesh.new()
		chevron_mesh_b.size = Vector3(0.42, 0.07, 0.12)
		chevron_b.mesh = chevron_mesh_b
		chevron_b.rotation.y = deg_to_rad(-34.0)
		chevron_b.material_override = booster_material
		chevron_root.add_child(chevron_b)
		parent.add_child(chevron_root)
		booster_markers.append(chevron_root)
	var area := Area3D.new()
	area.name = "BoosterArea"
	area.collision_layer = 0
	area.collision_mask = 1
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.6, 1.4, 2.4)
	collision.shape = shape
	area.add_child(collision)
	area.position = Vector3(1.3, 0.35, 0.0)
	area.body_entered.connect(_on_booster_body_entered.bind(parent))
	parent.add_child(area)

func _on_booster_body_entered(body: Node3D, attachment: Node3D) -> void:
	if not body.is_in_group("balls") or body.get_meta("boosted_by", -1) == attachment.get_instance_id():
		return
	body.set_meta("boosted_by", attachment.get_instance_id())
	boost_count += 1
	_show_feedback("BOOST", body.global_position + Vector3.UP * 0.6, Color("65e8f2"))
	var ball := body as RigidBody3D
	if ball == null:
		return
	var launch_direction: Vector3 = attachment.global_transform.basis.x + Vector3.UP * 0.28
	ball.linear_velocity = launch_direction.normalized() * 8.5

func _on_conveyor_body_entered(body: Node3D, attachment: Node3D) -> void:
	if not body.is_in_group("balls") or body.get_meta("conveyor_hit_by", -1) == attachment.get_instance_id():
		return
	var ball := body as RigidBody3D
	if ball == null:
		return
	var forward := attachment.global_transform.basis.x.normalized()
	var forward_speed := maxf(ball.linear_velocity.dot(forward), 3.5)
	ball.linear_velocity = forward * forward_speed + Vector3.UP * 0.08
	ball.sleeping = false
	body.set_meta("conveyor_hit_by", attachment.get_instance_id())
	conveyor_hit_count += 1
	_show_feedback("ROLL", ball.global_position + Vector3.UP * 0.6, Color("d3e7f4"))
	get_tree().create_timer(0.5).timeout.connect(func() -> void:
		if is_instance_valid(ball):
			ball.set_meta("conveyor_hit_by", -1)
	)

func _on_flap_body_entered(body: Node3D) -> void:
	if not body.is_in_group("balls") or body.get_meta("flap_hit", false):
		return
	var ball := body as RigidBody3D
	if ball == null:
		return
	body.set_meta("flap_hit", true)
	flap_hit_count += 1
	var push_sign := -1.0 if ball.global_position.z >= 0.0 else 1.0
	ball.linear_velocity.z = push_sign * maxf(absf(ball.linear_velocity.z), 1.2)
	_show_feedback("SWING", ball.global_position + Vector3.UP * 0.6, Color("65e8f2"))
	get_tree().create_timer(0.65).timeout.connect(func() -> void:
		if is_instance_valid(ball):
			ball.set_meta("flap_hit", false)
	)

func _on_spinner_body_entered(body: Node3D, spinner: Node3D) -> void:
	if not body.is_in_group("balls") or body.get_meta("spinner_hit_by", -1) == spinner.get_instance_id():
		return
	var ball := body as RigidBody3D
	if ball == null:
		return
	var local_position: Vector3 = spinner.global_transform.affine_inverse() * ball.global_position
	var push_sign := -1.0 if local_position.z >= 0.0 else 1.0
	var forward := spinner.global_transform.basis.x.normalized()
	var lateral := spinner.global_transform.basis.z.normalized()
	var forward_speed := maxf(ball.linear_velocity.dot(forward), 2.5)
	ball.linear_velocity = forward * forward_speed + lateral * (push_sign * 1.8) + Vector3.UP * 0.12
	ball.sleeping = false
	body.set_meta("spinner_hit_by", spinner.get_instance_id())
	spinner_hit_count += 1
	_show_feedback("SWING", ball.global_position + Vector3.UP * 0.6, Color("65e8f2"))
	get_tree().create_timer(0.55).timeout.connect(func() -> void:
		if is_instance_valid(ball):
			ball.set_meta("spinner_hit_by", -1)
	)

func _on_gate_body_entered(body: Node3D, gate: StaticBody3D, area: Area3D) -> void:
	if not body.is_in_group("balls") or gate.get_meta("gate_open", false) or body.get_meta("gate_hit_by", -1) == gate.get_instance_id():
		return
	var ball := body as RigidBody3D
	if ball == null:
		return
	body.set_meta("gate_hit_by", gate.get_instance_id())
	gate_hit_count += 1
	var remaining_health := maxi(0, int(gate.get_meta("gate_health", 1)) - int(maxf(1.0, float(ball.get("damage")))))
	gate.set_meta("gate_health", remaining_health)
	var normal := gate.global_transform.basis.x.normalized()
	get_tree().create_timer(0.45).timeout.connect(func() -> void:
		if is_instance_valid(ball):
			ball.set_meta("gate_hit_by", -1)
	)
	if remaining_health == 0:
		gate.set_meta("gate_open", true)
		var gate_label := gate.get_node_or_null("GateLabel") as Label3D
		if gate_label != null:
			gate_label.text = "OPEN"
			gate_label.modulate = Color("9dff9d")
		area.set_deferred("monitoring", false)
		gate.collision_layer = 0
		gate.collision_mask = 0
		var tween := create_tween()
		tween.tween_property(gate, "position", gate.position + Vector3.UP * 2.2, 0.45)
		ball.linear_velocity = normal * maxf(absf(ball.linear_velocity.dot(normal)), 4.2) + Vector3.UP * 0.12
		ball.sleeping = false
		_show_feedback("OPEN", ball.global_position + Vector3.UP * 0.6, Color("9dff9d"))
	else:
		ball.linear_velocity -= normal * (2.0 * ball.linear_velocity.dot(normal))
		ball.sleeping = false
		_show_feedback("-1", ball.global_position + Vector3.UP * 0.6, Color("ff8585"))
		get_tree().create_timer(0.22).timeout.connect(func() -> void:
			if is_instance_valid(ball):
				ball.call("fade_out")
		)

func _on_balance_body_entered(body: Node3D, attachment: Node3D) -> void:
	if not body.is_in_group("balls") or body.get_meta("balance_hit_by", -1) == attachment.get_instance_id():
		return
	var ball := body as RigidBody3D
	if ball == null:
		return
	var local_position: Vector3 = attachment.global_transform.affine_inverse() * ball.global_position
	var push_sign := -1.0 if local_position.z >= 0.0 else 1.0
	ball.linear_velocity += attachment.global_transform.basis.z.normalized() * (push_sign * 0.8)
	ball.sleeping = false
	body.set_meta("balance_hit_by", attachment.get_instance_id())
	balance_hit_count += 1
	_show_feedback("BALANCE", ball.global_position + Vector3.UP * 0.6, Color("ffd363"))
	get_tree().create_timer(0.55).timeout.connect(func() -> void:
		if is_instance_valid(ball):
			ball.set_meta("balance_hit_by", -1)
	)

func _on_waterfall_body_entered(body: Node3D, attachment: Node3D) -> void:
	if not body.is_in_group("balls") or body.get_meta("waterfall_hit_by", -1) == attachment.get_instance_id():
		return
	var ball := body as RigidBody3D
	if ball == null:
		return
	var forward := attachment.global_transform.basis.x.normalized()
	var forward_speed := maxf(ball.linear_velocity.dot(forward), 2.2)
	ball.linear_velocity = forward * forward_speed + Vector3.UP * 1.1
	ball.sleeping = false
	body.set_meta("waterfall_hit_by", attachment.get_instance_id())
	waterfall_hit_count += 1
	_show_feedback("SPLASH", ball.global_position + Vector3.UP * 0.6, Color("65e8f2"))
	get_tree().create_timer(0.5).timeout.connect(func() -> void:
		if is_instance_valid(ball):
			ball.set_meta("waterfall_hit_by", -1)
	)

func _on_portal_body_entered(body: Node3D) -> void:
	if not body.is_in_group("balls") or body.get_meta("portal_used", false) or body.get_meta("portal_cooldown", false):
		return
	var ball := body as RigidBody3D
	if ball == null or level_chain == null or level_chain.get_child_count() == 0:
		return
	var first_section: Node3D = level_chain.get_child(0)
	var entry: Marker3D = first_section.get_node("Entry")
	var exit: Marker3D = first_section.get_node("Exit")
	ball.global_position = entry.global_position + entry.global_transform.basis.y * 0.65
	ball.linear_velocity = entry.global_transform.basis.x.normalized() * maxf(ball.linear_velocity.length(), 5.0)
	ball.angular_velocity = Vector3.ZERO
	ball.sleeping = false
	ball.set_meta("portal_used", true)
	ball.set_meta("portal_cooldown", true)
	ball.set_meta("max_section_reached", -1)
	ball.set_meta("expected_section", 0)
	portal_count += 1
	_show_feedback("PORTAL", ball.global_position + Vector3.UP * 0.7, Color("65e8f2"))
	get_tree().create_timer(0.45).timeout.connect(func() -> void:
		if is_instance_valid(ball):
			ball.set_meta("portal_cooldown", false)
	)

func _add_attachment_box(parent: Node3D, position: Vector3, size: Vector3, rotation: Vector3, material: Material, visible: bool = true) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = position
	body.rotation = rotation
	parent.add_child(body)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)

	var visual := MeshInstance3D.new()
	if visible and material == wood_material and wood_beam_mesh != null:
		visual.mesh = wood_beam_mesh
		visual.scale = size
	else:
		var mesh := BoxMesh.new()
		mesh.size = size
		visual.mesh = mesh
	visual.visible = visible
	visual.material_override = material
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if visible else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(visual)
	return body

func _add_oriented_attachment_box(parent: Node3D, position: Vector3, size: Vector3, tangent: Vector3, material: Material, visible: bool = true) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = position
	body.basis = _basis_from_tangent(tangent)
	parent.add_child(body)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)

	var visual := MeshInstance3D.new()
	if visible and material == wood_material and wood_beam_mesh != null:
		visual.mesh = wood_beam_mesh
		visual.scale = size
	else:
		var mesh := BoxMesh.new()
		mesh.size = size
		visual.mesh = mesh
	visual.visible = visible
	visual.material_override = material
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if visible else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(visual)
	return body

func _add_waterfall_puck(parent: Node3D, position: Vector3, material: Material) -> void:
	var body := AnimatableBody3D.new()
	body.name = "WaterfallPuck%d" % waterfall_pucks.size()
	body.position = position
	body.set_meta("base_position", position)
	body.set_meta("phase", float(waterfall_pucks.size()) * 0.8)
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.34
	shape.height = 0.22
	collision.shape = shape
	body.add_child(collision)
	var visual := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.34
	mesh.bottom_radius = 0.34
	mesh.height = 0.22
	visual.mesh = mesh
	visual.material_override = material
	body.add_child(visual)
	var stripe := MeshInstance3D.new()
	var stripe_mesh := BoxMesh.new()
	stripe_mesh.size = Vector3(0.08, 0.035, 0.5)
	stripe.mesh = stripe_mesh
	stripe.position = Vector3(0.0, 0.13, 0.0)
	stripe.material_override = _make_material(Color("d9f6ff"), Color("8cd7ec"))
	body.add_child(stripe)
	var physics := PhysicsMaterial.new()
	physics.bounce = 0.85
	physics.friction = 0.2
	body.physics_material_override = physics
	parent.add_child(body)
	waterfall_pucks.append(body)

func _add_attachment_cylinder(parent: Node3D, position: Vector3, radius: float, height: float, material: Material, bounce: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = position
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	collision.shape = shape
	body.add_child(collision)
	var visual := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	visual.mesh = mesh
	visual.material_override = material
	body.add_child(visual)
	var physics := PhysicsMaterial.new()
	physics.bounce = bounce
	physics.friction = 0.2
	body.physics_material_override = physics
	parent.add_child(body)
	return body

func _add_port_collar(parent: Node3D) -> void:
	var collar := MeshInstance3D.new()
	collar.name = "EntryCollar"
	collar.mesh = port_mesh
	collar.material_override = port_material.duplicate()
	# The torus default axis is Y; rotate it so its opening follows the module's +X path.
	collar.rotation.z = PI * 0.5
	collar.position = Vector3(0.0, 0.28, 0.0)
	collar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(collar)

func _add_attachment_spinner(parent: Node3D) -> void:
	var spinner := AnimatableBody3D.new()
	spinner.name = "Spinner"
	spinner.position = Vector3(1.3, 0.34, 0.0)
	parent.add_child(spinner)
	for offset in [-0.72, 0.72]:
		var visual := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.22, 0.24, 1.55)
		visual.mesh = mesh
		visual.position = Vector3(0.0, 0.0, offset)
		visual.material_override = _make_material(Color("61d2e8"), Color("146c85"))
		spinner.add_child(visual)

		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = mesh.size
		collision.shape = shape
		collision.position = visual.position
		spinner.add_child(collision)
	var spinner_area := Area3D.new()
	spinner_area.name = "SpinnerArea"
	spinner_area.collision_layer = 0
	spinner_area.collision_mask = 1
	var area_collision := CollisionShape3D.new()
	var area_shape := BoxShape3D.new()
	area_shape.size = Vector3(0.8, 1.8, 3.2)
	area_collision.shape = area_shape
	spinner_area.add_child(area_collision)
	spinner_area.body_entered.connect(_on_spinner_body_entered.bind(spinner))
	spinner.add_child(spinner_area)
	flaps.append(spinner)

func _build_camera() -> void:
	camera = Camera3D.new()
	camera.fov = 50.0
	add_child(camera)
	camera.current = true
	_frame_level_chain()
	_update_camera(1.0)

func _frame_level_chain() -> void:
	if camera == null or level_chain == null or level_chain.get_child_count() == 0:
		return
	var bounds := AABB(TRACK_POINTS[0], Vector3.ZERO)
	for point in TRACK_POINTS:
		bounds = bounds.expand(point)
	for piece in level_chain.get_children():
		bounds = bounds.expand(piece.get_node("Entry").global_position)
		bounds = bounds.expand(piece.get_node("Exit").global_position)
	if finish_marker_root != null:
		bounds = bounds.expand(finish_marker_root.global_position)
	if tower_base_bounds.size != Vector3.ZERO:
		bounds = bounds.expand(tower_base_bounds.position)
		bounds = bounds.expand(tower_base_bounds.end + Vector3.UP * 1.2)
	if sky_island_bounds.size != Vector3.ZERO:
		bounds = bounds.expand(sky_island_bounds.position - Vector3(1.0, 1.3, 1.0))
		bounds = bounds.expand(sky_island_bounds.end + Vector3(1.0, 0.4, 1.0))
	var geometry_margin := Vector3.ONE * 2.0
	bounds.position -= geometry_margin
	bounds.size += geometry_margin * 2.0
	var center := bounds.position + bounds.size * 0.5
	camera_focus = center + Vector3.UP * 0.4
	var span := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	camera_distance = clamp(span * 1.42 + 8.0, 30.0, 46.0)

func _update_camera(delta: float) -> void:
	if camera == null:
		return
	var horizontal_distance := cos(camera_pitch) * camera_distance
	var offset := Vector3(
		sin(camera_yaw) * horizontal_distance,
		sin(camera_pitch) * camera_distance,
		cos(camera_yaw) * horizontal_distance
	)
	var desired_position := camera_focus + offset
	camera.global_position = camera.global_position.lerp(desired_position, 1.0 - exp(-8.0 * delta))
	camera.look_at(camera_focus, Vector3.UP)

func _reset_camera() -> void:
	camera_yaw = deg_to_rad(38.0)
	camera_pitch = deg_to_rad(30.0)
	_frame_level_chain()

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	ui_layer = layer
	add_child(layer)

	var panel := PanelContainer.new()
	panel.position = Vector2(22.0, 22.0)
	panel.custom_minimum_size = Vector2(238.0, 0.0)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.035, 0.05, 0.08, 0.88)
	panel_style.border_color = Color("29405b")
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(12)
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.34)
	panel_style.shadow_size = 10
	panel_style.shadow_offset = Vector2(0.0, 4.0)
	panel.add_theme_stylebox_override("panel", panel_style)
	layer.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.add_theme_constant_override("margin_left", 12)
	box.add_theme_constant_override("margin_top", 10)
	box.add_theme_constant_override("margin_right", 12)
	box.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(box)

	credits_label = Label.new()
	credits_label.add_theme_font_size_override("font_size", 18)
	credits_label.add_theme_color_override("font_color", Color("f4f7fb"))
	box.add_child(credits_label)

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.add_theme_color_override("font_color", Color("f4f7fb"))
	box.add_child(status_label)

	section_status_label = Label.new()
	section_status_label.add_theme_font_size_override("font_size", 14)
	section_status_label.add_theme_color_override("font_color", Color("9be8f4"))
	box.add_child(section_status_label)

	stop_progress = ProgressBar.new()
	stop_progress.max_value = stop_max_health
	stop_progress.show_percentage = false
	stop_progress.custom_minimum_size = Vector2(0.0, 12.0)
	var progress_background := StyleBoxFlat.new()
	progress_background.bg_color = Color("0b101a")
	progress_background.border_color = Color("05070b")
	progress_background.set_border_width_all(2)
	progress_background.set_corner_radius_all(4)
	stop_progress.add_theme_stylebox_override("background", progress_background)
	stop_progress_fill = StyleBoxFlat.new()
	stop_progress_fill.bg_color = Color("c92d3b")
	stop_progress_fill.border_color = Color("05070b")
	stop_progress_fill.set_border_width_all(2)
	stop_progress_fill.set_corner_radius_all(4)
	stop_progress.add_theme_stylebox_override("fill", stop_progress_fill)
	box.add_child(stop_progress)

	var first_session_prompt := Label.new()
	first_session_prompt.name = "FirstSessionPrompt"
	first_session_prompt.text = "Space drops a ball.\nBall impacts open the STOP gate."
	first_session_prompt.add_theme_font_size_override("font_size", 14)
	first_session_prompt.add_theme_color_override("font_color", Color("f4f7fb"))
	box.add_child(first_session_prompt)

	var drop_button := Button.new()
	drop_button.name = "DropBallButton"
	drop_button.text = "Drop ball  [Space]"
	drop_button.pressed.connect(_spawn_ball)
	_style_button(drop_button)
	box.add_child(drop_button)

	ui_options_button = Button.new()
	ui_options_button.name = "OptionsButton"
	ui_options_button.text = "Options"
	ui_options_button.pressed.connect(_toggle_ui_options)
	_style_button(ui_options_button)
	box.add_child(ui_options_button)

	ui_options = VBoxContainer.new()
	ui_options.name = "Options"
	ui_options.visible = false
	ui_options.add_theme_constant_override("separation", 5)
	box.add_child(ui_options)

	stop_button = Button.new()
	stop_button.text = "Spawn rate  [1]"
	stop_button.pressed.connect(_buy_spawn_upgrade)
	_style_button(stop_button)
	ui_options.add_child(stop_button)

	value_button = Button.new()
	value_button.text = "Ball value  [2]"
	value_button.pressed.connect(_buy_value_upgrade)
	_style_button(value_button)
	ui_options.add_child(value_button)

	damage_button = Button.new()
	damage_button.name = "DamageButton"
	damage_button.text = "Ball damage  [3]"
	damage_button.pressed.connect(_buy_damage_upgrade)
	_style_button(damage_button)
	ui_options.add_child(damage_button)

	auto_button = Button.new()
	auto_button.text = "Auto spawn: ON  [T]"
	auto_button.pressed.connect(_toggle_auto_spawn)
	_style_button(auto_button)
	ui_options.add_child(auto_button)

	randomize_button = Button.new()
	randomize_button.name = "RandomizeButton"
	randomize_button.text = "Randomize level  [G]"
	randomize_button.pressed.connect(_randomize_level)
	_style_button(randomize_button)
	ui_options.add_child(randomize_button)

func _toggle_ui_options() -> void:
	if ui_options == null or ui_options_button == null:
		return
	ui_options.visible = not ui_options.visible
	ui_options_button.text = "Hide options" if ui_options.visible else "Options"

func _style_button(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("182235")
	normal.border_color = Color("05070b")
	normal.border_width_left = 3
	normal.border_width_top = 3
	normal.border_width_right = 3
	normal.border_width_bottom = 3
	normal.corner_radius_top_left = 6
	normal.corner_radius_top_right = 6
	normal.corner_radius_bottom_left = 6
	normal.corner_radius_bottom_right = 6
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("26405e")
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("0f1725")
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", Color("f4f7fb"))
	button.add_theme_color_override("font_hover_color", Color("ffffff"))

func _update_ui() -> void:
	if credits_label == null:
		return
	credits_label.text = "Credits: %d\nBall value: %d\nBall damage: %.0f\nSpawn interval: %.2fs" % [credits, ball_value, ball_damage, spawn_interval]
	status_label.text = "Stop: OPEN" if stop_open else "Stop health: %d / %d" % [stop_health, stop_max_health]
	section_status_label.text = "Path sections: %d / %d" % [max_section_reached, LEVEL_SECTION_COUNT]
	stop_progress.value = stop_max_health if stop_open else stop_health
	if stop_progress_fill != null:
		stop_progress_fill.bg_color = Color("62d58b") if stop_open else Color("c92d3b")
	stop_button.text = "Spawn rate  [1]  %d" % spawn_upgrade_cost
	value_button.text = "Ball value  [2]  %d" % value_upgrade_cost
	damage_button.text = "Ball damage  [3]  %d" % damage_upgrade_cost
	auto_button.text = "Auto spawn: %s  [T]" % ("ON" if auto_spawn else "OFF")
	if stop_label != null:
		stop_label.text = "OPEN" if stop_open else "DAMAGE %d" % stop_health

func _spawn_ball() -> void:
	if get_tree().get_nodes_in_group("balls").size() >= MAX_ACTIVE_BALLS:
		return
	# ponytail: hard cap bounds rigid-body cost; use pooling only if profiling shows 300 is insufficient.
	var ball = Ball.new()
	ball.name = "Ball"
	ball.position = Vector3(-9.2 + randf_range(-0.35, 0.35), 9.0, randf_range(-0.35, 0.35))
	ball.mass = 0.8
	ball.linear_damp = 0.08
	ball.angular_damp = 0.08
	ball.continuous_cd = true
	ball.physics_material_override = ball_physics
	ball.value = ball_value
	ball.damage = ball_damage
	ball.set_meta("max_section_reached", -1)
	ball.set_meta("expected_section", 0)
	ball.add_to_group("balls")

	var collision := CollisionShape3D.new()
	collision.shape = ball_shape
	ball.add_child(collision)

	var visual := MeshInstance3D.new()
	visual.mesh = ball_mesh
	visual.material_override = ball_material
	# ponytail: limit expensive per-ball shadows at high population; keep every ball visible.
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if get_tree().get_nodes_in_group("balls").size() <= MAX_BALL_SHADOWS else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ball.add_child(visual)
	ball.visual = visual
	ball_root.add_child(ball)

func _cleanup_balls() -> void:
	for ball in get_tree().get_nodes_in_group("balls"):
		if not is_instance_valid(ball):
			continue
		var position: Vector3 = ball.global_position
		if position.y < -10.0 or absf(position.x) > 90.0 or absf(position.z) > 60.0:
			ball.queue_free()

func _ball_color() -> Color:
	return Color("c92d3b")

func _on_stop_body_entered(body: Node3D) -> void:
	if stop_open or not body.is_in_group("balls") or body.get_meta("stop_hit", false):
		return
	body.set_meta("stop_hit", true)
	var ball := body as RigidBody3D
	if ball == null:
		return
	stop_health = maxi(0, stop_health - int(maxf(1.0, float(ball.get("damage")))))
	_show_feedback("-1", ball.global_position + Vector3.UP * 0.6, Color("ff8585"))

	if stop_health == 0:
		_open_stop()
		ball.linear_velocity = Vector3.RIGHT * maxf(absf(ball.linear_velocity.x), 4.0) + Vector3.UP * 0.12
		ball.sleeping = false
	else:
		var fade_timer := get_tree().create_timer(0.28)
		fade_timer.timeout.connect(func() -> void:
			if is_instance_valid(ball):
				faded_ball_count += 1
				ball.call("fade_out")
		)

func _open_stop() -> void:
	stop_open = true
	stop_area.monitoring = false
	_show_feedback("OPEN", stop_panel.global_position + Vector3.UP * 1.2, Color("9dff9d"))
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(stop_panel, "position", stop_panel.position + Vector3(0.0, 4.0, 0.0), 0.8)
	tween.tween_property(stop_wall, "position", stop_wall.position + Vector3(0.0, 4.0, 0.0), 0.8)
	if stop_label != null:
		tween.tween_property(stop_label, "position", stop_label.position + Vector3(0.0, 4.0, 0.0), 0.8)

func _on_payment_body_entered(body: Node3D) -> void:
	if not body.is_in_group("balls"):
		return
	var ball := body as RigidBody3D
	if ball == null or ball.paid:
		return
	ball.paid = true
	credits += ball.value
	_show_feedback("+$%d" % ball.value, ball.global_position + Vector3.UP * 0.6, Color("ffd363"))

func _show_feedback(text: String, position: Vector3, color: Color) -> void:
	if feedback_label == null:
		return
	if feedback_tween != null:
		feedback_tween.kill()
	feedback_label.text = text
	feedback_label.position = position
	feedback_label.scale = Vector3.ONE
	var visible_color := color
	visible_color.a = 1.0
	feedback_label.modulate = visible_color
	feedback_label.visible = true
	feedback_tween = create_tween()
	feedback_tween.set_parallel(true)
	feedback_tween.tween_property(feedback_label, "position", position + Vector3.UP * 0.9, 0.8)
	var faded_color := color
	faded_color.a = 0.0
	feedback_tween.tween_property(feedback_label, "modulate", faded_color, 0.8)
	feedback_tween.tween_property(feedback_label, "scale", Vector3.ONE * 1.15, 0.28)
	feedback_tween.chain().tween_callback(func() -> void:
		feedback_label.visible = false
	)

func _on_finish_body_entered(body: Node3D) -> void:
	if body.is_in_group("balls"):
		finished_ball_count += 1
		_show_feedback("DONE", body.global_position + Vector3.UP * 0.7, Color("9dff9d"))
		body.queue_free()

func _buy_spawn_upgrade() -> void:
	if credits < spawn_upgrade_cost:
		return
	credits -= spawn_upgrade_cost
	spawn_upgrade_level += 1
	spawn_interval = maxf(0.25, spawn_interval - 0.15)
	spawn_upgrade_cost = 20 + spawn_upgrade_level * 15

func _buy_value_upgrade() -> void:
	if credits < value_upgrade_cost:
		return
	credits -= value_upgrade_cost
	value_upgrade_level += 1
	ball_value += 1
	value_upgrade_cost = 35 + value_upgrade_level * 25

func _buy_damage_upgrade() -> void:
	if credits < damage_upgrade_cost:
		return
	credits -= damage_upgrade_cost
	damage_upgrade_level += 1
	ball_damage += 1.0
	damage_upgrade_cost = 50 + damage_upgrade_level * 35

func _toggle_auto_spawn() -> void:
	auto_spawn = not auto_spawn

func _make_area(position: Vector3, size: Vector3) -> Area3D:
	var area := Area3D.new()
	area.position = position
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	area.add_child(shape)
	add_child(area)
	return area

func _make_material(color: Color, emission: Color = Color(0.0, 0.0, 0.0, 1.0)) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.7
	if emission != Color(0.0, 0.0, 0.0, 1.0):
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = 2.0
	return material
