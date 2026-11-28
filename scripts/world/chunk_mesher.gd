class_name ChunkMesher
extends RefCounted

const CHUNK_SIZE: float = WorldBlueprint.CHUNK_SIZE
const SKIRT_DEPTH: float = 3.5
const UV_TILE_METERS: float = 8.0 # 16 exact repeats per 128m chunk

const LOD_GRIDS: Array[int] = [64, 32, 16] # LOD 0: 2m, LOD 1: 4m, LOD 2: 8m


static func get_grid_for_lod(lod: int) -> int:
	return LOD_GRIDS[clampi(lod, 0, LOD_GRIDS.size() - 1)]


static func build_chunk_data(
	sampler: TerrainSampler,
	cx: int,
	cz: int,
	lod: int,
	build_collision: bool,
	variant_counts: Dictionary = {}
) -> Dictionary:
	var t0: int = Time.get_ticks_msec()
	var grid: int = get_grid_for_lod(lod)
	var stride: int = grid + 1
	var step: float = CHUNK_SIZE / float(grid)

	var x0: float = float(cx) * CHUNK_SIZE
	var z0: float = float(cz) * CHUNK_SIZE
	var slices: Dictionary = sampler.collect_chunk_slices(x0 - 4.0, x0 + CHUNK_SIZE + 4.0, z0 - 4.0, z0 + CHUNK_SIZE + 4.0)

	var v_count: int = stride * stride
	var heights := PackedFloat32Array()
	var biome_ids := PackedInt32Array()
	var road_dists := PackedFloat32Array()
	var road_kinds := PackedInt32Array()
	var road_hws := PackedFloat32Array()
	var power_dists := PackedFloat32Array()
	var riv_dists := PackedFloat32Array()
	var riv_hws := PackedFloat32Array()
	var riv_wys := PackedFloat32Array()
	var site_weights := PackedFloat32Array()

	heights.resize(v_count)
	biome_ids.resize(v_count)
	road_dists.resize(v_count)
	road_kinds.resize(v_count)
	road_hws.resize(v_count)
	power_dists.resize(v_count)
	riv_dists.resize(v_count)
	riv_hws.resize(v_count)
	riv_wys.resize(v_count)
	site_weights.resize(v_count)

	var min_y: float = 1e6
	var max_y: float = -1e6
	var has_road: bool = false
	var has_river: bool = false
	var biome_counts: Dictionary = {}

	for gz in range(stride):
		var lz: float = float(gz) * step
		var wz: float = z0 + lz
		for gx in range(stride):
			var lx: float = float(gx) * step
			var wx: float = x0 + lx
			var idx: int = gz * stride + gx
			var sp: Dictionary = sampler.sample_point_sliced(wx, wz, slices)
			var h: float = float(sp["height"])
			var bid: int = int(sp["biome_id"])
			var rd: float = float(sp["road_dist"])
			var rk: int = int(sp["road_kind"])
			var rhw: float = float(sp["road_hw"])
			var vd: float = float(sp["river_dist"])
			var vhw: float = float(sp["river_half_width"])

			heights[idx] = h
			biome_ids[idx] = bid
			road_dists[idx] = rd
			road_kinds[idx] = rk
			road_hws[idx] = rhw
			power_dists[idx] = float(sp["power_dist"])
			riv_dists[idx] = vd
			riv_hws[idx] = vhw
			riv_wys[idx] = float(sp["river_water_y"])
			site_weights[idx] = float(sp["site_weight"])

			if h < min_y:
				min_y = h
			if h > max_y:
				max_y = h
			biome_counts[bid] = biome_counts.get(bid, 0) + 1
			if rk >= 0 and rd < rhw + 3.0:
				has_road = true
			if vd < vhw + 4.0:
				has_river = true

	var dominant_biome: int = 0
	var dominant_hits: int = -1
	for b_key in biome_counts:
		if int(biome_counts[b_key]) > dominant_hits:
			dominant_hits = int(biome_counts[b_key])
			dominant_biome = int(b_key)

	# Compute normals + splats
	var skirt_verts: int = stride * 4
	var total_verts: int = v_count + skirt_verts
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var colors := PackedColorArray()
	var custom0 := PackedFloat32Array()

	verts.resize(total_verts)
	normals.resize(total_verts)
	uvs.resize(total_verts)
	uv2s.resize(total_verts)
	colors.resize(total_verts)
	custom0.resize(total_verts * 4)

	var two_step: float = 2.0 * step
	for gz in range(stride):
		var lz: float = float(gz) * step
		var wz: float = z0 + lz
		var v_coord: float = lz / UV_TILE_METERS
		for gx in range(stride):
			var lx: float = float(gx) * step
			var wx: float = x0 + lx
			var u_coord: float = lx / UV_TILE_METERS
			var idx: int = gz * stride + gx
			var h: float = heights[idx]
			verts[idx] = Vector3(lx, h, lz)
			uvs[idx] = Vector2(u_coord, v_coord)

			var nrm: Vector3
			if gx == 0 or gx == grid or gz == 0 or gz == grid:
				nrm = sampler.get_normal_sliced(wx, wz, slices, 2.0)
			else:
				var hl: float = heights[idx - 1]
				var hr: float = heights[idx + 1]
				var hd: float = heights[idx - stride]
				var hu: float = heights[idx + stride]
				nrm = Vector3(hl - hr, two_step, hd - hu).normalized()
			normals[idx] = nrm

			var splat: Array = _compute_surface_splat(
				biome_ids[idx], nrm.y, road_dists[idx], road_kinds[idx], road_hws[idx], riv_dists[idx], riv_hws[idx], site_weights[idx]
			)
			colors[idx] = splat[0]
			uv2s[idx] = splat[1]
			var ex: Vector2 = splat[2]
			var c_off: int = idx * 4
			custom0[c_off] = ex.x
			custom0[c_off + 1] = ex.y
			custom0[c_off + 2] = 0.0
			custom0[c_off + 3] = 0.0

	# Surface triangles + optional physics faces
	var quad_count: int = grid * grid
	var surf_idx_count: int = quad_count * 6
	var skirt_idx_count: int = grid * 4 * 6
	var indices := PackedInt32Array()
	indices.resize(surf_idx_count + skirt_idx_count)

	var col_faces := PackedVector3Array()
	if build_collision:
		col_faces.resize(surf_idx_count)

	var k: int = 0
	for gz in range(grid):
		for gx in range(grid):
			var i0: int = gz * stride + gx
			var i1: int = i0 + 1
			var i2: int = i0 + stride
			var i3: int = i2 + 1
			indices[k] = i0
			indices[k + 1] = i1
			indices[k + 2] = i2
			indices[k + 3] = i1
			indices[k + 4] = i3
			indices[k + 5] = i2
			if build_collision:
				col_faces[k] = verts[i0]
				col_faces[k + 1] = verts[i1]
				col_faces[k + 2] = verts[i2]
				col_faces[k + 3] = verts[i1]
				col_faces[k + 4] = verts[i3]
				col_faces[k + 5] = verts[i2]
			k += 6

	# Append 4 downward seam-hiding edge skirts (no physics faces)
	var sv_base: int = v_count
	k = _append_edge_skirt(verts, normals, uvs, uv2s, colors, custom0, indices, k, sv_base, stride, grid, 0, true, true)
	sv_base += stride
	k = _append_edge_skirt(verts, normals, uvs, uv2s, colors, custom0, indices, k, sv_base, stride, grid, grid, true, false)
	sv_base += stride
	k = _append_edge_skirt(verts, normals, uvs, uv2s, colors, custom0, indices, k, sv_base, stride, grid, 0, false, false)
	sv_base += stride
	_append_edge_skirt(verts, normals, uvs, uv2s, colors, custom0, indices, k, sv_base, stride, grid, grid, false, true)

	var mesh_arrays: Array = []
	mesh_arrays.resize(Mesh.ARRAY_MAX)
	mesh_arrays[Mesh.ARRAY_VERTEX] = verts
	mesh_arrays[Mesh.ARRAY_NORMAL] = normals
	mesh_arrays[Mesh.ARRAY_TEX_UV] = uvs
	mesh_arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	mesh_arrays[Mesh.ARRAY_COLOR] = colors
	mesh_arrays[Mesh.ARRAY_CUSTOM0] = custom0
	mesh_arrays[Mesh.ARRAY_INDEX] = indices

	var water_arrays: Array = []
	if has_river:
		water_arrays = _build_chunk_water_arrays(grid, stride, step, heights, riv_dists, riv_hws, riv_wys)

	var scatter_data: Dictionary = {}
	if not variant_counts.is_empty():
		scatter_data = ChunkScatterSolver.solve_chunk_props(
			sampler.blueprint,
			cx,
			cz,
			lod,
			grid,
			heights,
			normals,
			biome_ids,
			road_dists,
			road_kinds,
			road_hws,
			power_dists,
			riv_dists,
			riv_hws,
			site_weights,
			slices["roads"],
			variant_counts
		)

	return {
		"cx": cx,
		"cz": cz,
		"lod": lod,
		"has_collision": build_collision,
		"mesh_arrays": mesh_arrays,
		"col_faces": col_faces,
		"water_arrays": water_arrays,
		"scatter_data": scatter_data,
		"dominant_biome": dominant_biome,
		"min_y": min_y,
		"max_y": max_y,
		"has_river": not water_arrays.is_empty(),
		"has_road": has_road,
		"gen_ms": Time.get_ticks_msec() - t0,
	}


