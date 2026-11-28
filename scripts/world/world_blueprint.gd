class_name WorldBlueprint
extends RefCounted

const WORLD_SIZE: float = 32000.0
const HALF_WORLD: float = 16000.0
const CHUNK_SIZE: float = 128.0
const GRID_CHUNKS: int = 250
const BUCKET_SIZE: float = 512.0
const ROUTER_GRID: int = 160 # 200m cells over 32km

enum StructureKind {
	CRASH_SITE,
	RELAY_TOWER,
	INDUSTRIAL_HUB,
	SAFE_HOUSE,
	TUNNEL_PORTAL,
	QUARANTINE_GATE,
	CAMPSITE_OR_DECOY,
	FINALE_CACHE,
	BRIDGE,
}

enum RouteKind {
	HIGHWAY_PAVED,
	LOG_TRAIL_DIRT,
	RAIL_SPUR,
	POWER_LINE,
}

var world_seed: int = 4041994
var generation_ms: int = 0

# Thread-safe immutable noise fields configured during _init()
var noise_warp_x: FastNoiseLite
var noise_warp_z: FastNoiseLite
var noise_elev_macro: FastNoiseLite
var noise_elev_ridge: FastNoiseLite
var noise_elev_detail: FastNoiseLite
var noise_moisture: FastNoiseLite
var noise_blight: FastNoiseLite
var noise_fault_vein: FastNoiseLite
var noise_human: FastNoiseLite
var noise_micro: FastNoiseLite

# Stored macro features
var enclaves: Array[Dictionary] = []
var structures: Array[Dictionary] = []
var routes: Array[Dictionary] = []
var river_paths: Array[Array] = []

# O(1) spatial hash buckets keyed by Vector2i(floor(x / BUCKET_SIZE), floor(z / BUCKET_SIZE))
var enclave_buckets: Dictionary = {}
var site_buckets: Dictionary = {}
var road_buckets: Dictionary = {}
var river_buckets: Dictionary = {}

var crash_site_pos: Vector3 = Vector3.ZERO
var finale_cache_pos: Vector3 = Vector3.ZERO
var _rng := RandomNumberGenerator.new()
var _astar_g := PackedFloat32Array()
var _astar_came := PackedInt32Array()
var _astar_stamp := PackedInt32Array()
var _astar_cur_stamp: int = 0


func _init(seed_val: int = 4041994) -> void:
	var t0: int = Time.get_ticks_msec()
	world_seed = seed_val
	_rng.seed = seed_val
	_setup_noises()
	_generate_rivers()
	_generate_enclaves()
	_place_structures()
	_route_networks()
	_detect_river_bridges()
	generation_ms = Time.get_ticks_msec() - t0


func _setup_noises() -> void:
	noise_warp_x = _make_noise(world_seed + 11, 0.00018, 2, FastNoiseLite.FRACTAL_FBM)
	noise_warp_z = _make_noise(world_seed + 29, 0.00018, 2, FastNoiseLite.FRACTAL_FBM)
	noise_elev_macro = _make_noise(world_seed + 47, 0.00011, 4, FastNoiseLite.FRACTAL_FBM)
	noise_elev_ridge = _make_noise(world_seed + 83, 0.00016, 4, FastNoiseLite.FRACTAL_RIDGED)
	noise_elev_detail = _make_noise(world_seed + 131, 0.0014, 3, FastNoiseLite.FRACTAL_FBM)
	noise_moisture = _make_noise(world_seed + 193, 0.00022, 3, FastNoiseLite.FRACTAL_FBM)
	noise_blight = _make_noise(world_seed + 257, 0.00025, 4, FastNoiseLite.FRACTAL_FBM)
	noise_fault_vein = _make_noise(world_seed + 311, 0.00038, 3, FastNoiseLite.FRACTAL_RIDGED)
	noise_human = _make_noise(world_seed + 401, 0.00029, 3, FastNoiseLite.FRACTAL_FBM)
	noise_micro = _make_noise(world_seed + 503, 0.0065, 2, FastNoiseLite.FRACTAL_FBM)


func _make_noise(s: int, freq: float, octaves: int, ftype: FastNoiseLite.FractalType) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = s
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.fractal_type = ftype
	n.fractal_octaves = octaves
	n.fractal_lacunarity = 2.05
	n.fractal_gain = 0.50
	return n


func get_bucket_key(x: float, z: float) -> Vector2i:
	return Vector2i(int(floor(x / BUCKET_SIZE)), int(floor(z / BUCKET_SIZE)))


func _warp_coords(x: float, z: float) -> Vector2:
	var wx: float = x + noise_warp_x.get_noise_2d(x, z) * 1350.0
	var wz: float = z + noise_warp_z.get_noise_2d(x + 4100.0, z - 3700.0) * 1350.0
	return Vector2(wx, wz)


