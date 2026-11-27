class_name ForestTerrainData
extends RefCounted

const WORLD_SIZE: float = 260.0
const HALF_WORLD: float = 130.0
const CREEK_Z_BASE: float = 34.0
const RELAY_CENTER: Vector2 = Vector2(-2.0, -36.0)
const CAMP_CENTER: Vector2 = Vector2(28.0, 4.0)

var seed_value: int = 4041994
var _noise_macro: FastNoiseLite
var _noise_detail: FastNoiseLite
var _noise_warp: FastNoiseLite


func _init(world_seed: int = 4041994) -> void:
	seed_value = world_seed
	_noise_macro = FastNoiseLite.new()
	_noise_macro.seed = world_seed
	_noise_macro.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise_macro.frequency = 0.014
	_noise_macro.fractal_octaves = 4
	_noise_macro.fractal_lacunarity = 2.05
	_noise_macro.fractal_gain = 0.48

	_noise_detail = FastNoiseLite.new()
	_noise_detail.seed = world_seed + 137
	_noise_detail.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise_detail.frequency = 0.055
	_noise_detail.fractal_octaves = 3

	_noise_warp = FastNoiseLite.new()
	_noise_warp.seed = world_seed + 509
	_noise_warp.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise_warp.frequency = 0.022


func get_trail_center_x(z: float) -> float:
	# Main winding logging track passing through the south trailhead,
	# crossing the creek at z~34, climbing into the relay clearing near (-2, -36).
	var main_curve: float = sin(z * 0.042 + 0.35) * 9.5 + cos(z * 0.019 - 0.8) * 5.2
	# Blend smoothly toward Relay Clearing X = -2.0 near z = -36
	var clearing_pull: float = exp(-pow((z - RELAY_CENTER.y) / 28.0, 2.0))
	return lerpf(main_curve, RELAY_CENTER.x, clearing_pull * 0.88)


func get_spur_trail_z(x: float) -> float:
	# Narrow overgrown side spur leading from main trail east into abandoned camp (28, 4)
	return 14.5 - 0.36 * x + sin(x * 0.21) * 1.4


func get_main_trail_distance(x: float, z: float) -> float:
	# Project approx distance to serpentine z-axis trail with slope tangent scaling
	var cx: float = get_trail_center_x(z)
	var cx_next: float = get_trail_center_x(z + 0.5)
	var dx_dz: float = (cx_next - cx) / 0.5
	return absf(x - cx) / sqrt(1.0 + dx_dz * dx_dz)


func get_spur_distance(x: float, z: float) -> float:
	var start_x: float = get_trail_center_x(14.5)
	if x < start_x - 1.5 or x > CAMP_CENTER.x + 2.0:
		return 999.0
	var cz: float = get_spur_trail_z(x)
	var cz_next: float = get_spur_trail_z(x + 0.5)
	var dz_dx: float = (cz_next - cz) / 0.5
	return absf(z - cz) / sqrt(1.0 + dz_dx * dz_dx)


func get_trail_distance(x: float, z: float) -> float:
	return minf(get_main_trail_distance(x, z), get_spur_distance(x, z))


func get_creek_center_z(x: float) -> float:
	return CREEK_Z_BASE + sin(x * 0.048) * 6.2 + cos(x * 0.095 + 1.1) * 2.1


func get_creek_distance(x: float, z: float) -> float:
	var cz: float = get_creek_center_z(x)
	var cz_next: float = get_creek_center_z(x + 0.5)
	var dz_dx: float = (cz_next - cz) / 0.5
	return absf(z - cz) / sqrt(1.0 + dz_dx * dz_dx)


func get_relay_clearing_factor(x: float, z: float) -> float:
	var d: float = Vector2(x, z).distance_to(RELAY_CENTER)
	return clampf(1.0 - smoothstep(13.5, 22.0, d), 0.0, 1.0)


func get_camp_clearing_factor(x: float, z: float) -> float:
	var d: float = Vector2(x, z).distance_to(CAMP_CENTER)
	return clampf(1.0 - smoothstep(5.8, 10.5, d), 0.0, 1.0)


func get_clearing_mask(x: float, z: float) -> float:
	return maxf(get_relay_clearing_factor(x, z), get_camp_clearing_factor(x, z))


