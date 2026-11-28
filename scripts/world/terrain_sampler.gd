class_name TerrainSampler
extends RefCounted

var blueprint: WorldBlueprint


func _init(bp: WorldBlueprint) -> void:
	blueprint = bp
	# Eagerly initialize BiomeRegistry specs on owner thread so WorkerThreadPool reads are lock-free & immutable
	BiomeRegistry.get_all_specs()


func collect_chunk_slices(min_x: float, max_x: float, min_z: float, max_z: float) -> Dictionary:
	var min_bx: int = int(floor(min_x / WorldBlueprint.BUCKET_SIZE))
	var max_bx: int = int(floor(max_x / WorldBlueprint.BUCKET_SIZE))
	var min_bz: int = int(floor(min_z / WorldBlueprint.BUCKET_SIZE))
	var max_bz: int = int(floor(max_z / WorldBlueprint.BUCKET_SIZE))

	var encs: Array = []
	var roads: Array = []
	var rivs: Array = []
	var sites: Array = []

	for bz in range(min_bz, max_bz + 1):
		for bx in range(min_bx, max_bx + 1):
			var bk := Vector2i(bx, bz)
			for enc in blueprint.enclave_buckets.get(bk, []):
				var mr: float = float(enc["max_reach"])
				var cx: float = float(enc["center"].x)
				var cz: float = float(enc["center"].y)
				if cx + mr >= min_x and cx - mr <= max_x and cz + mr >= min_z and cz - mr <= max_z:
					if not encs.has(enc):
						encs.append(enc)
			for seg in blueprint.road_buckets.get(bk, []):
				var sa: Vector2 = seg["a"]
				var sb: Vector2 = seg["b"]
				var pad: float = float(seg["half_width"]) + 14.0
				if maxf(sa.x, sb.x) + pad < min_x or minf(sa.x, sb.x) - pad > max_x:
					continue
				if maxf(sa.y, sb.y) + pad < min_z or minf(sa.y, sb.y) - pad > max_z:
					continue
				if not roads.has(seg):
					roads.append(seg)
			for rseg in blueprint.river_buckets.get(bk, []):
				var ra: Vector2 = rseg["a"]
				var rb: Vector2 = rseg["b"]
				var rpad: float = float(rseg["half_width"]) + 16.0
				if maxf(ra.x, rb.x) + rpad < min_x or minf(ra.x, rb.x) - rpad > max_x:
					continue
				if maxf(ra.y, rb.y) + rpad < min_z or minf(ra.y, rb.y) - rpad > max_z:
					continue
				if not rivs.has(rseg):
					rivs.append(rseg)
			for site in blueprint.site_buckets.get(bk, []):
				var rad: float = float(site["radius"]) * 1.85
				var sx: float = float(site["pos"].x)
				var sz: float = float(site["pos"].z)
				if sx + rad >= min_x and sx - rad <= max_x and sz + rad >= min_z and sz - rad <= max_z:
					if not sites.has(site):
						sites.append(site)

	return {"enclaves": encs, "roads": roads, "rivers": rivs, "sites": sites}


func sample_point(x: float, z: float) -> Dictionary:
	var bk: Vector2i = blueprint.get_bucket_key(x, z)
	return _sample_with_lists(
		x, z,
		blueprint.enclave_buckets.get(bk, []),
		blueprint.road_buckets.get(bk, []),
		blueprint.river_buckets.get(bk, []),
		blueprint.site_buckets.get(bk, [])
	)


func sample_point_sliced(x: float, z: float, slices: Dictionary) -> Dictionary:
	return _sample_with_lists(x, z, slices["enclaves"], slices["roads"], slices["rivers"], slices["sites"])