func eval_macro_height(x: float, z: float) -> float:
	# Pure continuous base elevation before fine road/pad cuts (fast & safe for routing and river carving)
	var w: Vector2 = _warp_coords(x, z)
	var macro_n: float = noise_elev_macro.get_noise_2d(w.x, w.y) # ~ -0.7..0.7
	var ridge_n: float = maxf(0.0, noise_elev_ridge.get_noise_2d(w.x * 1.12, w.y * 1.12))
	var basin_h: float = (macro_n * 0.5 + 0.5) * 95.0 + pow(ridge_n, 1.45) * 185.0

	# Natural Cascade boundary mountains sealing the 32km valley rim with organic warped contours
	var edge_d: float = maxf(absf(x + (w.x - x) * 0.42), absf(z + (w.y - z) * 0.42))
	if edge_d > 13900.0:
		var t: float = clampf((edge_d - 13900.0) / 2100.0, 0.0, 1.0)
		basin_h += t * t * 240.0

	return basin_h


func eval_climate_fields(x: float, z: float) -> Dictionary:
	var w: Vector2 = _warp_coords(x, z)
	var macro_h: float = eval_macro_height(x, z)
	var elev_norm: float = clampf(macro_h / 260.0, 0.0, 1.0)

	var moist: float = clampf(noise_moisture.get_noise_2d(w.x, w.y) * 0.65 + 0.5, 0.0, 1.0)
	# Moisture rises in lower basins
	moist = clampf(moist + (1.0 - elev_norm) * 0.22 - 0.10, 0.0, 1.0)

	# Blight combines broad warped corruption patches + sharp fault-line tendrils (FRACTAL_RIDGED inverted!)
	var blight_patch: float = clampf(noise_blight.get_noise_2d(w.x * 1.25, w.y * 1.25) * 0.76 + 0.48, 0.0, 1.0)
	var vein_raw: float = clampf(noise_fault_vein.get_noise_2d(w.x, w.y), 0.0, 1.0)
	var vein_tendril: float = smoothstep(0.66, 0.92, vein_raw) * 0.72
	var blight: float = clampf(maxf(blight_patch, vein_tendril), 0.0, 1.0)

	var human: float = clampf(noise_human.get_noise_2d(w.x, w.y) * 0.72 + 0.42, 0.0, 1.0)
	var micro: float = noise_micro.get_noise_2d(x, z) # -1..1 micro jitter

	return {
		"elev_norm": elev_norm,
		"moist": moist,
		"blight": blight,
		"human": human,
		"micro": micro,
	}


func _generate_rivers() -> void:
	# Trace 6 meandering rivers draining smoothly across the basin with forward outflow momentum (no loops)
	for i in range(6):
		var a_start: float = (float(i) / 6.0) * TAU + _rng.randf_range(-0.28, 0.28)
		var start_r: float = _rng.randf_range(10800.0, 13400.0)
		var cur := Vector2(cos(a_start) * start_r, sin(a_start) * start_r)
		var a_out: float = a_start + PI + _rng.randf_range(-0.55, 0.55)
		var out_target := Vector2(cos(a_out) * 14500.0, sin(a_out) * 14500.0)
		var flow_bias: Vector2 = (out_target - cur).normalized()
		var dir: Vector2 = flow_bias
		var pts: Array[Vector2] = [cur]
		var step_len: float = 360.0

		for s in range(62):
			var eps: float = 240.0
			var gx: float = eval_macro_height(cur.x + eps, cur.y) - eval_macro_height(cur.x - eps, cur.y)
			var gz: float = eval_macro_height(cur.x, cur.y + eps) - eval_macro_height(cur.x, cur.y - eps)
			var descent := Vector2(-gx, -gz)
			if descent.length_squared() > 0.01:
				descent = descent.normalized()
			else:
				descent = flow_bias

			# Reject reverse slope pull inside small bowls so river drains cleanly without curling into loops
			if descent.dot(flow_bias) < 0.15:
				descent = (descent + flow_bias * 1.4).normalized()

			var meander: float = sin(float(s) * 0.34 + float(i) * 2.1) * 0.42 + noise_micro.get_noise_2d(cur.x * 0.12, cur.y * 0.12) * 0.32
			var steered: Vector2 = (flow_bias * 0.52 + dir * 0.26 + descent * 0.22).normalized().rotated(meander * 0.45)
			if steered.dot(flow_bias) < 0.32:
				steered = (steered + flow_bias).normalized()
			dir = steered

			var next_p: Vector2 = cur + dir * step_len
			if absf(next_p.x) > 14700.0 or absf(next_p.y) > 14700.0:
				pts.append(next_p)
				break
			pts.append(next_p)
			cur = next_p

		if pts.size() >= 6:
			var smooth_pts: Array[Vector2] = _smooth_polyline(pts, 2)
			river_paths.append(smooth_pts)
			for k in range(smooth_pts.size() - 1):
				var progress: float = float(k) / float(smooth_pts.size())
				var half_w: float = lerpf(3.2, 11.5, progress)
				_register_segment_in_buckets(river_buckets, {
					"a": smooth_pts[k],
					"b": smooth_pts[k + 1],
					"half_width": half_w,
					"river_id": i,
				})


