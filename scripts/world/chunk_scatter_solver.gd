class_name ChunkScatterSolver
extends RefCounted

const CHUNK_SIZE: float = WorldBlueprint.CHUNK_SIZE

## Fast deterministic chunk hash -> integer seed
static func _chunk_seed(world_seed: int, cx: int, cz: int, salt: int) -> int:
	var h: int = world_seed ^ (cx * 73856093) ^ (cz * 19349663) ^ (salt * 83492791)
	return absi(h)


## Solves all biome foliage, boulders, undergrowth, trunk colliders, rails & power poles
## entirely on WorkerThreadPool using already-computed grid height/biome/corridor samples.
static func solve_chunk_props(
	blueprint: WorldBlueprint,
	cx: int,
	cz: int,
	lod: int,
	grid: int,
	heights: PackedFloat32Array,
	normals: PackedVector3Array,
	biome_ids: PackedInt32Array,
	road_dists: PackedFloat32Array,
	road_kinds: PackedInt32Array,
	road_hws: PackedFloat32Array,
	power_dists: PackedFloat32Array,
	riv_dists: PackedFloat32Array,
	riv_hws: PackedFloat32Array,
	site_weights: PackedFloat32Array,
	road_slices: Array,
	variant_counts: Dictionary
) -> Dictionary:
	if lod >= 2:
		return {"multimeshes": [], "trunk_colliders": PackedVector4Array(), "boulder_colliders": PackedVector4Array(), "total_instances": 0}

	var stride: int = grid + 1
	var step: float = CHUNK_SIZE / float(grid)
	var x0: float = float(cx) * CHUNK_SIZE
	var z0: float = float(cz) * CHUNK_SIZE
	var rng := RandomNumberGenerator.new()

	# bucket_key -> Array of arrays (1 transform list per mesh variant)
	var mm_data: Dictionary = {}
	var _init_bucket := func(bkey: String) -> void:
		if mm_data.has(bkey):
			return
		var vc: int = int(variant_counts.get(bkey, 0))
		var arr: Array = []
		for _i in range(vc):
			arr.append([] as Array[Transform3D])
		mm_data[bkey] = arr

	var trunk_colliders := PackedVector4Array()
	var boulder_colliders := PackedVector4Array()
	var total_instances: int = 0

	# 1. Trees & Deadwood Snags (LOD 0 & LOD 1 -> forested skylines out to ~450m)
	rng.seed = _chunk_seed(blueprint.world_seed, cx, cz, 101)
	const TREE_GRID: int = 21 # ~6.1m cells -> up to 441 slots per 128m chunk
	var tree_cell: float = CHUNK_SIZE / float(TREE_GRID)
	for gz in range(TREE_GRID):
		for gx in range(TREE_GRID):
			var lx: float = (float(gx) + rng.randf_range(0.16, 0.84)) * tree_cell
			var lz: float = (float(gz) + rng.randf_range(0.16, 0.84)) * tree_cell
			var gi: int = _grid_index(lx, lz, grid, stride, step)
			var site_w: float = site_weights[gi]
			if site_w > 0.55:
				continue
			var rkind: int = road_kinds[gi]
			var rdist: float = road_dists[gi]
			if rkind >= 0 and rdist < road_hws[gi] + 2.5:
				continue
			if power_dists[gi] < 6.8:
				continue
			if riv_dists[gi] < riv_hws[gi] + 1.8:
				continue
			var nrm: Vector3 = normals[gi]
			if nrm.y < 0.68:
				continue

			var bid: int = biome_ids[gi]
			var spec: Dictionary = BiomeRegistry.get_spec(bid)
			var density: float = float(spec["tree_density"])
			if rng.randf() > density * 0.88:
				continue

			var species: String = _pick_tree_species(bid, rng)
			_init_bucket.call(species)
			var variants: Array = mm_data[species]
			if variants.is_empty():
				continue
			var v_idx: int = rng.randi_range(0, variants.size() - 1)

			var y: float = _sample_height_bilinear(lx, lz, grid, stride, step, heights)
			var sc: float = rng.randf_range(1.25, 2.35)
			if species == "pine":
				sc *= rng.randf_range(1.05, 1.32)
			elif species == "quiver":
				sc = rng.randf_range(0.85, 1.55)
			var max_lean: float = 0.085 if (species == "dead" or species == "dead_char" or species == "dead_pale") else 0.045
			var yaw: float = rng.randf_range(0.0, TAU)
			var basis := Basis.from_euler(Vector3(rng.randf_range(-max_lean, max_lean), yaw, rng.randf_range(-max_lean, max_lean))).scaled(Vector3.ONE * sc)
			var xform := Transform3D(basis, Vector3(lx, y - 0.16, lz))
			variants[v_idx].append(xform)
			total_instances += 1

			if lod == 0 and sc >= 0.90:
				trunk_colliders.append(Vector4(lx, y, lz, sc))

	# 2. Boulders & Outcrop Rocks (LOD 0 & LOD 1)
	rng.seed = _chunk_seed(blueprint.world_seed, cx, cz, 203)
	const ROCK_GRID: int = 8
	var rock_cell: float = CHUNK_SIZE / float(ROCK_GRID)
	for gz in range(ROCK_GRID):
		for gx in range(ROCK_GRID):
			var lx: float = (float(gx) + rng.randf_range(0.15, 0.85)) * rock_cell
			var lz: float = (float(gz) + rng.randf_range(0.15, 0.85)) * rock_cell
			var gi: int = _grid_index(lx, lz, grid, stride, step)
			if site_weights[gi] > 0.65:
				continue
			if road_kinds[gi] >= 0 and road_dists[gi] < road_hws[gi] + 1.8:
				continue

			var bid: int = biome_ids[gi]
			var nrm: Vector3 = normals[gi]
			var rock_prob: float = 0.24
			if bid == BiomeRegistry.Id.GRANITE_ESCARPMENT or bid == BiomeRegistry.Id.QUARRY_CUT:
				rock_prob = 0.72
			elif riv_dists[gi] < riv_hws[gi] + 7.5:
				rock_prob = 0.56
			elif nrm.y < 0.85:
				rock_prob = 0.52
			if rng.randf() > rock_prob:
				continue

			var bkey: String = "boulder" if rng.randf() < 0.34 else "rock_set"
			_init_bucket.call(bkey)
			var variants: Array = mm_data[bkey]
			if variants.is_empty():
				continue
			var v_idx: int = rng.randi_range(0, variants.size() - 1)
			var y: float = _sample_height_bilinear(lx, lz, grid, stride, step, heights)
			var sc: float = rng.randf_range(0.85, 2.20) if bkey == "boulder" else rng.randf_range(0.75, 1.75)
			var basis := _slope_aligned_basis(nrm, rng.randf_range(0.0, TAU), 0.16, 0.45, sc)
			var sink: float = -0.22 if bkey == "boulder" else -0.18
			variants[v_idx].append(Transform3D(basis, Vector3(lx, y + sink, lz)))
			total_instances += 1
			if lod == 0 and bkey == "boulder" and sc >= 1.30:
				boulder_colliders.append(Vector4(lx, y, lz, sc))

	# 3. Corridors (Rail sleepers + rails, Highway posts, Utility poles & cables) for LOD 0 & LOD 1
	total_instances += _build_corridor_instances(x0, z0, grid, stride, step, heights, normals, site_weights, riv_dists, riv_hws, road_slices, mm_data, _init_bucket, variant_counts)

	# 4. Fine Undergrowth, Fallen Logs, Stumps, Ferns, Grass & Pebbles ONLY on LOD 0 near player
	if lod == 0:
		# 4a. Logs, Stumps & Windfall Clutter (12x12 grid)
		rng.seed = _chunk_seed(blueprint.world_seed, cx, cz, 307)
		const WOOD_GRID: int = 12
		var wood_cell: float = CHUNK_SIZE / float(WOOD_GRID)
		for gz in range(WOOD_GRID):
			for gx in range(WOOD_GRID):
				var lx: float = (float(gx) + rng.randf_range(0.14, 0.86)) * wood_cell
				var lz: float = (float(gz) + rng.randf_range(0.14, 0.86)) * wood_cell
				var gi: int = _grid_index(lx, lz, grid, stride, step)
				if site_weights[gi] > 0.68:
					continue
				if road_kinds[gi] >= 0 and road_dists[gi] < road_hws[gi] + 1.5:
					continue
				var bid: int = biome_ids[gi]
				var spec: Dictionary = BiomeRegistry.get_spec(bid)
				var dw: float = float(spec["deadwood"])
				var accept_p: float = clampf(0.18 + dw * 0.55, 0.14, 0.72)
				if rng.randf() > accept_p:
					continue

				var rpick: float = rng.randf()
				var bkey: String = "log" if rpick < 0.34 else ("stump" if rpick < 0.62 else "branch")
				_init_bucket.call(bkey)
				var variants: Array = mm_data[bkey]
				if variants.is_empty():
					continue
				var v_idx: int = rng.randi_range(0, variants.size() - 1)
				var y: float = _sample_height_bilinear(lx, lz, grid, stride, step, heights)
				var sc: float = rng.randf_range(0.85, 1.65)
				var basis := _slope_aligned_basis(normals[gi], rng.randf_range(0.0, TAU), 0.14, 0.65, sc)
				variants[v_idx].append(Transform3D(basis, Vector3(lx, y - 0.06, lz)))
				total_instances += 1

		# 4b. Dense Bushes & Shrubs (16x16 grid)
		rng.seed = _chunk_seed(blueprint.world_seed, cx, cz, 409)
		const BUSH_GRID: int = 16
		var bush_cell: float = CHUNK_SIZE / float(BUSH_GRID)
		for gz in range(BUSH_GRID):
			for gx in range(BUSH_GRID):
				var lx: float = (float(gx) + rng.randf_range(0.12, 0.88)) * bush_cell
				var lz: float = (float(gz) + rng.randf_range(0.12, 0.88)) * bush_cell
				var gi: int = _grid_index(lx, lz, grid, stride, step)
				if site_weights[gi] > 0.70 or riv_dists[gi] < riv_hws[gi] + 1.4:
					continue
				if road_kinds[gi] >= 0 and road_dists[gi] < road_hws[gi] + 1.4:
					continue
				var bid: int = biome_ids[gi]
				var spec: Dictionary = BiomeRegistry.get_spec(bid)
				var ug: float = float(spec["undergrowth"])
				if rng.randf() > ug * 0.78:
					continue

				var bkey: String = "bush" if rng.randf() < 0.45 else "low_shrub"
				_init_bucket.call(bkey)
				var variants: Array = mm_data[bkey]
				if variants.is_empty():
					continue
				var v_idx: int = rng.randi_range(0, variants.size() - 1)
				var y: float = _sample_height_bilinear(lx, lz, grid, stride, step, heights)
				var sc: float = rng.randf_range(0.70, 1.40)
				var basis := _slope_aligned_basis(normals[gi], rng.randf_range(0.0, TAU), 0.10, 0.45, sc)
				variants[v_idx].append(Transform3D(basis, Vector3(lx, y - 0.04, lz)))
				total_instances += 1

		# 4c. Woodland Ferns, Grass Tufts, Moss & Gravel Pebbles (26x26 = 676 slots/chunk)
		rng.seed = _chunk_seed(blueprint.world_seed, cx, cz, 521)
		const GRASS_GRID: int = 26
		var grass_cell: float = CHUNK_SIZE / float(GRASS_GRID)
		for gz in range(GRASS_GRID):
			for gx in range(GRASS_GRID):
				var lx: float = (float(gx) + rng.randf_range(0.08, 0.92)) * grass_cell
				var lz: float = (float(gz) + rng.randf_range(0.08, 0.92)) * grass_cell
				var gi: int = _grid_index(lx, lz, grid, stride, step)
				if site_weights[gi] > 0.78:
					continue
				var rkind: int = road_kinds[gi]
				var rdist: float = road_dists[gi]
				var on_road_shoulder: bool = (rkind >= 0 and rdist < road_hws[gi] + 0.6)
				if on_road_shoulder:
					# Pebbles on roadbeds & quarry aprons instead of grass
					if rng.randf() < 0.35:
						_init_bucket.call("pebble")
						var pv: Array = mm_data["pebble"]
						if not pv.is_empty():
							var y_p: float = _sample_height_bilinear(lx, lz, grid, stride, step, heights)
							var sc_p: float = rng.randf_range(0.85, 1.95)
							pv[rng.randi_range(0, pv.size() - 1)].append(Transform3D(_slope_aligned_basis(normals[gi], rng.randf_range(0.0, TAU), 0.12, 0.7, sc_p), Vector3(lx, y_p - 0.02, lz)))
							total_instances += 1
					continue

				if riv_dists[gi] < riv_hws[gi] + 0.8:
					continue

				var bid: int = biome_ids[gi]
				var spec: Dictionary = BiomeRegistry.get_spec(bid)
				var ug: float = float(spec["undergrowth"])
				if rng.randf() > maxf(0.14, ug * 0.92):
					continue

				var bkey: String = "grass"
				if ug < 0.25:
					bkey = "pebble" if rng.randf() < 0.7 else "branch"
				else:
					var groll: float = rng.randf()
					if groll < 0.36:
						bkey = "fern"
					elif groll < 0.84:
						bkey = "grass"
					else:
						bkey = "moss"

				_init_bucket.call(bkey)
				var variants: Array = mm_data[bkey]
				if variants.is_empty():
					continue
				var v_idx: int = rng.randi_range(0, variants.size() - 1)
				var y: float = _sample_height_bilinear(lx, lz, grid, stride, step, heights)
				var sc: float = rng.randf_range(1.15, 2.25)
				if bkey == "moss":
					sc = rng.randf_range(4.5, 9.5)
				elif bkey == "fern":
					sc = rng.randf_range(0.95, 1.95)
				var basis := _slope_aligned_basis(normals[gi], rng.randf_range(0.0, TAU), 0.12, 0.65, sc)
				variants[v_idx].append(Transform3D(basis, Vector3(lx, y - 0.02, lz)))
				total_instances += 1

	var batches: Array[Dictionary] = []
	for bkey in mm_data.keys():
		var var_lists: Array = mm_data[bkey]
		for v_i in range(var_lists.size()):
			var xforms: Array = var_lists[v_i]
			if xforms.is_empty():
				continue
			var cast_shadows: bool = bkey in ["pine", "normal", "birch", "dead", "dead_char", "dead_pale", "quiver", "boulder", "log", "pole_shaft", "pole_arm"]
			var vis_end: float = 0.0
			if bkey in ["fern", "grass", "moss", "pebble", "branch"]:
				vis_end = 74.0
			elif bkey in ["bush", "low_shrub"]:
				vis_end = 105.0
			elif bkey in ["boulder", "rock_set", "stump", "log", "rail_tie", "rail_bar", "guardrail_post"]:
				vis_end = 180.0
			else:
				vis_end = 440.0
			batches.append({
				"bucket": bkey,
				"variant_idx": v_i,
				"transforms": xforms,
				"cast_shadows": cast_shadows,
				"vis_end": vis_end,
			})

	return {
		"multimeshes": batches,
		"trunk_colliders": trunk_colliders,
		"boulder_colliders": boulder_colliders,
		"total_instances": total_instances,
	}