func _sample_with_lists(x: float, z: float, enc_list: Array, road_list: Array, riv_list: Array, site_list: Array) -> Dictionary:
	var cf: Dictionary = blueprint.eval_climate_fields(x, z)
	var base_biome: int = BiomeRegistry.classify_base_biome(
		cf["elev_norm"], cf["moist"], cf["blight"], cf["human"]
	)

	var enc_info: Dictionary = _eval_enclaves_list(x, z, enc_list)
	var road_info: Dictionary = _eval_road_list(x, z, road_list)
	var river_info: Dictionary = _eval_river_list(x, z, riv_list)
	var site_info: Dictionary = _eval_site_list(x, z, site_list)

	var active_biome: int = base_biome
	var enclave_w: float = enc_info["weight"]
	if enclave_w > 0.42:
		active_biome = enc_info["biome_id"]
	elif float(cf["micro"]) > 0.52 and cf["elev_norm"] < 0.65:
		# Sub-chunk randomized micro-pockets fracture clean borders organically
		active_biome = BiomeRegistry.Id.WINDFALL_SADDLE if base_biome != BiomeRegistry.Id.GREEN_ISLAND else base_biome

	if int(site_info["forced_biome"]) >= 0 and float(site_info["weight"]) > 0.35:
		active_biome = int(site_info["forced_biome"])
	elif float(road_info["power_dist"]) < 7.5 and cf["elev_norm"] < 0.78:
		active_biome = BiomeRegistry.Id.TELEMETRY_SWATH

	var h: float = _compute_height_from_fields(x, z, cf, enc_info, road_info, river_info, site_info)
	var base_anom: float = float(BiomeRegistry.get_spec(active_biome)["anomaly"])
	var anomaly: float = clampf(base_anom + float(enc_info["anomaly_delta"]) * enclave_w, 0.0, 1.0)
	if active_biome == BiomeRegistry.Id.GREEN_ISLAND:
		anomaly = 0.0

	var river_water_y: float = h
	var riv_d: float = float(river_info["dist"])
	var riv_hw: float = float(river_info["half_width"])
	if riv_d < riv_hw + 9.0:
		var uncarved_y: float = blueprint.eval_macro_height(x, z) + blueprint.noise_elev_detail.get_noise_2d(x, z) * 4.2 + float(enc_info["height_delta"]) * float(enc_info["weight"])
		var full_carve: float = 2.6 + riv_hw * 0.25
		river_water_y = uncarved_y - full_carve * 0.56

	return {
		"height": h,
		"biome_id": active_biome,
		"base_biome_id": base_biome,
		"enclave_weight": enclave_w,
		"anomaly": anomaly,
		"road_dist": road_info["road_dist"],
		"road_kind": road_info["road_kind"],
		"road_hw": road_info["road_hw"],
		"power_dist": road_info["power_dist"],
		"river_dist": riv_d,
		"river_half_width": riv_hw,
		"river_water_y": river_water_y,
		"site_weight": site_info["weight"],
	}


func get_height(x: float, z: float) -> float:
	var bk: Vector2i = blueprint.get_bucket_key(x, z)
	return get_height_with_lists(
		x, z,
		blueprint.enclave_buckets.get(bk, []),
		blueprint.road_buckets.get(bk, []),
		blueprint.river_buckets.get(bk, []),
		blueprint.site_buckets.get(bk, [])
	)


func get_height_with_lists(x: float, z: float, enc_list: Array, road_list: Array, riv_list: Array, site_list: Array) -> float:
	var cf: Dictionary = blueprint.eval_climate_fields(x, z)
	var enc_info: Dictionary = _eval_enclaves_list(x, z, enc_list)
	var road_info: Dictionary = _eval_road_list(x, z, road_list)
	var river_info: Dictionary = _eval_river_list(x, z, riv_list)
	var site_info: Dictionary = _eval_site_list(x, z, site_list)
	return _compute_height_from_fields(x, z, cf, enc_info, road_info, river_info, site_info)


func get_normal(x: float, z: float, step: float = 0.75) -> Vector3:
	var hl: float = get_height(x - step, z)
	var hr: float = get_height(x + step, z)
	var hd: float = get_height(x, z - step)
	var hu: float = get_height(x, z + step)
	return Vector3(hl - hr, 2.0 * step, hd - hu).normalized()


func get_normal_sliced(x: float, z: float, slices: Dictionary, step: float = 1.5) -> Vector3:
	var el: Array = slices["enclaves"]
	var rl: Array = slices["roads"]
	var vl: Array = slices["rivers"]
	var sl: Array = slices["sites"]
	var hl: float = get_height_with_lists(x - step, z, el, rl, vl, sl)
	var hr: float = get_height_with_lists(x + step, z, el, rl, vl, sl)
	var hd: float = get_height_with_lists(x, z - step, el, rl, vl, sl)
	var hu: float = get_height_with_lists(x, z + step, el, rl, vl, sl)
	return Vector3(hl - hr, 2.0 * step, hd - hu).normalized()