func _generate_enclaves() -> void:
	# Scatter ~250 non-circular warped enclaves, Green Islands, Ash Sinkholes & micro-pockets
	var eid: int = 0
	var placed_centers: Array[Vector2] = []

	for attempt in range(950):
		if enclaves.size() >= 255:
			break
		var x: float = _rng.randf_range(-13800.0, 13800.0)
		var z: float = _rng.randf_range(-13800.0, 13800.0)
		var cf: Dictionary = eval_climate_fields(x, z)
		var blight: float = cf["blight"]
		var elev: float = cf["elev_norm"]
		var moist: float = cf["moist"]

		# Determine organic enclave type opposing or fracturing the local base field
		var target_biome: int = BiomeRegistry.Id.MYCORRHIZAL_SINKHOLE
		var rad_a: float = _rng.randf_range(120.0, 560.0)
		var rad_b: float = rad_a * _rng.randf_range(0.45, 0.92)
		var height_delta: float = 0.0
		var anomaly_delta: float = 0.0

		if blight > 0.56:
			# Inside ash/corruption barrens -> spawn vital "Green Island" refuges!
			target_biome = BiomeRegistry.Id.GREEN_ISLAND
			rad_a = _rng.randf_range(140.0, 440.0)
			rad_b = rad_a * _rng.randf_range(0.50, 0.88)
			height_delta = _rng.randf_range(2.5, 9.0)
			anomaly_delta = -1.0 # Stabilizes compass needles cleanly inside Green Islands
		elif elev > 0.70:
			# Inside ridges -> windfall deadwood pockets or rocky scree
			target_biome = BiomeRegistry.Id.PALE_BONEWOOD if _rng.randf() < 0.5 else BiomeRegistry.Id.WINDFALL_SADDLE
			rad_a = _rng.randf_range(95.0, 340.0)
			rad_b = rad_a * _rng.randf_range(0.42, 0.85)
			height_delta = _rng.randf_range(-5.0, 4.0)
			anomaly_delta = 0.55 if target_biome == BiomeRegistry.Id.PALE_BONEWOOD else 0.15
		else:
			# Inside healthy sunken timber -> drop sinister sinkholes, burn scars, sulfur craters, flooded marshes, or overgrown sidings
			var roll: float = _rng.randf()
			if roll < 0.34:
				target_biome = BiomeRegistry.Id.MYCORRHIZAL_SINKHOLE
				height_delta = _rng.randf_range(-14.0, -5.5)
				anomaly_delta = 0.92
			elif roll < 0.56:
				target_biome = BiomeRegistry.Id.BURN_SCAR
				height_delta = _rng.randf_range(-3.0, 1.5)
				anomaly_delta = 0.60
			elif roll < 0.74:
				target_biome = BiomeRegistry.Id.PALE_BONEWOOD
				height_delta = _rng.randf_range(-2.0, 5.0)
				anomaly_delta = 0.75
			elif roll < 0.90 and moist > 0.40:
				target_biome = BiomeRegistry.Id.ALDER_SLOUGH
				height_delta = _rng.randf_range(-6.5, -2.5)
				anomaly_delta = 0.25
			else:
				target_biome = BiomeRegistry.Id.CULVERT_DRAIN
				rad_a = _rng.randf_range(75.0, 220.0)
				rad_b = rad_a * _rng.randf_range(0.45, 0.80)
				height_delta = _rng.randf_range(-7.0, -2.0)
				anomaly_delta = 0.65

		# Keep large enclaves spaced enough so pockets stay legible rather than mushing into one blob
		var min_gap: float = maxf(rad_a * 0.95, 220.0)
		var overlap: bool = false
		for pc in placed_centers:
			if pc.distance_squared_to(Vector2(x, z)) < min_gap * min_gap:
				overlap = true
				break
		if overlap:
			continue

		var ang: float = _rng.randf_range(0.0, TAU)
		var enc: Dictionary = {
			"id": eid,
			"biome_id": target_biome,
			"center": Vector2(x, z),
			"rad_a": rad_a,
			"rad_b": rad_b,
			"cos_a": cos(ang),
			"sin_a": sin(ang),
			"lobe_a": float(_rng.randi_range(2, 5)),
			"lobe_b": float(_rng.randi_range(3, 7)),
			"phase_a": _rng.randf_range(0.0, TAU),
			"phase_b": _rng.randf_range(0.0, TAU),
			"warp_amp": _rng.randf_range(0.26, 0.44),
			"height_delta": height_delta,
			"anomaly_delta": anomaly_delta,
			"max_reach": rad_a * 1.65,
		}
		enclaves.append(enc)
		placed_centers.append(Vector2(x, z))
		_register_circle_in_buckets(enclave_buckets, enc["center"], enc["max_reach"], enc)
		eid += 1