static func _append_edge_skirt(
	verts: PackedVector3Array,
	normals: PackedVector3Array,
	uvs: PackedVector2Array,
	uv2s: PackedVector2Array,
	colors: PackedColorArray,
	custom0: PackedFloat32Array,
	indices: PackedInt32Array,
	k: int,
	sv_base: int,
	stride: int,
	grid: int,
	fixed_coord: int,
	is_z_edge: bool,
	flip_winding: bool
) -> int:
	for s in range(stride):
		var src: int = (fixed_coord * stride + s) if is_z_edge else (s * stride + fixed_coord)
		var dst: int = sv_base + s
		var vp: Vector3 = verts[src]
		verts[dst] = Vector3(vp.x, vp.y - SKIRT_DEPTH, vp.z)
		normals[dst] = normals[src]
		uvs[dst] = uvs[src]
		uv2s[dst] = uv2s[src]
		colors[dst] = colors[src]
		var s_off: int = src * 4
		var d_off: int = dst * 4
		custom0[d_off] = custom0[s_off]
		custom0[d_off + 1] = custom0[s_off + 1]
		custom0[d_off + 2] = custom0[s_off + 2]
		custom0[d_off + 3] = custom0[s_off + 3]

	for s in range(grid):
		var top_a: int = (fixed_coord * stride + s) if is_z_edge else (s * stride + fixed_coord)
		var top_b: int = (fixed_coord * stride + s + 1) if is_z_edge else ((s + 1) * stride + fixed_coord)
		var bot_a: int = sv_base + s
		var bot_b: int = sv_base + s + 1
		if flip_winding:
			indices[k] = top_a; indices[k + 1] = bot_a; indices[k + 2] = top_b
			indices[k + 3] = top_b; indices[k + 4] = bot_a; indices[k + 5] = bot_b
		else:
			indices[k] = top_a; indices[k + 1] = top_b; indices[k + 2] = bot_a
			indices[k + 3] = top_b; indices[k + 4] = bot_b; indices[k + 5] = bot_a
		k += 6
	return k