func _compute_height_from_fields(
	x: float,
	z: float,
	cf: Dictionary,
	enc_info: Dictionary,
	road_info: Dictionary,
	river_info: Dictionary,
	site_info: Dictionary
) -> float:
	var h: float = blueprint.eval_macro_height(x, z)
	var fine_relief: float = blueprint.noise_elev_detail.get_noise_2d(x * 7.5, z * 7.5) * 1.45 + blueprint.noise_micro.get_noise_2d(x * 4.2, z * 4.2) * 0.48
	h += blueprint.noise_elev_detail.get_noise_2d(x, z) * 4.2 + float(cf["micro"]) * 0.65 + fine_relief

	# Enclave relief (sinkholes carve inward, Green Islands lift slightly)
	h += float(enc_info["height_delta"]) * float(enc_info["weight"])

	# Road/rail bed cross-profile smoothing (ruts & ballast)
	var sw: float = float(site_info["weight"])
	var rdist: float = float(road_info["road_dist"])
	var rhw: float = float(road_info["road_hw"])
	var rkind: int = int(road_info["road_kind"])
	if rkind >= 0 and rdist < rhw + 4.5:
		var shoulder: float = 1.0 - smoothstep(rhw * 0.75, rhw + 4.2, rdist)
		# Sample centerline elevation smoothly without recursive fine noise on roadbeds
		var road_base_y: float = blueprint.eval_macro_height(x, z) + blueprint.noise_elev_detail.get_noise_2d(x, z) * 4.2 + float(enc_info["height_delta"]) * float(enc_info["weight"])
		h = lerpf(h, road_base_y, shoulder * 0.76)
		if rkind == WorldBlueprint.RouteKind.LOG_TRAIL_DIRT and rdist < rhw:
			var rut: float = exp(-pow((absf(rdist) - 0.92) / 0.35, 2.0))
			h -= rut * 0.11
		elif rkind == WorldBlueprint.RouteKind.RAIL_SPUR and rdist < rhw:
			var ballast: float = 1.0 - smoothstep(1.2, rhw, rdist)
			h += ballast * 0.34

	# Flattened structure pads override roads/rails & micro-hills smoothly across building aprons
	if sw > 0.0:
		h = lerpf(h, float(site_info["target_y"]), sw)

	# River valley carve with organic bank shoreline wobble (softened at bridge pads)
	var riv_d: float = float(river_info["dist"])
	var riv_hw: float = float(river_info["half_width"])
	if riv_d < riv_hw + 11.0:
		var bank_wobble: float = blueprint.noise_micro.get_noise_2d(x * 3.2, z * 3.2) * 1.9
		var eff_riv_d: float = maxf(0.0, riv_d + bank_wobble)
		var bank: float = 1.0 - smoothstep(riv_hw * 0.42, riv_hw + 8.5, eff_riv_d)
		var bridge_mask: float = 1.0 - sw * 0.55
		h -= bank * (2.6 + riv_hw * 0.25) * bridge_mask

	return h


func _eval_enclaves_list(x: float, z: float, list: Array) -> Dictionary:
	if list.is_empty():
		return {"weight": 0.0, "biome_id": -1, "height_delta": 0.0, "anomaly_delta": 0.0}

	var best_w: float = 0.0
	var best_biome: int = -1
	var total_h: float = 0.0
	var total_a: float = 0.0
	var total_w: float = 0.0
	var pos := Vector2(x, z)
	var micro_j: float = blueprint.noise_micro.get_noise_2d(x * 0.55, z * 0.55)

	for enc in list:
		var d: Vector2 = pos - enc["center"]
		var max_r: float = float(enc["max_reach"])
		if d.length_squared() > max_r * max_r:
			continue
		var cos_a: float = enc["cos_a"]
		var sin_a: float = enc["sin_a"]
		var lx: float = d.x * cos_a + d.y * sin_a
		var lz: float = -d.x * sin_a + d.y * cos_a
		var nx: float = lx / float(enc["rad_a"])
		var nz: float = lz / float(enc["rad_b"])
		var norm_r: float = sqrt(nx * nx + nz * nz)
		var theta: float = atan2(nz, nx)

		var lobes: float = 0.55 * sin(theta * float(enc["lobe_a"]) + float(enc["phase_a"])) + 0.45 * cos(theta * float(enc["lobe_b"]) + float(enc["phase_b"]))
		var boundary: float = 1.0 + float(enc["warp_amp"]) * (lobes + micro_j * 0.65)
		boundary = maxf(0.45, boundary)
		if norm_r >= boundary:
			continue

		var w: float = 1.0 - smoothstep(boundary * 0.45, boundary, norm_r)
		total_h += float(enc["height_delta"]) * w
		total_a += float(enc["anomaly_delta"]) * w
		total_w += w
		if w > best_w:
			best_w = w
			best_biome = int(enc["biome_id"])

	if total_w > 1.0:
		total_h /= total_w
		total_a /= total_w
	return {
		"weight": clampf(best_w, 0.0, 1.0),
		"biome_id": best_biome,
		"height_delta": total_h,
		"anomaly_delta": total_a,
	}


