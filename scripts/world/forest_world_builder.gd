@tool
class_name ForestWorldBuilder
extends Node3D

@export var world_seed: int = 4041994
@export var spawn_player: bool = true
@export var rebuild_in_editor: bool = false:
	set(val):
		rebuild_in_editor = false
		if Engine.is_editor_hint() and is_inside_tree():
			generate_world()

var _terrain: ForestTerrainData
var _animated: Dictionary = {}
var _elapsed: float = 0.0
var _generated: bool = false


func _ready() -> void:
	generate_world()


func generate_world() -> Dictionary:
	_clear_generated_children()
	_elapsed = 0.0

	_terrain = ForestTerrainData.new(world_seed)
	_build_atmosphere_and_lighting()
	ForestMeshBuilder.build_terrain(_terrain, self)

	var scatter := ForestFoliageScatter.new()
	var stats: Dictionary = scatter.populate(_terrain, self)
	_animated = ForestLandmarks.build_all(_terrain, self)

	_build_inspection_viewpoints()
	if spawn_player and not Engine.is_editor_hint():
		_spawn_player_character()
	_generated = true

	if not Engine.is_editor_hint():
		print("[ForestWorld] Built night forest seed=%d trees=%d total_foliage_instances=%d multimeshes=%d" % [
			world_seed,
			stats.get("tree_count", 0),
			stats.get("total_instances", 0),
			stats.get("multimesh_nodes", 0)
		])
	return stats


func get_terrain_data() -> ForestTerrainData:
	return _terrain


func _clear_generated_children() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()


func _build_atmosphere_and_lighting() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.016, 0.026, 0.050)
	sky_mat.sky_horizon_color = Color(0.055, 0.084, 0.125)
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
	env.ssao_radius = 1.1
	env.ssao_intensity = 1.25

	env.glow_enabled = true
	env.glow_intensity = 0.72
	env.glow_bloom = 0.24
	env.glow_hdr_threshold = 1.0

	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_density = 0.019
	env.fog_light_color = Color(0.115, 0.165, 0.235)
	env.fog_light_energy = 0.88
	env.fog_sky_affect = 0.55
	env.fog_height = 2.8
	env.fog_height_density = 0.075

	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.026
	env.volumetric_fog_albedo = Color(0.24, 0.34, 0.46)
	env.volumetric_fog_emission = Color(0.014, 0.024, 0.036)
	env.volumetric_fog_anisotropy = 0.56
	env.volumetric_fog_length = 88.0
	env.volumetric_fog_detail_spread = 2.2

	var we := WorldEnvironment.new()
	we.name = "NightForestEnvironment"
	we.environment = env
	add_child(we)

	# Cold slate-blue moonlight slicing through treetops
	var moon := DirectionalLight3D.new()
	moon.name = "MoonlightKey"
	moon.rotation_degrees = Vector3(-34.0, 128.0, 0.0)
	moon.light_color = Color(0.56, 0.70, 0.96)
	moon.light_energy = 0.95
	moon.shadow_enabled = true
	moon.shadow_bias = 0.05
	moon.shadow_normal_bias = 1.5
	moon.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	moon.directional_shadow_max_distance = 92.0
	add_child(moon)

	# Cool atmospheric bounce fill so trunks & ferns read clearly in shadowed hollows
	var rim := DirectionalLight3D.new()
	rim.name = "CanopySkyRim"
	rim.rotation_degrees = Vector3(-48.0, -44.0, 0.0)
	rim.light_color = Color(0.26, 0.36, 0.52)
	rim.light_energy = 0.34
	rim.shadow_enabled = false
	add_child(rim)