static func _build_chunk_water_arrays(
	grid: int,
	stride: int,
	step: float,
	heights: PackedFloat32Array,
	riv_dists: PackedFloat32Array,
	riv_hws: PackedFloat32Array,
	riv_wys: PackedFloat32Array
) -> Array:
	var w_verts := PackedVector3Array()
	var w_normals := PackedVector3Array()
	var w_uvs := PackedVector2Array()
	var w_indices := PackedInt32Array()
	var idx_map := PackedInt32Array()
	idx_map.resize(stride * stride)
	idx_map.fill(-1)

	for gz in range(grid):
		for gx in range(grid):
			var i0: int = gz * stride + gx
			var i1: int = i0 + 1
			var i2: int = i0 + stride
			var i3: int = i2 + 1
			var near_river: bool = false
			for ci in [i0, i1, i2, i3]:
				if riv_dists[ci] <= riv_hws[ci] + 3.2 and riv_wys[ci] > heights[ci] - 0.8:
					near_river = true
					break
			if not near_river:
				continue

			var cell_indices: Array[int] = [i0, i1, i2, i3]
			var qv: Array[int] = []
			for vi in range(4):
				var src_i: int = cell_indices[vi]
				if idx_map[src_i] == -1:
					var cgx: int = src_i % stride
					var cgz: int = src_i / stride
					var lx: float = float(cgx) * step
					var lz: float = float(cgz) * step
					idx_map[src_i] = w_verts.size()
					w_verts.append(Vector3(lx, riv_wys[src_i], lz))
					w_normals.append(Vector3.UP)
					w_uvs.append(Vector2(lx / UV_TILE_METERS, lz / UV_TILE_METERS))
				qv.append(idx_map[src_i])

			w_indices.append(qv[0]); w_indices.append(qv[1]); w_indices.append(qv[2])
			w_indices.append(qv[1]); w_indices.append(qv[3]); w_indices.append(qv[2])

	if w_indices.is_empty():
		return []

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = w_verts
	arrays[Mesh.ARRAY_NORMAL] = w_normals
	arrays[Mesh.ARRAY_TEX_UV] = w_uvs
	arrays[Mesh.ARRAY_INDEX] = w_indices
	return arrays