func _place_structures() -> void:
	# 1. Cold-Open Crash Site (south-central valley perimeter corridor)
	var crash_x: float = _rng.randf_range(-1600.0, 1600.0)
	var crash_z: float = _rng.randf_range(7400.0, 9600.0)
	crash_site_pos = _add_structure(StructureKind.CRASH_SITE, "Kilometer0_CrashSite", Vector2(crash_x, crash_z), 28.0, 1.0)

	# 2. 6 Outer Quarantine Perimeter Gates around the basin edges
	for i in range(6):
		var a: float = (float(i) / 6.0) * TAU + _rng.randf_range(-0.22, 0.22)
		var r: float = _rng.randf_range(12200.0, 13400.0)
		_add_structure(StructureKind.QUARANTINE_GATE, "QuarantineGate_%d" % i, Vector2(cos(a) * r, sin(a) * r), 34.0, 1.0)

	# 3. 4 Major Industrial Hubs (4x scale: Mill, Rail Yard, Quarry, Logging Depot)
	var hub_names: Array[String] = ["Old_Lumber_Mill", "Rusted_Rail_Yard", "Gravel_Quarry_Cut", "Logging_Dispatch_Depot"]
	var hub_biomes: Array[int] = [
		BiomeRegistry.Id.LUMBER_MILL_GROUNDS,
		BiomeRegistry.Id.RAIL_SPUR_YARD,
		BiomeRegistry.Id.QUARRY_CUT,
		BiomeRegistry.Id.LOGGING_DEPOT
	]
	for i in range(4):
		var p: Vector2 = _sample_site_pos(12500.0, 5800.0, 0.0, 0.56, i == 2)
		_add_structure(StructureKind.INDUSTRIAL_HUB, hub_names[i], p, 64.0, 2.5, hub_biomes[i])

	# 4. 16 Regional Relay Towers (4x scale; biased to elevated ridges for sightline triangulation)
	for i in range(16):
		var best_p: Vector2 = _sample_site_pos(13400.0, 3600.0, 0.42, 0.88, true)
		_add_structure(StructureKind.RELAY_TOWER, "Relay_Tower_%02d" % (i + 1), best_p, 24.0, 0.5)

	# 5. 4 Sub-Surface Tunnel Networks (4 linked culvert/hatch portals each = 16 portals)
	for net_id in range(4):
		var anchor: Vector2 = _sample_site_pos(12000.0, 3200.0, 0.15, 0.72, false)
		for sub in range(4):
			var ang: float = (float(sub) / 4.0) * TAU + _rng.randf_range(-0.4, 0.4)
			var dist: float = _rng.randf_range(280.0, 760.0)
			var hp: Vector2 = Vector2(clampf(anchor.x + cos(ang) * dist, -13800.0, 13800.0), clampf(anchor.y + sin(ang) * dist, -13800.0, 13800.0))
			_add_structure(StructureKind.TUNNEL_PORTAL, "Tunnel_%d_%d" % [net_id + 1, sub + 1], hp, 18.0, -1.5, -1, net_id)

	# 6. 32 Safe-Houses (Cabins & Fire-Watch Lookouts, including guaranteed Green Island sanctuaries)
	var green_islands: Array[Dictionary] = []
	for enc in enclaves:
		if int(enc["biome_id"]) == BiomeRegistry.Id.GREEN_ISLAND:
			green_islands.append(enc)
	var gi_used: int = 0
	for i in range(32):
		var sp: Vector2 = Vector2.ZERO
		if i < 5 and gi_used < green_islands.size():
			var idx: int = (gi_used * 3 + 1) % green_islands.size()
			sp = green_islands[idx]["center"]
			gi_used += 1
		else:
			sp = _sample_site_pos(13400.0, 1850.0, 0.12, 0.85, i % 3 == 0)
		_add_structure(StructureKind.SAFE_HOUSE, "SafeHouse_%02d" % (i + 1), sp, 19.0, 0.4)

	# 7. 64 Campsites, Decoy Transmitters & Survey Outposts scattered organically
	for i in range(64):
		var cp: Vector2 = _sample_site_pos(13600.0, 850.0, 0.05, 0.78, false)
		_add_structure(StructureKind.CAMPSITE_OR_DECOY, "FieldCamp_%02d" % (i + 1), cp, 11.5, 0.0)

	# 8. Hidden Emergency Survey Cache (Finale) >= 10.5km away from crash site in high-anomaly sector
	var fin_best: Vector2 = Vector2(-crash_x, -crash_z * 0.9)
	var fin_score: float = -1e9
	for _k in range(120):
		var cx: float = _rng.randf_range(-12600.0, 12600.0)
		var cz: float = _rng.randf_range(-12600.0, 12600.0)
		var d_crash: float = Vector2(cx, cz).distance_to(Vector2(crash_x, crash_z))
		if d_crash < 10500.0:
			continue
		var cf: Dictionary = eval_climate_fields(cx, cz)
		var sc: float = cf["blight"] * 2.0 + (d_crash / 16000.0) - cf["human"]
		if sc > fin_score:
			fin_score = sc
			fin_best = Vector2(cx, cz)
	finale_cache_pos = _add_structure(StructureKind.FINALE_CACHE, "Emergency_HF_Cache", fin_best, 16.0, 0.2)