static func _build_corridor_instances(
	x0: float,
	z0: float,
	grid: int,
	stride: int,
	step: float,
	heights: PackedFloat32Array,
	normals: PackedVector3Array,
	site_weights: PackedFloat32Array,
	riv_dists: PackedFloat32Array,
	riv_hws: PackedFloat32Array,
	road_slices: Array,
	mm_data: Dictionary,
	init_fn: Callable,
	_variant_counts: Dictionary
) -> int:
	var added: int = 0
	var placed_poles: Array[Vector2] = []

	for seg in road_slices:
		var a: Vector2 = seg["a"]
		var b: Vector2 = seg["b"]
		var seg_vec: Vector2 = b - a
		var seg_len: float = seg_vec.length()
		if seg_len < 0.5:
			continue
		var dir2: Vector2 = seg_vec / seg_len
		var perp2 := Vector2(-dir2.y, dir2.x)
		var yaw: float = atan2(dir2.x, dir2.y)
		var kind: int = int(seg["kind"])

		var step_m: float = 36.0
		if kind == WorldBlueprint.RouteKind.RAIL_SPUR:
			step_m = 1.45
		elif kind == WorldBlueprint.RouteKind.HIGHWAY_PAVED:
			step_m = 18.0
		elif kind == WorldBlueprint.RouteKind.POWER_LINE:
			step_m = 42.0
		else:
			continue

		var count: int = maxi(1, int(floor(seg_len / step_m)))
		for s_i in range(count + 1):
			var dist_along: float = minf(seg_len, float(s_i) * step_m)
			var p: Vector2 = a + dir2 * dist_along
			var lx: float = p.x - x0
			var lz: float = p.y - z0
			if lx < 0.0 or lx >= CHUNK_SIZE or lz < 0.0 or lz >= CHUNK_SIZE:
				continue

			var gi: int = _grid_index(lx, lz, grid, stride, step)
			# Avoid colliding into bridge water decks or structure clearing interiors
			if riv_dists[gi] < riv_hws[gi] + 5.5:
				continue
			if site_weights[gi] > 0.58:
				continue

			var y: float = _sample_height_bilinear(lx, lz, grid, stride, step, heights)
			if kind == WorldBlueprint.RouteKind.RAIL_SPUR:
				init_fn.call("rail_tie")
				var fwd3 := Vector3(dir2.x, 0.0, dir2.y)
				var up3: Vector3 = Vector3.UP.lerp(normals[gi], 0.65).normalized()
				var right3: Vector3 = up3.cross(fwd3).normalized()
				fwd3 = right3.cross(up3).normalized()
				var b_tie := Basis(right3, up3, fwd3)
				mm_data["rail_tie"][0].append(Transform3D(b_tie, Vector3(lx, y + 0.03, lz)))
				added += 1

				if s_i % 3 == 0:
					init_fn.call("rail_bar")
					mm_data["rail_bar"][0].append(Transform3D(b_tie, Vector3(lx, y + 0.14, lz) - right3 * 0.72))
					mm_data["rail_bar"][0].append(Transform3D(b_tie, Vector3(lx, y + 0.14, lz) + right3 * 0.72))
					added += 2

			elif kind == WorldBlueprint.RouteKind.HIGHWAY_PAVED:
				if normals[gi].y < 0.94:
					init_fn.call("guardrail_post")
					for side in [-1.0, 1.0]:
						var gp: Vector2 = p + perp2 * (side * (float(seg["half_width"]) + 0.65))
						var glx: float = gp.x - x0
						var glz: float = gp.y - z0
						if glx >= 0.0 and glx < CHUNK_SIZE and glz >= 0.0 and glz < CHUNK_SIZE:
							var gy: float = _sample_height_bilinear(glx, glz, grid, stride, step, heights)
							mm_data["guardrail_post"][0].append(Transform3D(Basis(Vector3.UP, yaw), Vector3(glx, gy + 0.42, glz)))
							added += 1

			elif kind == WorldBlueprint.RouteKind.POWER_LINE:
				var p_vec := Vector2(lx, lz)
				var too_near: bool = false
				for ep in placed_poles:
					if ep.distance_squared_to(p_vec) < 28.0 * 28.0:
						too_near = true
						break
				if too_near:
					continue
				placed_poles.append(p_vec)
				init_fn.call("pole_shaft")
				var pole_vars: Array = mm_data["pole_shaft"]
				var pv_idx: int = 1 if (pole_vars.size() > 1 and (s_i % 4 == 0)) else 0
				var b_pole := Basis(Vector3.UP, yaw)
				pole_vars[pv_idx].append(Transform3D(b_pole, Vector3(lx, y, lz)))
				added += 1

	return added