static func _compute_surface_splat(
	biome_id: int,
	normal_y: float,
	road_dist: float,
	road_kind: int,
	road_hw: float,
	riv_dist: float,
	riv_hw: float,
	site_w: float = 0.0
) -> Array:
	var mud: float = 0.12
	var leaf: float = 0.28
	var rock: float = 0.05
	var wet: float = 0.35
	var ash: float = 0.0
	var myco: float = 0.0
	var asphalt: float = 0.0
	var gravel: float = 0.0

	match biome_id:
		BiomeRegistry.Id.HEMLOCK_HOLLOW, BiomeRegistry.Id.GREEN_ISLAND:
			mud = 0.08; leaf = 0.34; wet = 0.38
		BiomeRegistry.Id.CEDAR_FOG_BOTTOM, BiomeRegistry.Id.MOSS_CREEK_BASIN:
			mud = 0.22; leaf = 0.56; wet = 0.52
		BiomeRegistry.Id.ALDER_SLOUGH:
			mud = 0.68; leaf = 0.24; wet = 0.85
		BiomeRegistry.Id.BURN_SCAR:
			mud = 0.38; leaf = 0.12; wet = 0.14; ash = 0.90
		BiomeRegistry.Id.MYCORRHIZAL_SINKHOLE:
			mud = 0.72; leaf = 0.18; wet = 0.78; myco = 0.92; ash = 0.25
		BiomeRegistry.Id.PALE_BONEWOOD:
			mud = 0.26; leaf = 0.20; rock = 0.16; wet = 0.12; ash = 0.74
		BiomeRegistry.Id.SULFUR_RAVINE:
			mud = 0.65; leaf = 0.10; rock = 0.22; wet = 0.84; myco = 0.80
		BiomeRegistry.Id.LUMBER_MILL_GROUNDS, BiomeRegistry.Id.RAIL_SPUR_YARD, BiomeRegistry.Id.LOGGING_DEPOT:
			mud = 0.42; leaf = 0.16; rock = 0.38; wet = 0.46; gravel = 0.55
		BiomeRegistry.Id.QUARRY_CUT, BiomeRegistry.Id.GRANITE_ESCARPMENT:
			mud = 0.12; leaf = 0.06; rock = 0.84; wet = 0.32
		BiomeRegistry.Id.SUBALPINE_CREST, BiomeRegistry.Id.LOOKOUT_RIDGE:
			mud = 0.16; leaf = 0.32; rock = 0.46; wet = 0.28
		BiomeRegistry.Id.WINDFALL_SADDLE:
			mud = 0.22; leaf = 0.66; rock = 0.12; wet = 0.36
		BiomeRegistry.Id.QUARANTINE_PERIMETER:
			mud = 0.46; leaf = 0.14; rock = 0.44; wet = 0.52; asphalt = 0.25
		BiomeRegistry.Id.TELEMETRY_SWATH:
			mud = 0.36; leaf = 0.44; rock = 0.18; wet = 0.42; myco = 0.18
		BiomeRegistry.Id.CULVERT_DRAIN:
			mud = 0.74; leaf = 0.16; rock = 0.22; wet = 0.88; myco = 0.26

	# Steep terrain exposes rockfaces
	var slope: float = clampf((0.88 - normal_y) / 0.34, 0.0, 1.0)
	if slope > 0.01:
		rock = lerpf(rock, 0.92, slope)
		leaf *= (1.0 - slope * 0.75)

	# Road, rail & logging track material overrides
	if road_kind >= 0 and road_dist < road_hw + 3.2:
		var rw: float = 1.0 - smoothstep(road_hw * 0.72, road_hw + 2.8, road_dist)
		if road_kind == WorldBlueprint.RouteKind.HIGHWAY_PAVED:
			var deck_w: float = 1.0 - smoothstep(road_hw * 0.65, road_hw + 0.9, road_dist)
			asphalt = maxf(asphalt, deck_w * 0.98)
			gravel = maxf(gravel, rw * (1.0 - deck_w) * 0.90)
			wet = maxf(wet, deck_w * 0.88)
			mud *= (1.0 - rw * 0.65)
		elif road_kind == WorldBlueprint.RouteKind.RAIL_SPUR:
			gravel = maxf(gravel, rw * 0.92)
			rock = maxf(rock, rw * 0.86)
			mud = maxf(mud, rw * 0.36)
		else:
			mud = maxf(mud, rw * 0.90)
			wet = maxf(wet, rw * 0.72)
			leaf *= (1.0 - rw * 0.80)

	# Flattened structure pads blend subtle compacted gravel/wetness
	if site_w > 0.05:
		gravel = maxf(gravel, site_w * 0.42)
		mud = maxf(mud, site_w * 0.45)

	# River banks become dark rain-slick silt
	if riv_dist < riv_hw + 5.5:
		var vw: float = 1.0 - smoothstep(riv_hw * 0.5, riv_hw + 5.0, riv_dist)
		mud = maxf(mud, vw * 0.92)
		wet = maxf(wet, vw * 0.95)
		leaf *= (1.0 - vw * 0.82)
		asphalt *= (1.0 - vw)

	return [Color(mud, leaf, rock, wet), Vector2(ash, myco), Vector2(asphalt, gravel)]