func _sample_site_pos(max_bound: float, min_dist: float, min_elev: float, max_elev: float, prefer_high: bool) -> Vector2:
	var best := Vector2(_rng.randf_range(-max_bound, max_bound), _rng.randf_range(-max_bound, max_bound))
	var best_score: float = -1e9
	var min_sq: float = min_dist * min_dist

	for _a in range(36):
		var px: float = _rng.randf_range(-max_bound, max_bound)
		var pz: float = _rng.randf_range(-max_bound, max_bound)
		var cand := Vector2(px, pz)
		var too_close: bool = false
		for s in structures:
			var sp := Vector2(s["pos"].x, s["pos"].z)
			if sp.distance_squared_to(cand) < min_sq:
				too_close = true
				break
		if too_close:
			continue
		var cf: Dictionary = eval_climate_fields(px, pz)
		var e: float = cf["elev_norm"]
		if e < min_elev or e > max_elev:
			continue
		var sc: float = e if prefer_high else (1.0 - absf(e - 0.35))
		if sc > best_score:
			best_score = sc
			best = cand
	return best


func _add_structure(
	kind: int,
	sname: String,
	xz: Vector2,
	pad_radius: float,
	y_bias: float,
	forced_biome: int = -1,
	tunnel_network: int = -1
) -> Vector3:
	var h: float = eval_macro_height(xz.x, xz.y) + y_bias
	var pos := Vector3(xz.x, h, xz.y)
	var site := {
		"id": structures.size(),
		"kind": kind,
		"name": sname,
		"pos": pos,
		"yaw": _rng.randf_range(0.0, TAU),
		"radius": pad_radius,
		"forced_biome": forced_biome,
		"tunnel_network": tunnel_network,
	}
	structures.append(site)
	_register_circle_in_buckets(site_buckets, xz, pad_radius * 1.85, site)
	return pos


