class_name CascadeWorldBuilder
extends Node3D

@export var world_seed: int = 4041994
@export var spawn_player: bool = true

var blueprint: WorldBlueprint
var sampler: TerrainSampler
var floating_origin: FloatingOrigin
var chunk_streamer: ChunkStreamer
var player: ThirdPersonPlayer
var last_preload_stats: Dictionary = {}
var _tracked_nodes: Array = []
var _anim_elapsed: float = 0.0


func _ready() -> void:
	build_world()


func build_world() -> Dictionary:
	_clear_children()

	blueprint = WorldBlueprint.new(world_seed)
	sampler = TerrainSampler.new(blueprint)

	_build_atmosphere_and_lighting()

	floating_origin = FloatingOrigin.new()
	floating_origin.name = "FloatingOrigin"
	add_child(floating_origin)

	chunk_streamer = ChunkStreamer.new()
	chunk_streamer.name = "ChunkStreamer"
	add_child(chunk_streamer)

	# Spawn near the Cold Open Crash Site on its roadside clearing looking toward the wrecked van
	var spawn_world := Vector3(
		blueprint.crash_site_pos.x + 5.8,
		0.0,
		blueprint.crash_site_pos.z + 4.8
	)
	spawn_world.y = sampler.get_height(spawn_world.x, spawn_world.z) + 0.15

	floating_origin.set_origin_to_world_pos(spawn_world)
	chunk_streamer.setup(sampler, floating_origin, spawn_world)
	var preload_stats: Dictionary = chunk_streamer.preload_initial_chunks(spawn_world)
	last_preload_stats = preload_stats

	if spawn_player:
		_spawn_player_at_world(spawn_world)

	if not DisplayServer.get_name().contains("headless"):
		print("[CascadeWorld] seed=%d blueprint=%dms preload_chunks=%d landmarks=%d foliage=%d wall=%dms world_spawn=%s" % [
			world_seed,
			blueprint.generation_ms,
			preload_stats.get("chunks_loaded", 0),
			chunk_streamer.get_active_landmark_count(),
			chunk_streamer.get_total_foliage_instances(),
			preload_stats.get("preload_wall_ms", 0),
			str(spawn_world),
		])
	return preload_stats


func get_player_world_position() -> Vector3:
	if player == null or floating_origin == null:
		return Vector3.ZERO
	return floating_origin.local_to_world(player.global_position)


func teleport_player_to_world(world_xz: Vector2) -> Vector3:
	var wy: float = sampler.get_height(world_xz.x, world_xz.y) + 0.25
	var target_world := Vector3(world_xz.x, wy, world_xz.y)
	chunk_streamer.clear_all_chunks()
	floating_origin.set_origin_to_world_pos(target_world)
	chunk_streamer.preload_initial_chunks(target_world)
	if player != null:
		var local_p: Vector3 = floating_origin.world_to_local(target_world)
		player.global_position = local_p
		if player.camera_pivot != null:
			player.camera_pivot.global_position = local_p + Vector3(0.0, 1.32, 0.0)
	return target_world


func _process(delta: float) -> void:
	if chunk_streamer == null:
		return
	_anim_elapsed += delta
	for lm in chunk_streamer.get_active_landmarks():
		for b in lm["beacons"]:
			var pulse: float = pow(maxf(0.0, sin(_anim_elapsed * 1.45 + float(lm["id"]))), 3.0)
			var l: OmniLight3D = b["light"]
			var m: StandardMaterial3D = b["mat"]
			if is_instance_valid(l):
				l.light_energy = lerpf(0.8, float(b["base"]), pulse)
			if m != null:
				m.emission_energy_multiplier = lerpf(1.2, 9.5, pulse)
		for sw in lm["swaying"]:
			var n: Node3D = sw["node"]
			if is_instance_valid(n):
				var ph: float = float(sw["phase"])
				var sp: float = float(sw["speed"])
				var am: float = float(sw["amp"])
				n.rotation.z = sin(_anim_elapsed * sp + ph) * am
				n.rotation.x = cos(_anim_elapsed * sp * 0.73 + ph) * am * 0.55
		for fl in lm["flickers"]:
			var fl_l: OmniLight3D = fl["light"]
			if is_instance_valid(fl_l):
				var sp2: float = float(fl["speed"])
				var ph2: float = float(fl["phase"])
				var noise: float = sin(_anim_elapsed * sp2 + ph2) * 0.14 + sin(_anim_elapsed * sp2 * 2.41 + ph2 * 1.3) * 0.09
				fl_l.light_energy = float(fl["base"]) * (1.0 + noise)