func get_height(x: float, z: float) -> float:
	# Base undulating forest hills
	var wx: float = x + _noise_warp.get_noise_2d(x, z) * 14.0
	var wz: float = z + _noise_warp.get_noise_2d(x + 80.0, z - 60.0) * 14.0
	var macro_h: float = _noise_macro.get_noise_2d(wx, wz) * 5.2
	var detail_h: float = _noise_detail.get_noise_2d(x, z) * 0.72

	# Gentle north-south grade rising subtly toward the relay station knoll
	var grade: float = clampf((-z + 20.0) * 0.022, -1.2, 2.6)
	var base_h: float = macro_h + detail_h + grade

	# Perimeter framing ridges (keeps deep woods horizon tall on all edges)
	var edge_dist: float = maxf(absf(x), absf(z))
	if edge_dist > 82.0:
		var t: float = clampf((edge_dist - 82.0) / 48.0, 0.0, 1.0)
		base_h += t * t * 14.5

	# Flatten relay outpost clearing pad smoothly to a stable working grade (~2.2m)
	var relay_w: float = get_relay_clearing_factor(x, z)
	if relay_w > 0.0:
		base_h = lerpf(base_h, 2.25, relay_w)

	# Flatten camp clearing pad cleanly (~0.95m)
	var camp_w: float = get_camp_clearing_factor(x, z)
	if camp_w > 0.0:
		base_h = lerpf(base_h, 0.95, camp_w * 0.92)

	# Carve main dirt road bed smoothly (flattening cross-slope & slight tire ruts)
	var d_main: float = get_main_trail_distance(x, z)
	if d_main < 6.0:
		var road_smooth: float = 1.0 - smoothstep(1.8, 5.8, d_main)
		var road_center_h: float = _get_raw_centerline_height(z)
		base_h = lerpf(base_h, road_center_h, road_smooth * 0.78)
		# Dual shallow wheel ruts inside main road (r ~ 0.95m from centerline)
		if d_main < 2.1:
			var rut: float = exp(-pow((absf(d_main) - 0.92) / 0.34, 2.0))
			base_h -= rut * 0.11

	# Carve meandering creek ravine across south forest (bridge straddles it cleanly)
	var d_creek: float = get_creek_distance(x, z)
	if d_creek < 7.5:
		var bank: float = 1.0 - smoothstep(1.4, 7.2, d_creek)
		# Deeper carve below surrounding ground; soften slightly under bridge abutment
		var bridge_x: float = get_trail_center_x(CREEK_Z_BASE)
		var bridge_blend: float = 1.0 - smoothstep(2.4, 5.2, absf(x - bridge_x)) * 0.2
		base_h -= bank * (1.75 + 0.3 * sin(x * 0.14)) * (0.9 + 0.1 * bridge_blend)

	return base_h


func _get_raw_centerline_height(z: float) -> float:
	var cx: float = get_trail_center_x(z)
	var wx: float = cx + _noise_warp.get_noise_2d(cx, z) * 14.0
	var wz: float = z + _noise_warp.get_noise_2d(cx + 80.0, z - 60.0) * 14.0
	var macro_h: float = _noise_macro.get_noise_2d(wx, wz) * 4.4
	var grade: float = clampf((-z + 20.0) * 0.022, -1.2, 2.6)
	var h: float = macro_h + grade
	var d_relay: float = Vector2(cx, z).distance_to(RELAY_CENTER)
	var relay_w: float = clampf(1.0 - smoothstep(13.5, 22.0, d_relay), 0.0, 1.0)
	return lerpf(h, 2.25, relay_w)


func get_normal(x: float, z: float) -> Vector3:
	const EPS: float = 0.45
	var h_l: float = get_height(x - EPS, z)
	var h_r: float = get_height(x + EPS, z)
	var h_d: float = get_height(x, z - EPS)
	var h_u: float = get_height(x, z + EPS)
	return Vector3(h_l - h_r, 2.0 * EPS, h_d - h_u).normalized()


func get_creek_water_level() -> float:
	var bx: float = get_trail_center_x(CREEK_Z_BASE)
	return _get_raw_centerline_height(CREEK_Z_BASE) - 1.18


func get_terrain_weights(x: float, z: float) -> Color:
	# R = mud trail & relay gravel/mud pad
	# G = roadside decaying leaves & forest clearings
	# B = wet mud / creek specular puddles
	var d_main: float = get_main_trail_distance(x, z)
	var d_spur: float = get_spur_distance(x, z)
	var d_creek: float = get_creek_distance(x, z)
	var d_trail: float = minf(d_main, d_spur)
	var relay_w: float = get_relay_clearing_factor(x, z)
	var camp_w: float = get_camp_clearing_factor(x, z)

	var w_mud: float = 1.0 - smoothstep(1.3, 2.9, d_trail)
	w_mud = maxf(w_mud, 1.0 - smoothstep(1.6, 3.8, d_creek))
	w_mud = maxf(w_mud, relay_w * 0.65)

	var w_leaf: float = (1.0 - smoothstep(1.9, 6.8, d_trail)) * 0.9
	w_leaf = maxf(w_leaf, camp_w * 0.85)
	w_leaf = maxf(w_leaf, relay_w * 0.55)

	# Wet ruts + soaked creek bed + damp mossy dips
	var rut_wet: float = 0.0
	if d_main < 2.0:
		rut_wet = exp(-pow((absf(d_main) - 0.92) / 0.42, 2.0)) * 0.82
	var creek_wet: float = (1.0 - smoothstep(1.5, 4.4, d_creek)) * 0.95
	var w_wet: float = maxf(rut_wet, creek_wet)

	return Color(clampf(w_mud, 0.0, 1.0), clampf(w_leaf, 0.0, 1.0), clampf(w_wet, 0.0, 1.0), 1.0)