func _route_networks() -> void:
	# Build coarse slope-penalized elevation cost map once (160x160 = 25,600 cells)
	var cell_size: float = WORLD_SIZE / float(ROUTER_GRID)
	var costs := PackedFloat32Array()
	costs.resize(ROUTER_GRID * ROUTER_GRID)
	for gz in range(ROUTER_GRID):
		var wz: float = -HALF_WORLD + (float(gz) + 0.5) * cell_size
		for gx in range(ROUTER_GRID):
			var wx: float = -HALF_WORLD + (float(gx) + 0.5) * cell_size
			var h: float = eval_macro_height(wx, wz)
			var hx: float = eval_macro_height(wx + 90.0, wz)
			var hz: float = eval_macro_height(wx, wz + 90.0)
			var slope: float = sqrt((hx - h) * (hx - h) + (hz - h) * (hz - h)) / 90.0
			var edge_pen: float = 0.0
			if maxf(absf(wx), absf(wz)) > 14200.0:
				edge_pen = 35.0
			costs[gz * ROUTER_GRID + gx] = 1.0 + slope * 18.0 + maxf(0.0, h - 135.0) * 0.04 + edge_pen

	var crash_2d := Vector2(crash_site_pos.x, crash_site_pos.z)
	var gates: Array[Vector2] = []
	var hubs: Array[Vector2] = []
	var relays: Array[Vector2] = []
	var safehouses: Array[Vector2] = []

	for s in structures:
		var p2 := Vector2(s["pos"].x, s["pos"].z)
		match int(s["kind"]):
			StructureKind.QUARANTINE_GATE: gates.append(p2)
			StructureKind.INDUSTRIAL_HUB: hubs.append(p2)
			StructureKind.RELAY_TOWER: relays.append(p2)
			StructureKind.SAFE_HOUSE: safehouses.append(p2)

	# 1. Highway backbone linking Crash Site <-> Nearest Gate <-> Hubs <-> Loop Gates (MST + closure)
	var highway_nodes: Array[Vector2] = [crash_2d]
	highway_nodes.append_array(hubs)
	highway_nodes.append_array(gates)
	for edge in _build_mst_edges(highway_nodes):
		_carve_route(highway_nodes[edge.x], highway_nodes[edge.y], RouteKind.HIGHWAY_PAVED, 4.2, costs, cell_size)

	# 2. Rusted Rail Spur linking the 4 Industrial Hubs + 1 outer gate exit
	if hubs.size() >= 2:
		var rail_nodes: Array[Vector2] = hubs.duplicate()
		if gates.size() > 0:
			rail_nodes.append(gates[0])
		for edge in _build_mst_edges(rail_nodes):
			_carve_route(rail_nodes[edge.x], rail_nodes[edge.y], RouteKind.RAIL_SPUR, 3.0, costs, cell_size)

	# 3. Dirt Logging Trails linking Relay Towers & 65% of SafeHouses to nearest Highway/Hub node
	for r_pos in relays:
		var nearest: Vector2 = _find_nearest_point(r_pos, highway_nodes)
		_carve_route(r_pos, nearest, RouteKind.LOG_TRAIL_DIRT, 2.4, costs, cell_size)
	for i in range(safehouses.size()):
		if i % 4 == 0:
			continue # Leave ~25% of cabins completely off-trail for pure compass navigation
		var nearest_sh: Vector2 = _find_nearest_point(safehouses[i], highway_nodes)
		_carve_route(safehouses[i], nearest_sh, RouteKind.LOG_TRAIL_DIRT, 2.1, costs, cell_size)

	# 4. Telemetry Power-Line Corridor linking Relay Towers + Crash Site corridor
	var pwr_nodes: Array[Vector2] = [crash_2d]
	pwr_nodes.append_array(relays)
	for edge in _build_mst_edges(pwr_nodes):
		_carve_direct_corridor(pwr_nodes[edge.x], pwr_nodes[edge.y], RouteKind.POWER_LINE, 5.5)


func _carve_route(a: Vector2, b: Vector2, kind: int, half_w: float, costs: PackedFloat32Array, cell_size: float) -> void:
	var path: Array[Vector2] = _astar_2d(a, b, costs, cell_size)
	if path.size() < 2:
		path = [a, b]
	# Chaikin smooth + organic forest wiggle (never grid-staircase)
	var smoothed: Array[Vector2] = _smooth_polyline(path, 2)
	routes.append({"kind": kind, "points": smoothed, "half_width": half_w})
	for i in range(smoothed.size() - 1):
		_register_segment_in_buckets(road_buckets, {
			"a": smoothed[i],
			"b": smoothed[i + 1],
			"half_width": half_w,
			"kind": kind,
		})


func _carve_direct_corridor(a: Vector2, b: Vector2, kind: int, half_w: float) -> void:
	var pts: Array[Vector2] = []
	var steps: int = maxi(2, int(ceil(a.distance_to(b) / 380.0)))
	var perp := Vector2(-(b.y - a.y), b.x - a.x).normalized()
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var p: Vector2 = a.lerp(b, t)
		if i > 0 and i < steps:
			p += perp * _rng.randf_range(-42.0, 42.0)
		pts.append(p)
	routes.append({"kind": kind, "points": pts, "half_width": half_w})
	for i in range(pts.size() - 1):
		_register_segment_in_buckets(road_buckets, {
			"a": pts[i],
			"b": pts[i + 1],
			"half_width": half_w,
			"kind": kind,
		})