func _physics_process(_delta: float) -> void:
	if player == null or floating_origin == null or chunk_streamer == null:
		return
	floating_origin.check_and_shift(player.global_position, _tracked_nodes)
	chunk_streamer.step_streaming(floating_origin.local_to_world(player.global_position))


func _spawn_player_at_world(world_pos: Vector3) -> void:
	var player_ps: PackedScene = load("res://scenes/PlayerCharacter.tscn")
	if player_ps == null:
		push_error("[CascadeWorld] Missing res://scenes/PlayerCharacter.tscn")
		return
	player = player_ps.instantiate() as ThirdPersonPlayer
	var local_pos: Vector3 = floating_origin.world_to_local(world_pos)
	player.position = local_pos
	add_child(player)
	if player.camera != null:
		player.camera.far = 900.0
	var look_target := blueprint.crash_site_pos
	var yaw: float = atan2(-(look_target.x - world_pos.x), -(look_target.z - world_pos.z))
	player.set_initial_heading(yaw)
	_tracked_nodes = [player]


func _clear_children() -> void:
	_tracked_nodes.clear()
	for c in get_children():
		remove_child(c)
		c.queue_free()


func _build_atmosphere_and_lighting() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.016, 0.026, 0.050)
	sky_mat.sky_horizon_color = Color(0.058, 0.088, 0.132)
	sky_mat.ground_bottom_color = Color(0.012, 0.016, 0.022)
	sky_mat.ground_horizon_color = Color(0.042, 0.062, 0.090)
	sky_mat.sky_curve = 0.24
	sky_mat.ground_curve = 0.14
	sky_mat.sun_angle_max = 8.0
	sky_mat.sun_curve = 0.08

	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_color = Color(0.14, 0.20, 0.29)
	env.ambient_light_energy = 0.72

	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.32
	env.tonemap_white = 4.2

	env.ssao_enabled = true
	env.ssao_radius = 1.05
	env.ssao_intensity = 1.48
	env.ssao_power = 1.45

	env.ssil_enabled = true
	env.ssil_radius = 4.5
	env.ssil_intensity = 1.12
	env.ssil_sharpness = 0.90

	env.ssr_enabled = true
	env.ssr_max_steps = 48
	env.ssr_fade_in = 0.14
	env.ssr_fade_out = 2.0
	env.ssr_depth_tolerance = 0.25

	env.sdfgi_enabled = true
	env.sdfgi_use_occlusion = true
	env.sdfgi_read_sky_light = true
	env.sdfgi_bounce_feedback = 0.45
	env.sdfgi_cascades = 4
	env.sdfgi_min_cell_size = 0.28
	env.sdfgi_y_scale = Environment.SDFGI_Y_SCALE_75_PERCENT

	env.glow_enabled = true
	env.glow_intensity = 0.70
	env.glow_bloom = 0.22
	env.glow_hdr_threshold = 1.0

	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_density = 0.0042
	env.fog_light_color = Color(0.115, 0.165, 0.235)
	env.fog_light_energy = 0.88
	env.fog_sky_affect = 0.65
	env.fog_height = 6.0
	env.fog_height_density = 0.024

	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.018
	env.volumetric_fog_albedo = Color(0.24, 0.34, 0.46)
	env.volumetric_fog_emission = Color(0.014, 0.024, 0.036)
	env.volumetric_fog_anisotropy = 0.56
	env.volumetric_fog_length = 110.0
	env.volumetric_fog_detail_spread = 2.2

	var we := WorldEnvironment.new()
	we.name = "CascadeAtmosphere"
	we.environment = env
	add_child(we)

	var moon := DirectionalLight3D.new()
	moon.name = "MoonlightKey"
	moon.rotation_degrees = Vector3(-34.0, 128.0, 0.0)
	moon.light_color = Color(0.56, 0.70, 0.96)
	moon.light_energy = 0.98
	moon.shadow_enabled = true
	moon.shadow_bias = 0.05
	moon.shadow_normal_bias = 1.5
	moon.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	moon.directional_shadow_max_distance = 120.0
	add_child(moon)

	var rim := DirectionalLight3D.new()
	rim.name = "CanopySkyRim"
	rim.rotation_degrees = Vector3(-48.0, -44.0, 0.0)
	rim.light_color = Color(0.26, 0.36, 0.52)
	rim.light_energy = 0.36
	rim.shadow_enabled = false
	add_child(rim)