static func _pick_tree_species(biome_id: int, rng: RandomNumberGenerator) -> String:
	var r: float = rng.randf()
	match biome_id:
		BiomeRegistry.Id.BURN_SCAR:
			if r < 0.76: return "dead_char"
			if r < 0.92: return "quiver"
			return "dead"
		BiomeRegistry.Id.PALE_BONEWOOD:
			if r < 0.78: return "dead_pale"
			if r < 0.90: return "dead"
			return "birch"
		BiomeRegistry.Id.MYCORRHIZAL_SINKHOLE, BiomeRegistry.Id.SULFUR_RAVINE:
			if r < 0.46: return "quiver"
			if r < 0.80: return "dead"
			return "dead_pale"
		BiomeRegistry.Id.ALDER_SLOUGH, BiomeRegistry.Id.CULVERT_DRAIN:
			if r < 0.42: return "normal"
			if r < 0.72: return "quiver"
			if r < 0.88: return "dead"
			return "birch"
		BiomeRegistry.Id.WINDFALL_SADDLE:
			if r < 0.40: return "pine"
			if r < 0.82: return "dead"
			return "normal"
		BiomeRegistry.Id.GRANITE_ESCARPMENT, BiomeRegistry.Id.SUBALPINE_CREST, BiomeRegistry.Id.LOOKOUT_RIDGE:
			if r < 0.62: return "pine"
			if r < 0.82: return "birch"
			return "dead"
		BiomeRegistry.Id.GREEN_ISLAND:
			if r < 0.78: return "pine"
			if r < 0.92: return "birch"
			return "normal"
		_:
			if r < 0.72: return "pine"
			if r < 0.86: return "normal"
			if r < 0.93: return "birch"
			return "dead"