func _build_inspection_viewpoints() -> void:
	var vp_root := Node3D.new()
	vp_root.name = "CameraViewpoints"
	add_child(vp_root)

	# Main Static Atmospheric Camera (Trail approach looking through lanterns & bridge toward crimson tower glow)
	var trail_z: float = 54.0
	var trail_x: float = _terrain.get_trail_center_x(trail_z)
	var trail_y: float = _terrain.get_height(trail_x, trail_z)
	var bridge_x: float = _terrain.get_trail_center_x(ForestTerrainData.CREEK_Z_BASE)
	var cam := Camera3D.new()
	cam.name = "StaticForestCamera"
	cam.fov = 62.0
	cam.far = 260.0
	cam.position = Vector3(trail_x - 0.6, trail_y + 2.35, trail_z)
	cam.current = not (spawn_player and not Engine.is_editor_hint())
	add_child(cam)
	cam.look_at(Vector3(bridge_x, _terrain.get_height(bridge_x, 34.0) + 2.4, 30.0), Vector3.UP)

	var marks: Array = [
		{"name": "View_TrailBridgeApproach", "pos": cam.position, "look": Vector3(bridge_x, _terrain.get_height(bridge_x, 34.0) + 2.0, 26.0)},
		{"name": "View_BrokenUtilityPole", "pos": Vector3(_terrain.get_trail_center_x(21.0) + 2.4, _terrain.get_height(_terrain.get_trail_center_x(21.0) + 2.4, 21.0) + 2.2, 21.0), "look": Vector3(_terrain.get_trail_center_x(11.5) - 1.2, _terrain.get_height(_terrain.get_trail_center_x(11.5), 11.5) + 2.5, 11.5)},
		{"name": "View_RelayOutpost", "pos": Vector3(ForestTerrainData.RELAY_CENTER.x + 14.5, _terrain.get_height(ForestTerrainData.RELAY_CENTER.x + 14.5, ForestTerrainData.RELAY_CENTER.y + 7.2) + 3.4, ForestTerrainData.RELAY_CENTER.y + 7.2), "look": Vector3(ForestTerrainData.RELAY_CENTER.x - 0.5, _terrain.get_height(ForestTerrainData.RELAY_CENTER.x, ForestTerrainData.RELAY_CENTER.y) + 5.2, ForestTerrainData.RELAY_CENTER.y - 1.8)},
		{"name": "View_ShackInteriorLook", "pos": Vector3(ForestTerrainData.RELAY_CENTER.x - 0.9, _terrain.get_height(ForestTerrainData.RELAY_CENTER.x, ForestTerrainData.RELAY_CENTER.y) + 1.68, ForestTerrainData.RELAY_CENTER.y + 1.95), "look": Vector3(ForestTerrainData.RELAY_CENTER.x - 4.4, _terrain.get_height(ForestTerrainData.RELAY_CENTER.x - 4.2, ForestTerrainData.RELAY_CENTER.y + 0.6) + 1.15, ForestTerrainData.RELAY_CENTER.y + 0.5)},
		{"name": "View_AbandonedCampsite", "pos": Vector3(ForestTerrainData.CAMP_CENTER.x - 5.2, _terrain.get_height(ForestTerrainData.CAMP_CENTER.x - 5.2, ForestTerrainData.CAMP_CENTER.y + 5.2) + 2.2, ForestTerrainData.CAMP_CENTER.y + 5.2), "look": Vector3(ForestTerrainData.CAMP_CENTER.x + 0.8, _terrain.get_height(ForestTerrainData.CAMP_CENTER.x, ForestTerrainData.CAMP_CENTER.y) + 1.0, ForestTerrainData.CAMP_CENTER.y - 0.5)},
		{"name": "View_DenseCanopyOverview", "pos": Vector3(32.0, 26.0, 22.0), "look": Vector3(0.0, 4.0, -18.0)}
	]
	for m in marks:
		var node := Marker3D.new()
		node.name = m["name"]
		node.position = m["pos"]
		vp_root.add_child(node)
		node.look_at(m["look"], Vector3.UP)


func _spawn_player_character() -> void:
	var player_ps: PackedScene = load("res://scenes/PlayerCharacter.tscn")
	if player_ps == null:
		push_error("[ForestWorld] Failed to load PlayerCharacter.tscn")
		return
	var player: ThirdPersonPlayer = player_ps.instantiate() as ThirdPersonPlayer
	var spawn_z: float = 50.0
	var spawn_x: float = _terrain.get_trail_center_x(spawn_z)
	var spawn_y: float = _terrain.get_height(spawn_x, spawn_z) + 0.05
	var ahead_z: float = 42.0
	var ahead_x: float = _terrain.get_trail_center_x(ahead_z)
	var yaw: float = atan2(-(ahead_x - spawn_x), -(ahead_z - spawn_z))

	player.position = Vector3(spawn_x, spawn_y, spawn_z)
	add_child(player)
	player.set_initial_heading(yaw)


func _process(delta: float) -> void:
	if not _generated or _animated.is_empty():
		return
	_elapsed += delta

	# Crimson aviation beacon slow ominous sweep pulse
	for b in _animated.get("beacons", []):
		var pulse: float = pow(maxf(0.0, sin(_elapsed * 1.45)), 3.0)
		var l: OmniLight3D = b["light"]
		var mat: StandardMaterial3D = b["mat"]
		l.light_energy = lerpf(1.2, float(b["base"]), pulse)
		mat.emission_energy_multiplier = lerpf(1.5, 9.5, pulse)

	# Gentle breeze swaying lantern hooks along the muddy road
	for sw in _animated.get("swaying_lanterns", []):
		var n: Node3D = sw["node"]
		var ph: float = float(sw["phase"])
		var sp: float = float(sw["speed"])
		var am: float = float(sw["amp"])
		n.rotation.z = sin(_elapsed * sp + ph) * am
		n.rotation.x = cos(_elapsed * sp * 0.73 + ph) * am * 0.55

	# Subtle organic flame/filament/spark variance (world ambiance only)
	for fl in _animated.get("flicker_lights", []):
		var l2: OmniLight3D = fl["light"]
		var sp2: float = float(fl["speed"])
		var ph2: float = float(fl["phase"])
		var noise: float = sin(_elapsed * sp2 + ph2) * 0.10 + sin(_elapsed * sp2 * 2.37 + ph2 * 1.4) * 0.06
		l2.light_energy = float(fl["base"]) * (1.0 + noise)