func get_road_info(x: float, z: float) -> Dictionary:
	var bk: Vector2i = blueprint.get_bucket_key(x, z)
	return _eval_road_list(x, z, blueprint.road_buckets.get(bk, []))


func _eval_road_list(x: float, z: float, list: Array) -> Dictionary:
	var min_road: float = 1e6
	var min_kind: int = -1
	var min_hw: float = 0.0
	var min_power: float = 1e6
	var p := Vector2(x, z)

	for seg in list:
		var cp: Vector2 = Geometry2D.get_closest_point_to_segment(p, seg["a"], seg["b"])
		var d: float = p.distance_to(cp)
		var kind: int = int(seg["kind"])
		if kind == WorldBlueprint.RouteKind.POWER_LINE:
			if d < min_power:
				min_power = d
		else:
			if d < min_road:
				min_road = d
				min_kind = kind
				min_hw = float(seg["half_width"])

	return {
		"road_dist": min_road,
		"road_kind": min_kind,
		"road_hw": min_hw,
		"power_dist": min_power,
	}


func get_river_info(x: float, z: float) -> Dictionary:
	var bk: Vector2i = blueprint.get_bucket_key(x, z)
	return _eval_river_list(x, z, blueprint.river_buckets.get(bk, []))


func _eval_river_list(x: float, z: float, list: Array) -> Dictionary:
	var min_d: float = 1e6
	var hw: float = 0.0
	var p := Vector2(x, z)
	for seg in list:
		var cp: Vector2 = Geometry2D.get_closest_point_to_segment(p, seg["a"], seg["b"])
		var d: float = p.distance_to(cp)
		if d < min_d:
			min_d = d
			hw = float(seg["half_width"])
	return {"dist": min_d, "half_width": hw}


func _eval_site_list(x: float, z: float, list: Array) -> Dictionary:
	if list.is_empty():
		return {"weight": 0.0, "target_y": 0.0, "forced_biome": -1}
	var best_w: float = 0.0
	var best_y: float = 0.0
	var best_biome: int = -1
	var p := Vector2(x, z)
	for site in list:
		var rad: float = float(site["radius"])
		var sp := Vector2(site["pos"].x, site["pos"].z)
		var d: float = p.distance_to(sp)
		if d < rad * 1.75:
			var w: float = 1.0 - smoothstep(rad * 0.72, rad * 1.72, d)
			if w > best_w:
				best_w = w
				best_y = float(site["pos"].y)
				best_biome = int(site.get("forced_biome", -1))
	return {"weight": best_w, "target_y": best_y, "forced_biome": best_biome}