static func _grid_index(lx: float, lz: float, grid: int, stride: int, step: float) -> int:
	var gx: int = clampi(int(round(lx / step)), 0, grid)
	var gz: int = clampi(int(round(lz / step)), 0, grid)
	return gz * stride + gx


static func _sample_height_bilinear(lx: float, lz: float, grid: int, stride: int, step: float, heights: PackedFloat32Array) -> float:
	var fx: float = clampf(lx / step, 0.0, float(grid) - 0.001)
	var fz: float = clampf(lz / step, 0.0, float(grid) - 0.001)
	var gx: int = int(floor(fx))
	var gz: int = int(floor(fz))
	var tx: float = fx - float(gx)
	var tz: float = fz - float(gz)
	var i0: int = gz * stride + gx
	var h00: float = heights[i0]
	var h10: float = heights[i0 + 1]
	var h01: float = heights[i0 + stride]
	var h11: float = heights[i0 + stride + 1]
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), tz)


static func _slope_aligned_basis(nrm: Vector3, yaw: float, max_tilt: float, align_weight: float, sc: float) -> Basis:
	var up_dir: Vector3 = Vector3.UP.lerp(nrm, align_weight).normalized()
	var fwd := Vector3(sin(yaw), 0.0, cos(yaw))
	var right: Vector3 = up_dir.cross(fwd).normalized()
	fwd = right.cross(up_dir).normalized()
	return Basis(right, up_dir, fwd).rotated(Vector3.RIGHT, max_tilt * 0.25).scaled(Vector3.ONE * sc)