func _detect_river_bridges() -> void:
	# Mark river-crossing bridge sites automatically where highways/rails/dirt roads intersect rivers
	var placed_bridges: Array[Vector2] = []
	for r in routes:
		var rkind: int = int(r["kind"])
		if rkind == RouteKind.POWER_LINE:
			continue
		var pts: Array = r["points"]
		for i in range(pts.size() - 1):
			var p0: Vector2 = pts[i]
			var p1: Vector2 = pts[i + 1]
			var cand_buckets: Array[Vector2i] = []
			for pt in [p0, (p0 + p1) * 0.5, p1]:
				var bk: Vector2i = get_bucket_key(pt.x, pt.y)
				if not cand_buckets.has(bk):
					cand_buckets.append(bk)
			for bk in cand_buckets:
				if not river_buckets.has(bk):
					continue
				for rseg in river_buckets[bk]:
					var ix = Geometry2D.segment_intersects_segment(p0, p1, rseg["a"], rseg["b"])
					if ix is Vector2:
						var skip: bool = false
						for pb in placed_bridges:
							if pb.distance_squared_to(ix) < 120.0 * 120.0:
								skip = true
								break
						if not skip:
							placed_bridges.append(ix)
							var st: Dictionary = {
								"id": structures.size(),
								"kind": StructureKind.BRIDGE,
								"name": "RiverBridge_%d" % placed_bridges.size(),
								"pos": Vector3(ix.x, eval_macro_height(ix.x, ix.y), ix.y),
								"yaw": atan2(p1.x - p0.x, p1.y - p0.y),
								"radius": 14.0,
								"route_kind": rkind,
							}
							structures.append(st)
							_register_circle_in_buckets(site_buckets, ix, 24.0, st)


func _smooth_polyline(pts: Array[Vector2], iterations: int) -> Array[Vector2]:
	var cur: Array[Vector2] = pts.duplicate()
	for _it in range(iterations):
		if cur.size() < 3:
			break
		var next: Array[Vector2] = [cur[0]]
		for i in range(cur.size() - 1):
			next.append(cur[i].lerp(cur[i + 1], 0.25))
			next.append(cur[i].lerp(cur[i + 1], 0.75))
		next.append(cur[cur.size() - 1])
		cur = next
	return cur


func _astar_2d(a: Vector2, b: Vector2, costs: PackedFloat32Array, cell_size: float) -> Array[Vector2]:
	var sx: int = clampi(int((a.x + HALF_WORLD) / cell_size), 0, ROUTER_GRID - 1)
	var sz: int = clampi(int((a.y + HALF_WORLD) / cell_size), 0, ROUTER_GRID - 1)
	var gx: int = clampi(int((b.x + HALF_WORLD) / cell_size), 0, ROUTER_GRID - 1)
	var gz: int = clampi(int((b.y + HALF_WORLD) / cell_size), 0, ROUTER_GRID - 1)

	var start_idx: int = sz * ROUTER_GRID + sx
	var goal_idx: int = gz * ROUTER_GRID + gx
	if start_idx == goal_idx:
		return [a, b]

	var total_cells: int = ROUTER_GRID * ROUTER_GRID
	if _astar_stamp.size() != total_cells:
		_astar_g.resize(total_cells)
		_astar_came.resize(total_cells)
		_astar_stamp.resize(total_cells)
	_astar_cur_stamp += 1
	var seen_stamp: int = _astar_cur_stamp * 2 - 1
	var closed_stamp: int = _astar_cur_stamp * 2

	var heap_nodes := PackedInt32Array()
	var heap_f := PackedFloat32Array()
	_astar_g[start_idx] = 0.0
	_astar_came[start_idx] = -1
	_astar_stamp[start_idx] = seen_stamp
	_heap_push(heap_nodes, heap_f, start_idx, float(absi(gx - sx) + absi(gz - sz)))

	const DIRS: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1),
	]

	var found: bool = false
	while heap_nodes.size() > 0:
		var cur: int = _heap_pop(heap_nodes, heap_f)
		if cur == goal_idx:
			found = true
			break
		if _astar_stamp[cur] == closed_stamp:
			continue
		_astar_stamp[cur] = closed_stamp

		var cx: int = cur % ROUTER_GRID
		var cz: int = cur / ROUTER_GRID
		for d in DIRS:
			var nx: int = cx + d.x
			var nz: int = cz + d.y
			if nx < 0 or nx >= ROUTER_GRID or nz < 0 or nz >= ROUTER_GRID:
				continue
			var nidx: int = nz * ROUTER_GRID + nx
			if _astar_stamp[nidx] == closed_stamp:
				continue
			var step_mult: float = 1.4142 if (d.x != 0 and d.y != 0) else 1.0
			var tent_g: float = _astar_g[cur] + step_mult * costs[nidx]
			if _astar_stamp[nidx] < seen_stamp or tent_g < _astar_g[nidx]:
				_astar_g[nidx] = tent_g
				_astar_came[nidx] = cur
				_astar_stamp[nidx] = seen_stamp
				var h_est: float = sqrt(float((gx - nx) * (gx - nx) + (gz - nz) * (gz - nz)))
				_heap_push(heap_nodes, heap_f, nidx, tent_g + h_est)

	if not found:
		return [a, b]

	var rev: Array[Vector2] = [b]
	var trace: int = _astar_came[goal_idx]
	while trace != -1 and trace != start_idx:
		var tx: int = trace % ROUTER_GRID
		var tz: int = trace / ROUTER_GRID
		var wx: float = -HALF_WORLD + (float(tx) + 0.5) * cell_size
		var wz: float = -HALF_WORLD + (float(tz) + 0.5) * cell_size
		rev.append(Vector2(wx, wz))
		trace = _astar_came[trace]
	rev.append(a)
	rev.reverse()
	return rev