func export_overview_image(size_px: int = 768) -> Image:
	var img := Image.create(size_px, size_px, false, Image.FORMAT_RGBA8)
	var step_m: float = WorldBlueprint.WORLD_SIZE / float(size_px)

	# 1. Render base biome colors + topographic hillshade + contour intervals
	for py in range(size_px):
		var wz: float = -WorldBlueprint.HALF_WORLD + (float(py) + 0.5) * step_m
		for px in range(size_px):
			var wx: float = -WorldBlueprint.HALF_WORLD + (float(px) + 0.5) * step_m
			var s: Dictionary = sample_point(wx, wz)
			var spec: Dictionary = BiomeRegistry.get_spec(int(s["biome_id"]))
			var col: Color = spec["color"]

			var h_c: float = float(s["height"])
			var h_dx: float = blueprint.eval_macro_height(wx + step_m, wz) - blueprint.eval_macro_height(wx - step_m, wz)
			var h_dz: float = blueprint.eval_macro_height(wx, wz + step_m) - blueprint.eval_macro_height(wx, wz - step_m)
			var shade: float = clampf(0.92 - (h_dx + h_dz) * 0.008 + (h_c / 340.0) * 0.25, 0.45, 1.38)
			col = Color(col.r * shade, col.g * shade, col.b * shade, 1.0)

			var mod_h: float = fposmod(h_c, 25.0)
			if mod_h < 1.35:
				col = col.darkened(0.18)

			img.set_pixel(px, py, col)

	# 2. Vector-rasterize rivers, power lines, dirt logging trails, rails & paved highways cleanly
	for rpts in blueprint.river_paths:
		_draw_polyline(img, rpts, step_m, size_px, Color(0.14, 0.44, 0.68, 1.0), 1)
	for r in blueprint.routes:
		var rkind: int = int(r["kind"])
		var col_r := Color(0.75, 0.60, 0.42, 1.0)
		var thick: int = 0
		if rkind == WorldBlueprint.RouteKind.POWER_LINE:
			col_r = Color(0.32, 0.78, 0.86, 0.85)
		elif rkind == WorldBlueprint.RouteKind.RAIL_SPUR:
			col_r = Color(0.72, 0.44, 0.78, 1.0); thick = 1
		elif rkind == WorldBlueprint.RouteKind.HIGHWAY_PAVED:
			col_r = Color(0.90, 0.70, 0.28, 1.0); thick = 1
		_draw_polyline(img, r["points"], step_m, size_px, col_r, thick)

	# 3. Stamp distinct landmark markers so 32km spatial layout is readable cleanly
	for st in blueprint.structures:
		var sx: int = clampi(int((float(st["pos"].x) + WorldBlueprint.HALF_WORLD) / step_m), 0, size_px - 1)
		var sy: int = clampi(int((float(st["pos"].z) + WorldBlueprint.HALF_WORLD) / step_m), 0, size_px - 1)
		var col_m := Color.WHITE
		var r_px: int = 2
		match int(st["kind"]):
			WorldBlueprint.StructureKind.CRASH_SITE:
				col_m = Color(1.0, 0.92, 0.15); r_px = 5
			WorldBlueprint.StructureKind.FINALE_CACHE:
				col_m = Color(0.15, 1.0, 0.95); r_px = 5
			WorldBlueprint.StructureKind.RELAY_TOWER:
				col_m = Color(1.0, 0.20, 0.18); r_px = 4
			WorldBlueprint.StructureKind.INDUSTRIAL_HUB:
				col_m = Color(1.0, 0.56, 0.12); r_px = 4
			WorldBlueprint.StructureKind.SAFE_HOUSE:
				col_m = Color(0.30, 1.0, 0.40); r_px = 3
			WorldBlueprint.StructureKind.TUNNEL_PORTAL:
				col_m = Color(0.75, 0.45, 1.0); r_px = 2
			WorldBlueprint.StructureKind.QUARANTINE_GATE:
				col_m = Color(1.0, 0.40, 0.65); r_px = 3
			WorldBlueprint.StructureKind.CAMPSITE_OR_DECOY:
				col_m = Color(0.88, 0.85, 0.72); r_px = 1
			WorldBlueprint.StructureKind.BRIDGE:
				col_m = Color(0.95, 0.95, 1.0); r_px = 2

		for dy in range(-r_px, r_px + 1):
			for dx in range(-r_px, r_px + 1):
				if dx * dx + dy * dy <= r_px * r_px:
					var px2: int = clampi(sx + dx, 0, size_px - 1)
					var py2: int = clampi(sy + dy, 0, size_px - 1)
					img.set_pixel(px2, py2, col_m)

	return img


func _draw_polyline(img: Image, pts: Array, step_m: float, size_px: int, col: Color, radius_px: int) -> void:
	for i in range(pts.size() - 1):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var ax: float = (a.x + WorldBlueprint.HALF_WORLD) / step_m
		var ay: float = (a.y + WorldBlueprint.HALF_WORLD) / step_m
		var bx: float = (b.x + WorldBlueprint.HALF_WORLD) / step_m
		var by: float = (b.y + WorldBlueprint.HALF_WORLD) / step_m
		var steps: int = maxi(1, int(ceil(maxf(absf(bx - ax), absf(by - ay)))))
		for s in range(steps + 1):
			var t: float = float(s) / float(steps)
			var px: int = clampi(int(round(lerpf(ax, bx, t))), 0, size_px - 1)
			var py: int = clampi(int(round(lerpf(ay, by, t))), 0, size_px - 1)
			for dy in range(-radius_px, radius_px + 1):
				for dx in range(-radius_px, radius_px + 1):
					var xx: int = clampi(px + dx, 0, size_px - 1)
					var yy: int = clampi(py + dy, 0, size_px - 1)
					var prev: Color = img.get_pixel(xx, yy)
					img.set_pixel(xx, yy, prev.lerp(col, col.a))