func _heap_push(nodes: PackedInt32Array, fvals: PackedFloat32Array, node: int, fval: float) -> void:
	nodes.append(node)
	fvals.append(fval)
	var i: int = nodes.size() - 1
	while i > 0:
		var p: int = (i - 1) >> 1
		if fvals[i] < fvals[p]:
			var tn: int = nodes[p]; nodes[p] = nodes[i]; nodes[i] = tn
			var tf: float = fvals[p]; fvals[p] = fvals[i]; fvals[i] = tf
			i = p
		else:
			break


func _heap_pop(nodes: PackedInt32Array, fvals: PackedFloat32Array) -> int:
	var top: int = nodes[0]
	var last_i: int = nodes.size() - 1
	nodes[0] = nodes[last_i]
	fvals[0] = fvals[last_i]
	nodes.resize(last_i)
	fvals.resize(last_i)
	var n: int = nodes.size()
	var i: int = 0
	while true:
		var smallest: int = i
		var l: int = i * 2 + 1
		var r: int = l + 1
		if l < n and fvals[l] < fvals[smallest]:
			smallest = l
		if r < n and fvals[r] < fvals[smallest]:
			smallest = r
		if smallest != i:
			var tn: int = nodes[smallest]; nodes[smallest] = nodes[i]; nodes[i] = tn
			var tf: float = fvals[smallest]; fvals[smallest] = fvals[i]; fvals[i] = tf
			i = smallest
		else:
			break
	return top


func _build_mst_edges(pts: Array[Vector2]) -> Array[Vector2i]:
	var edges: Array[Vector2i] = []
	if pts.size() < 2:
		return edges
	var in_tree: PackedByteArray = PackedByteArray()
	in_tree.resize(pts.size())
	in_tree[0] = 1
	for _step in range(pts.size() - 1):
		var best_u: int = -1
		var best_v: int = -1
		var best_d2: float = 1e20
		for u in range(pts.size()):
			if in_tree[u] == 0:
				continue
			for v in range(pts.size()):
				if in_tree[v] != 0:
					continue
				var d2: float = pts[u].distance_squared_to(pts[v])
				if d2 < best_d2:
					best_d2 = d2
					best_u = u
					best_v = v
		if best_v != -1:
			in_tree[best_v] = 1
			edges.append(Vector2i(best_u, best_v))
	return edges


func _find_nearest_point(p: Vector2, candidates: Array[Vector2]) -> Vector2:
	var best: Vector2 = candidates[0]
	var best_d2: float = p.distance_squared_to(best)
	for c in candidates:
		var d2: float = p.distance_squared_to(c)
		if d2 < best_d2:
			best_d2 = d2
			best = c
	return best


func _register_circle_in_buckets(buckets: Dictionary, center: Vector2, reach: float, item: Dictionary) -> void:
	var min_bx: int = int(floor((center.x - reach) / BUCKET_SIZE))
	var max_bx: int = int(floor((center.x + reach) / BUCKET_SIZE))
	var min_bz: int = int(floor((center.y - reach) / BUCKET_SIZE))
	var max_bz: int = int(floor((center.y + reach) / BUCKET_SIZE))
	for bz in range(min_bz, max_bz + 1):
		for bx in range(min_bx, max_bx + 1):
			var k := Vector2i(bx, bz)
			if not buckets.has(k):
				buckets[k] = [item]
			else:
				buckets[k].append(item)


func _register_segment_in_buckets(buckets: Dictionary, seg: Dictionary) -> void:
	var a: Vector2 = seg["a"]
	var b: Vector2 = seg["b"]
	var pad: float = float(seg.get("half_width", 4.0)) + 24.0
	var min_bx: int = int(floor((minf(a.x, b.x) - pad) / BUCKET_SIZE))
	var max_bx: int = int(floor((maxf(a.x, b.x) + pad) / BUCKET_SIZE))
	var min_bz: int = int(floor((minf(a.y, b.y) - pad) / BUCKET_SIZE))
	var max_bz: int = int(floor((maxf(a.y, b.y) + pad) / BUCKET_SIZE))
	for bz in range(min_bz, max_bz + 1):
		for bx in range(min_bx, max_bx + 1):
			var k := Vector2i(bx, bz)
			if not buckets.has(k):
				buckets[k] = [seg]
			else:
				buckets[k].append(seg)
