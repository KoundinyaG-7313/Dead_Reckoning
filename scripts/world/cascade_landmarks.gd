class_name CascadeLandmarks
extends RefCounted

const PROPS_BASE: String = "res://assets/models/props/"
const PROPS_HD_BASE: String = "res://assets/models/props_hd/"
const KENNEY_BASE: String = "res://assets/models/kenney/"
const FOREST_BASE: String = "res://assets/models/forest/"


static func build_landmark(site: Dictionary, sampler: TerrainSampler, assets: CascadeAssetBank) -> Dictionary:
	var root := Node3D.new()
	root.name = String(site["name"])
	var beacons: Array = []
	var swaying: Array = []
	var flickers: Array = []

	var kind: int = int(site["kind"])
	var pos2 := Vector2(float(site["pos"].x), float(site["pos"].z))
	var base_y: float = sampler.get_height(pos2.x, pos2.y)
	var anchor_world := Vector3(pos2.x, base_y, pos2.y)
	root.rotation.y = float(site.get("yaw", 0.0))

	match kind:
		WorldBlueprint.StructureKind.CRASH_SITE:
			_build_crash_site(root, assets, flickers)
		WorldBlueprint.StructureKind.BRIDGE:
			anchor_world = _build_river_bridge(root, site, sampler, assets, swaying, flickers)
		WorldBlueprint.StructureKind.RELAY_TOWER:
			_build_relay_tower_site(root, assets, beacons, swaying, flickers)
		WorldBlueprint.StructureKind.SAFE_HOUSE:
			var elev_norm: float = clampf(base_y / 260.0, 0.0, 1.0)
			_build_safehouse_cabin(root, assets, elev_norm > 0.56, swaying, flickers)
		WorldBlueprint.StructureKind.INDUSTRIAL_HUB:
			_build_industrial_hub(root, site, assets, flickers)
		WorldBlueprint.StructureKind.QUARANTINE_GATE:
			_build_quarantine_gate(root, assets, flickers)
		WorldBlueprint.StructureKind.TUNNEL_PORTAL:
			_build_tunnel_portal(root, assets, flickers)
		WorldBlueprint.StructureKind.CAMPSITE_OR_DECOY:
			_build_campsite(root, int(site["id"]), assets, beacons, flickers)
		WorldBlueprint.StructureKind.FINALE_CACHE:
			_build_finale_cache(root, assets, beacons, flickers)

	return {
		"id": int(site["id"]),
		"node": root,
		"anchor_world": anchor_world,
		"beacons": beacons,
		"swaying": swaying,
		"flickers": flickers,
	}


static func _build_crash_site(root: Node3D, assets: CascadeAssetBank, flickers: Array) -> void:
	# 1991 Boxy Volvo Cargo Van crashed into ditch beside fallen pine & snapped high-voltage line
	var mat_van := ForestMaterials.build_dark_metal_material(Color(0.32, 0.44, 0.56), 0.36, 0.52)
	var mat_trim := ForestMaterials.build_dark_metal_material(Color(0.06, 0.07, 0.08), 0.84, 0.15)
	var mat_glass := ForestMaterials.build_dark_metal_material(Color(0.04, 0.08, 0.10), 0.08, 0.18)
	var mat_chrome := ForestMaterials.build_dark_metal_material(Color(0.42, 0.44, 0.46), 0.28, 0.88)
	var mat_hazard := ForestMaterials.build_emissive_material(Color(1.0, 0.42, 0.08), 5.0)
	var mat_headlight := ForestMaterials.build_emissive_material(Color(1.0, 0.90, 0.68), 3.6)
	var mat_cable := ForestMaterials.build_dark_metal_material(Color(0.04, 0.04, 0.05), 0.85, 0.4)

	var van := Node3D.new()
	van.name = "Wrecked1991Van"
	van.rotation = Vector3(-0.10, 0.24, -0.18) # Slid sideways/nose-down into ditch
	van.position = Vector3(-0.6, 0.58, 0.0)
	root.add_child(van)

	_add_box_col(van, Vector3(0.0, 0.62, 0.35), Vector3(1.98, 1.35, 3.35), mat_van) # Cargo box
	_add_box_col(van, Vector3(0.0, 0.44, -1.78), Vector3(1.90, 0.92, 1.15), mat_van) # Nose / engine bay
	_add_box_col(van, Vector3(0.0, 1.05, -1.35), Vector3(1.86, 0.58, 0.82), mat_glass) # Cab windshield frame
	_add_box_col(van, Vector3(0.0, 1.34, -0.45), Vector3(1.94, 0.12, 4.10), mat_van) # Roof rack/cap

	# Heavy bumpers, grille trim, side mirrors, roof rack bars & kicked open passenger door
	_add_box_col(van, Vector3(0.0, 0.14, -2.38), Vector3(1.98, 0.22, 0.20), mat_trim)
	_add_box_col(van, Vector3(0.0, 0.12, 2.08), Vector3(2.02, 0.20, 0.22), mat_trim)
	var grille := _make_box(Vector3(1.18, 0.34, 0.08), mat_chrome)
	grille.position = Vector3(0.0, 0.52, -2.36)
	van.add_child(grille)
	for side_m in [-1.02, 1.02]:
		var mirror := _make_box(Vector3(0.14, 0.24, 0.12), mat_trim)
		mirror.position = Vector3(side_m, 1.04, -1.62)
		van.add_child(mirror)
	for rb_z in [-1.4, -0.2, 1.1]:
		var rbar := _make_box(Vector3(1.76, 0.05, 0.08), mat_chrome)
		rbar.position = Vector3(0.0, 1.44, rb_z)
		van.add_child(rbar)
	var open_door := _make_box(Vector3(0.09, 0.92, 0.96), mat_van)
	open_door.position = Vector3(1.36, 0.54, -1.32)
	open_door.rotation.y = -0.78
	van.add_child(open_door)

	for wx in [-0.94, 0.94]:
		for wz in [-1.72, 1.32]:
			var tire := _make_cyl(0.37, 0.24, mat_trim)
			tire.rotation.z = PI * 0.5
			tire.position = Vector3(wx, -0.22, wz)
			van.add_child(tire)
			var rim_dir: float = -PI * 0.5 if wx < 0.0 else PI * 0.5
			_place_gltf(PROPS_HD_BASE + "rusted_wheel_rim_01/rusted_wheel_rim_01.gltf", van, "WheelRim", Vector3(wx + signf(wx) * 0.06, -0.22, wz), Vector3(0.0, rim_dir, 0.0), Vector3.ONE * 1.12)

	# Faint hazard warning lights on wreck rear & left headlight
	for hx in [-0.74, 0.74]:
		var tail := _make_box(Vector3(0.18, 0.16, 0.06), mat_hazard)
		tail.position = Vector3(hx, 0.36, 2.04)
		van.add_child(tail)
	var l_head := _make_box(Vector3(0.24, 0.16, 0.06), mat_headlight)
	l_head.position = Vector3(-0.72, 0.54, -2.36)
	van.add_child(l_head)
	var haz_lt := OmniLight3D.new()
	haz_lt.position = Vector3(0.0, 0.5, 2.3)
	haz_lt.light_color = Color(1.0, 0.45, 0.10)
	haz_lt.light_energy = 1.6
	haz_lt.omni_range = 8.5
	haz_lt.shadow_enabled = false
	van.add_child(haz_lt)
	flickers.append({"light": haz_lt, "base": 1.6, "speed": 4.2, "phase": 0.4})

	# Fallen pine trunk right in front of crushed hood
	_place_gltf(FOREST_BASE + "dead_tree_trunk/dead_tree_trunk.gltf", root, "CrashedFallenPine", Vector3(-1.4, 0.08, -3.2), Vector3(0.08, 0.95, 0.12), Vector3.ONE * 1.45)

	# High-poly 2K snapped utility pole (preset_03) & sparking downed wire draped across van hood
	var pole := Node3D.new()
	pole.name = "SnappedCrashPole"
	pole.position = Vector3(3.1, -0.2, -1.8)
	pole.rotation = Vector3(0.10, -0.3, 0.42)
	root.add_child(pole)
	var hd_pole: ArrayMesh = ForestMaterials.extract_gltf_kit_mesh(PROPS_HD_BASE + "modular_electricity_poles/modular_electricity_poles.gltf", ["preset_03_*"], Vector3(-6.5, 0.0, 0.0), false, true, 0.25)
	if hd_pole != null:
		var p_mi := MeshInstance3D.new()
		p_mi.mesh = hd_pole
		p_mi.scale = Vector3.ONE * 1.26
		pole.add_child(p_mi)
	else:
		var shaft := _make_cyl(0.15, 7.6, assets.mat_creosote)
		shaft.position = Vector3(0.0, 3.8, 0.0)
		pole.add_child(shaft)

	var wire_top: Vector3 = pole.position + (Basis.from_euler(pole.rotation) * Vector3(-0.6, 7.1, 0.0))
	var wire_hood := Vector3(-0.4, 1.05, -2.0)
	_add_catenary(root, wire_top, wire_hood, 0.9, 10, mat_cable)

	var spark_lt := OmniLight3D.new()
	spark_lt.position = wire_hood + Vector3(0.0, 0.18, 0.0)
	spark_lt.light_color = Color(0.58, 0.84, 1.0)
	spark_lt.light_energy = 1.85
	spark_lt.omni_range = 8.0
	spark_lt.shadow_enabled = false
	root.add_child(spark_lt)
	flickers.append({"light": spark_lt, "base": 1.85, "speed": 14.5, "phase": 1.1})

	# Concrete quarantine barriers, smashed warning barricade, spilled cargo & trauma kit
	_place_gltf(PROPS_HD_BASE + "concrete_road_barrier_02/concrete_road_barrier_02.gltf", root, "CrashBarrier_A", Vector3(-3.3, 0.0, 2.0), Vector3(0.06, -0.45, -0.10), Vector3.ONE)
	_place_gltf(PROPS_HD_BASE + "concrete_road_barrier_02/concrete_road_barrier_02.gltf", root, "CrashBarrier_B", Vector3(3.1, 0.0, 2.1), Vector3(-0.04, 0.65, 0.08), Vector3.ONE)
	_place_gltf(PROPS_HD_BASE + "wooden_military_crate/wooden_military_crate.gltf", root, "SpilledCargoCrate", Vector3(1.1, 0.05, 3.2), Vector3(0.04, 0.42, -0.06), Vector3.ONE * 0.92)
	_place_gltf(PROPS_HD_BASE + "medical_box/medical_box.gltf", root, "CrashTraumaKit", Vector3(1.8, 0.04, -0.6), Vector3(0.0, -0.55, 0.0), Vector3.ONE * 1.1)
	_place_gltf(PROPS_HD_BASE + "metal_toolbox/metal_toolbox.gltf", root, "CrashToolbox", Vector3(-2.5, 0.02, 1.6), Vector3(0.0, 0.85, 0.0), Vector3.ONE * 1.1)
	_place_gltf(PROPS_BASE + "Barrel_01/Barrel_01.gltf", root, "HazardDrum_Tipped", Vector3(2.1, 0.28, 1.6), Vector3(1.52, 0.8, 0.2), Vector3.ONE * 1.12)
	_place_gltf(PROPS_BASE + "Barrel_01/Barrel_01.gltf", root, "HazardDrum_Upright", Vector3(2.6, 0.0, 0.4), Vector3(0.0, 0.2, 0.0), Vector3.ONE * 1.12)


static func _build_river_bridge(root: Node3D, site: Dictionary, sampler: TerrainSampler, assets: CascadeAssetBank, swaying: Array, flickers: Array) -> Vector3:
	var px: float = float(site["pos"].x)
	var pz: float = float(site["pos"].z)
	var yaw: float = float(site.get("yaw", 0.0))
	root.rotation.y = yaw

	var dir := Vector2(sin(yaw), cos(yaw))
	var aft_h: float = sampler.get_height(px - dir.x * 11.5, pz - dir.y * 11.5)
	var fore_h: float = sampler.get_height(px + dir.x * 11.5, pz + dir.y * 11.5)
	var mid_sp: Dictionary = sampler.sample_point(px, pz)
	var water_y: float = float(mid_sp["river_water_y"])
	var hw: float = clampf(float(mid_sp["river_half_width"]), 3.2, 11.5)

	var deck_y: float = maxf(water_y + 1.25, maxf(aft_h, fore_h) + 0.20)
	var rkind: int = int(site.get("route_kind", WorldBlueprint.RouteKind.LOG_TRAIL_DIRT))
	var br_w: float = 5.8 if rkind == WorldBlueprint.RouteKind.HIGHWAY_PAVED else 3.8
	var br_l: float = clampf(hw * 2.1 + 3.0, 9.5, 22.0)

	var mat_deck: Material = assets.mat_concrete if rkind == WorldBlueprint.RouteKind.HIGHWAY_PAVED else assets.mat_plank
	var mat_rail: Material = assets.mat_rusted_iron if rkind == WorldBlueprint.RouteKind.RAIL_SPUR else assets.mat_creosote

	_add_box_col(root, Vector3(0.0, -0.14, 0.0), Vector3(br_w, 0.28, br_l), mat_deck)

	for beam_x in [-br_w * 0.40, 0.0, br_w * 0.40]:
		var beam := _make_box(Vector3(0.28, 0.36, br_l + 0.4), assets.mat_creosote)
		beam.position = Vector3(beam_x, -0.44, 0.0)
		root.add_child(beam)

	# Sloped bank approach ramps connecting bridge deck cleanly down onto road shoulders
	for end_val in [-1.0, 1.0]:
		var end_s: float = float(end_val)
		var bank_p: Vector2 = Vector2(px, pz) + dir * (end_s * (br_l * 0.5 + 3.8))
		var bank_h: float = sampler.get_height(bank_p.x, bank_p.y) - 0.14
		var local_tip_y: float = bank_h - deck_y
		var ramp_len: float = sqrt(3.8 * 3.8 + local_tip_y * local_tip_y)
		var slope_pitch: float = atan2(local_tip_y, 3.8) * (-end_s)
		var r_pos := Vector3(0.0, local_tip_y * 0.5 - 0.14, end_s * (br_l * 0.5 + 1.9))
		var ramp := _make_box(Vector3(br_w, 0.26, ramp_len + 0.3), mat_deck)
		ramp.position = r_pos
		ramp.rotation.x = slope_pitch
		root.add_child(ramp)
		_attach_box_col(root, r_pos, Vector3(br_w, 0.28, ramp_len + 0.3), Vector3(slope_pitch, 0.0, 0.0))

	# Guardrails & water piers
	for side_x in [-br_w * 0.5 + 0.16, br_w * 0.5 - 0.16]:
		var top_r := _make_box(Vector3(0.14, 0.12, br_l), mat_rail)
		top_r.position = Vector3(side_x, 0.96, 0.0)
		root.add_child(top_r)
		_attach_box_col(root, Vector3(side_x, 0.52, 0.0), Vector3(0.24, 1.05, br_l), Vector3.ZERO)

		var step_z: float = br_l * 0.35
		for pz_off in [-step_z, 0.0, step_z]:
			var post := _make_box(Vector3(0.16, 1.05, 0.16), mat_rail)
			post.position = Vector3(side_x, 0.52, pz_off)
			root.add_child(post)
			var pier := _make_cyl(0.22, 5.5, assets.mat_creosote)
			pier.position = Vector3(side_x, -2.9, pz_off)
			root.add_child(pier)

	if rkind == WorldBlueprint.RouteKind.RAIL_SPUR:
		for rx in [-0.72, 0.72]:
			var rail := _make_box(Vector3(0.10, 0.14, br_l + 6.0), assets.mat_rusted_iron)
			rail.position = Vector3(rx, 0.07, 0.0)
			root.add_child(rail)

	# Bridge marker post & swaying storm lantern casting golden ripples across river water
	var lpost := _make_cyl(0.07, 2.5, assets.mat_creosote)
	lpost.position = Vector3(-br_w * 0.5 + 0.16, 1.25, br_l * 0.35)
	root.add_child(lpost)
	var larm := _make_box(Vector3(0.55, 0.09, 0.09), assets.mat_dark_wood)
	larm.position = Vector3(-br_w * 0.5 + 0.40, 2.42, br_l * 0.35)
	root.add_child(larm)
	_attach_swaying_lantern(root, Vector3(-br_w * 0.5 + 0.62, 2.38, br_l * 0.35), assets, swaying, flickers, Color(1.0, 0.62, 0.24), 3.6)

	return Vector3(px, deck_y, pz)


static func _build_relay_tower_site(root: Node3D, assets: CascadeAssetBank, beacons: Array, swaying: Array, flickers: Array) -> void:
	var mat_steel: StandardMaterial3D = ForestMaterials.build_dark_metal_material(Color(0.28, 0.30, 0.31), 0.58, 0.85)
	var mat_red: StandardMaterial3D = ForestMaterials.build_dark_metal_material(Color(0.38, 0.14, 0.12), 0.65, 0.65)
	var mat_cable := ForestMaterials.build_dark_metal_material(Color(0.04, 0.04, 0.05), 0.85, 0.4)

	var tower := Node3D.new()
	tower.position = Vector3(4.2, 0.0, -2.6)
	root.add_child(tower)
	_add_box_col(tower, Vector3(0.0, 0.15, 0.0), Vector3(4.2, 0.5, 4.2), assets.mat_concrete)

	var bays: int = 8
	var tower_h: float = 26.0
	var corners: Array[Vector2] = [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
	for b in range(bays):
		var t0: float = float(b) / float(bays)
		var t1: float = float(b + 1) / float(bays)
		var y0: float = 0.25 + t0 * tower_h
		var y1: float = 0.25 + t1 * tower_h
		var r0: float = lerpf(1.45, 0.42, t0)
		var r1: float = lerpf(1.45, 0.42, t1)
		var leg_mat: Material = mat_steel if (b % 2 == 0) else mat_red
		for c in range(4):
			var cn: int = (c + 1) % 4
			var p0 := Vector3(corners[c].x * r0, y0, corners[c].y * r0)
			var p1 := Vector3(corners[c].x * r1, y1, corners[c].y * r1)
			var p1_n := Vector3(corners[cn].x * r1, y1, corners[cn].y * r1)
			_add_strut(tower, p0, p1, 0.065, leg_mat)
			_add_strut(tower, p1, p1_n, 0.036, mat_steel)
			_add_strut(tower, p0, p1_n, 0.025, mat_steel)

	var spire := _make_cyl(0.055, 4.0, mat_steel)
	spire.position = Vector3(0.0, tower_h + 2.1, 0.0)
	tower.add_child(spire)

	var mat_beacon: StandardMaterial3D = ForestMaterials.build_emissive_material(Color(1.0, 0.12, 0.08), 11.0)
	var bulb := MeshInstance3D.new()
	var sph := SphereMesh.new(); sph.radius = 0.28; sph.height = 0.56
	bulb.mesh = sph; bulb.material_override = mat_beacon
	bulb.position = Vector3(0.0, tower_h + 4.2, 0.0)
	tower.add_child(bulb)

	var b_lt := OmniLight3D.new()
	b_lt.position = Vector3(0.0, tower_h + 4.3, 0.0)
	b_lt.light_color = Color(1.0, 0.12, 0.08)
	b_lt.light_energy = 9.0
	b_lt.omni_range = 38.0
	b_lt.shadow_enabled = false
	tower.add_child(b_lt)
	beacons.append({"light": b_lt, "mat": mat_beacon, "base": 9.0})

	# Operator maintenance shack beside tower (slab top = +0.10)
	var shack := Node3D.new()
	shack.position = Vector3(-4.2, 0.0, 1.4)
	shack.rotation.y = 0.85
	root.add_child(shack)
	_build_simple_shack_shell(shack, 4.4, 3.6, 2.75, assets, true)

	_place_gltf(PROPS_BASE + "WoodenTable_01/WoodenTable_01.gltf", shack, "Desk", Vector3(0.85, 0.10, 0.1), Vector3.ZERO, Vector3.ONE * 1.22)
	var desk_top_y: float = 0.77
	_place_gltf(PROPS_HD_BASE + "vintage_radio_transceiver/vintage_radio_transceiver.gltf", shack, "RelayTransceiver", Vector3(0.42, desk_top_y, 0.08), Vector3(0.0, -0.35, 0.0), Vector3.ONE * 1.05)
	_place_gltf(PROPS_BASE + "cassette_player/cassette_player.gltf", shack, "RadioDeck", Vector3(1.08, desk_top_y, 0.16), Vector3(0.0, 0.35, 0.0), Vector3.ONE * 1.3)
	_place_gltf(PROPS_HD_BASE + "vintage_oil_lamp/vintage_oil_lamp.gltf", shack, "DeskOilLamp", Vector3(0.18, desk_top_y, -0.14), Vector3.ZERO, Vector3.ONE * 0.65)
	_place_gltf(PROPS_BASE + "ammo_box/ammo_box.gltf", shack, "ToolCase", Vector3(1.48, desk_top_y, 0.0), Vector3(0.0, -0.4, 0.0), Vector3.ONE * 1.3)
	_place_gltf(PROPS_BASE + "WoodenChair_01/WoodenChair_01.gltf", shack, "OperatorChair", Vector3(0.82, 0.10, -0.58), Vector3(0.0, 0.25, 0.0), Vector3.ONE * 0.36)
	_place_gltf(PROPS_BASE + "caged_hanging_light/caged_hanging_light.gltf", shack, "ShackCeilingLamp", Vector3(0.0, 2.77, 0.0), Vector3.ZERO, Vector3.ONE * 0.72)

	_place_gltf(PROPS_BASE + "Barrel_01/Barrel_01.gltf", shack, "DieselDrum", Vector3(-2.6, 0.0, -0.5), Vector3.ZERO, Vector3.ONE * 1.1)
	_place_gltf(PROPS_HD_BASE + "portable_generator/portable_generator.gltf", shack, "RelayGenerator", Vector3(-2.9, 0.0, 0.6), Vector3(0.0, 0.7, 0.0), Vector3.ONE * 1.2)
	_place_gltf(PROPS_HD_BASE + "power_box_01/power_box_01.gltf", shack, "RelayBreakerBox", Vector3(2.33, 1.45, 0.2), Vector3(0.0, PI * 0.5, 0.0), Vector3.ONE * 1.2)
	_place_gltf(PROPS_HD_BASE + "wooden_military_crate/wooden_military_crate.gltf", root, "TowerCrate", Vector3(1.5, 0.0, -2.5), Vector3(0.0, -0.45, 0.0), Vector3.ONE * 0.85)
	_place_gltf(PROPS_HD_BASE + "utility_box_01/utility_box_01.gltf", tower, "TowerUtilityBox", Vector3(-2.3, 0.0, 1.5), Vector3(0.0, 0.65, 0.0), Vector3.ONE)
	_place_floodlight_stand(root, Vector3(0.2, 0.0, 4.4), 2.55)
	_place_chainlink_run(root, Vector3(1.0, 0.0, -5.6), 4, 0.0)

	_attach_swaying_lantern(shack, Vector3(-1.55, 2.15, 2.05), assets, swaying, flickers, Color(1.0, 0.62, 0.24), 3.6)
	_add_catenary(root, shack.position + Vector3(1.5, 2.6, 0.0), tower.position + Vector3(-1.2, 2.4, 0.0), 0.55, 8, mat_cable)


static func _build_safehouse_cabin(root: Node3D, assets: CascadeAssetBank, elevated_lookout: bool, swaying: Array, flickers: Array) -> void:
	var deck_h: float = 4.2 if elevated_lookout else 0.0
	var deck := Node3D.new()
	deck.position = Vector3(0.0, deck_h, 0.0)
	root.add_child(deck)

	if elevated_lookout:
		for sx in [-2.2, 2.2]:
			for sz in [-1.8, 1.8]:
				var stilt := _make_cyl(0.16, deck_h + 0.6, assets.mat_creosote)
				stilt.position = Vector3(sx, -deck_h * 0.5 - 0.1, sz)
				deck.add_child(stilt)
		# Walkable ramp stairs up to elevated lookout porch
		var ramp_pos := Vector3(-1.2, -deck_h * 0.5, 4.4)
		var r_pitch: float = atan2(deck_h, 5.2)
		var ramp_mesh := _make_box(Vector3(1.4, 0.18, 6.6), assets.mat_plank)
		ramp_mesh.position = ramp_pos
		ramp_mesh.rotation.x = r_pitch
		deck.add_child(ramp_mesh)
		_attach_box_col(deck, ramp_pos, Vector3(1.4, 0.20, 6.6), Vector3(r_pitch, 0.0, 0.0))

	_build_simple_shack_shell(deck, 4.8, 4.0, 2.85, assets, true)
	var pipe := _make_cyl(0.11, 1.4, assets.mat_rusted_iron)
	pipe.position = Vector3(-1.5, 3.65, -1.1)
	deck.add_child(pipe)

	_place_gltf(PROPS_BASE + "WoodenTable_01/WoodenTable_01.gltf", deck, "CabinTable", Vector3(1.0, 0.10, -0.4), Vector3.ZERO, Vector3.ONE * 1.20)
	var cab_top: float = 0.759
	_place_gltf(PROPS_HD_BASE + "vintage_oil_lamp/vintage_oil_lamp.gltf", deck, "CabinOilLamp", Vector3(1.25, cab_top, -0.42), Vector3.ZERO, Vector3.ONE * 0.65)
	_place_gltf(PROPS_BASE + "cassette_player/cassette_player.gltf", deck, "CabinTape", Vector3(0.68, cab_top, -0.35), Vector3(0.0, 0.35, 0.0), Vector3.ONE * 1.25)
	_place_gltf(PROPS_HD_BASE + "medical_box/medical_box.gltf", deck, "CabinFirstAid", Vector3(-1.45, 0.10, -1.2), Vector3(0.0, 0.4, 0.0), Vector3.ONE)
	_place_gltf(PROPS_BASE + "WoodenChair_01/WoodenChair_01.gltf", deck, "CabinChair", Vector3(0.45, 0.10, -0.88), Vector3(0.0, 0.5, 0.0), Vector3.ONE * 0.36)
	_place_gltf(PROPS_BASE + "caged_hanging_light/caged_hanging_light.gltf", deck, "CabinCeilingLamp", Vector3(0.0, 2.87, 0.0), Vector3.ZERO, Vector3.ONE * 0.72)
	_place_gltf(PROPS_HD_BASE + "portable_generator/portable_generator.gltf", root, "CabinGen", Vector3(-3.3, 0.0, 0.8), Vector3(0.0, 0.9, 0.0), Vector3.ONE * 1.15)
	_place_kenney(KENNEY_BASE + "log_stackLarge.glb", root, "FirewoodStack", Vector3(3.1, 0.13, 0.2), Vector3(0.0, PI * 0.5, 0.0), Vector3.ONE * 2.6, assets.mat_creosote)
	_attach_swaying_lantern(deck, Vector3(-1.55, 2.20, 2.25), assets, swaying, flickers, Color(1.0, 0.64, 0.28), 3.4)


static func _build_industrial_hub(root: Node3D, site: Dictionary, assets: CascadeAssetBank, flickers: Array) -> void:
	# Large concrete yard apron (slab top = +0.15) + open-bay corrugated mill shed + stacked timber + barrels
	_add_box_col(root, Vector3(0.0, -0.05, 0.0), Vector3(16.0, 0.40, 14.0), assets.mat_concrete)

	# Warehouse steel/wood bays (open front & back for exploration)
	_add_box_col(root, Vector3(-5.8, 2.6, 0.0), Vector3(0.24, 5.2, 11.5), assets.mat_corrugated)
	_add_box_col(root, Vector3(5.8, 2.6, 0.0), Vector3(0.24, 5.2, 11.5), assets.mat_corrugated)
	_add_box_col(root, Vector3(0.0, 5.3, 0.0), Vector3(12.4, 0.18, 12.2), assets.mat_corrugated)

	for lx in [-3.4, 3.4]:
		_place_kenney(KENNEY_BASE + "log_stackLarge.glb", root, "HubLogPile_%d" % int(lx), Vector3(lx, 0.31, -3.0), Vector3.ZERO, Vector3.ONE * 3.2, assets.mat_plank)
	_place_gltf(PROPS_BASE + "Barrel_01/Barrel_01.gltf", root, "HubFuel_A", Vector3(-4.4, 0.15, 3.6), Vector3.ZERO, Vector3.ONE * 1.2)
	_place_gltf(PROPS_BASE + "barrel_03/barrel_03.gltf", root, "HubFuel_B", Vector3(-3.6, 0.15, 4.1), Vector3(0.0, 1.2, 0.0), Vector3.ONE * 1.15)
	_place_gltf(PROPS_BASE + "WoodenTable_01/WoodenTable_01.gltf", root, "WorkBench", Vector3(4.1, 0.15, 3.2), Vector3(0.0, -0.4, 0.0), Vector3.ONE * 1.35)
	_place_gltf(PROPS_HD_BASE + "metal_toolbox/metal_toolbox.gltf", root, "HubToolbox", Vector3(4.2, 0.89, 3.2), Vector3(0.0, 0.2, 0.0), Vector3.ONE)
	_place_gltf(PROPS_HD_BASE + "portable_generator/portable_generator.gltf", root, "HubGen", Vector3(-4.2, 0.15, 1.4), Vector3(0.0, 1.1, 0.0), Vector3.ONE * 1.35)
	_place_gltf(PROPS_HD_BASE + "wooden_military_crate/wooden_military_crate.gltf", root, "HubCrate", Vector3(4.4, 0.15, 0.4), Vector3(0.0, 1.5, 0.0), Vector3.ONE)
	_place_gltf(PROPS_HD_BASE + "utility_box_01/utility_box_01.gltf", root, "HubSwitchgear", Vector3(-5.55, 0.15, -0.8), Vector3(0.0, PI * 0.5, 0.0), Vector3.ONE * 1.1)
	_place_gltf(PROPS_HD_BASE + "covered_car/covered_car.gltf", root, "HubCoveredCar", Vector3(0.4, 0.15, 4.2), Vector3(0.0, 0.35, 0.0), Vector3.ONE)
	_place_floodlight_stand(root, Vector3(6.8, 0.15, 5.2), -0.6)

	if str(site["name"]).contains("Rail"):
		# Rusted derailed boxcar shell on spur yard
		var car := _make_box(Vector3(3.1, 3.2, 10.5), assets.mat_rusted_iron)
		car.position = Vector3(-9.5, 1.65, -2.0)
		car.rotation = Vector3(0.03, 0.15, 0.14)
		root.add_child(car)
		_attach_box_col(root, car.position, Vector3(3.1, 3.2, 10.5), car.rotation)

	var cage := OmniLight3D.new()
	cage.position = Vector3(0.0, 4.7, 0.0)
	cage.light_color = Color(0.88, 0.94, 0.98)
	cage.light_energy = 2.8
	cage.omni_range = 16.0
	cage.shadow_enabled = false
	root.add_child(cage)
	flickers.append({"light": cage, "base": 2.8, "speed": 9.2, "phase": 2.4})


static func _build_quarantine_gate(root: Node3D, assets: CascadeAssetBank, flickers: Array) -> void:
	# Concrete checkpoints + overhead truss beam + jersey barriers + chainlink perimeter + guard booth
	_add_box_col(root, Vector3(-4.2, 1.8, 0.0), Vector3(0.65, 3.6, 0.65), assets.mat_concrete)
	_add_box_col(root, Vector3(4.2, 1.8, 0.0), Vector3(0.65, 3.6, 0.65), assets.mat_concrete)
	_add_box_col(root, Vector3(0.0, 3.85, 0.0), Vector3(9.4, 0.55, 0.55), assets.mat_rusted_iron)

	_build_simple_shack_shell(root, 2.6, 2.4, 2.55, assets, false)
	_place_gltf(PROPS_HD_BASE + "power_box_01/power_box_01.gltf", root, "GatePowerBox", Vector3(1.43, 1.35, 0.0), Vector3(0.0, PI * 0.5, 0.0), Vector3.ONE * 1.15)
	_place_gltf(PROPS_HD_BASE + "concrete_road_barrier_02/concrete_road_barrier_02.gltf", root, "GateJersey_L", Vector3(-2.6, 0.0, 2.1), Vector3(0.0, 0.25, 0.0), Vector3.ONE)
	_place_gltf(PROPS_HD_BASE + "concrete_road_barrier_02/concrete_road_barrier_02.gltf", root, "GateJersey_R", Vector3(2.4, 0.0, 2.3), Vector3(0.0, -0.32, 0.0), Vector3.ONE)
	_place_gltf(PROPS_HD_BASE + "utility_box_01/utility_box_01.gltf", root, "GateUtility", Vector3(-3.3, 0.0, 0.4), Vector3.ZERO, Vector3.ONE)
	_place_gltf(PROPS_HD_BASE + "covered_car/covered_car.gltf", root, "GateAbandonedCar", Vector3(-0.2, 0.0, 5.6), Vector3(0.0, 0.14, 0.0), Vector3.ONE)
	_place_chainlink_run(root, Vector3(-7.6, 0.0, 0.4), 2, 0.0)
	_place_chainlink_run(root, Vector3(4.6, 0.0, 0.4), 2, 0.0)
	_place_kenney(KENNEY_BASE + "sign.glb", root, "QuarantineStopSign", Vector3(4.8, 0.16, 1.6), Vector3(0.0, -0.45, 0.0), Vector3.ONE * 3.2, assets.mat_dark_wood)
	_place_gltf(PROPS_BASE + "Barrel_01/Barrel_01.gltf", root, "GateDrum", Vector3(3.1, 0.0, 1.4), Vector3.ZERO, Vector3.ONE * 1.15)

	var amber := OmniLight3D.new()
	amber.position = Vector3(0.0, 3.4, 0.4)
	amber.light_color = Color(1.0, 0.52, 0.14)
	amber.light_energy = 2.6
	amber.omni_range = 14.0
	amber.shadow_enabled = false
	root.add_child(amber)
	flickers.append({"light": amber, "base": 2.6, "speed": 2.4, "phase": 0.9})


static func _build_tunnel_portal(root: Node3D, assets: CascadeAssetBank, flickers: Array) -> void:
	# Reinforced concrete portal bunker set against hillside + heavy blast bulkhead
	_add_box_col(root, Vector3(0.0, 2.2, -1.6), Vector3(6.8, 4.4, 3.2), assets.mat_concrete)
	var recess := _make_box(Vector3(3.2, 3.0, 0.4), ForestMaterials.build_dark_metal_material(Color(0.03, 0.03, 0.04), 0.9, 0.2))
	recess.position = Vector3(0.0, 1.5, 0.02)
	root.add_child(recess)
	_add_box_col(root, Vector3(0.0, 1.5, 0.18), Vector3(2.8, 2.8, 0.20), assets.mat_rusted_iron) # Sealed/locked door
	_place_gltf(PROPS_HD_BASE + "concrete_road_barrier_02/concrete_road_barrier_02.gltf", root, "TunnelBarrier", Vector3(1.2, 0.0, 2.4), Vector3(0.0, -0.25, 0.0), Vector3.ONE)
	_place_gltf(PROPS_HD_BASE + "utility_box_01/utility_box_01.gltf", root, "TunnelUtility", Vector3(-2.6, 0.0, 0.6), Vector3.ZERO, Vector3.ONE)
	_place_gltf(PROPS_HD_BASE + "metal_toolbox/metal_toolbox.gltf", root, "TunnelTools", Vector3(2.1, 0.0, 1.1), Vector3(0.0, 0.6, 0.0), Vector3.ONE * 1.1)
	_place_gltf(PROPS_BASE + "barrel_03/barrel_03.gltf", root, "TunnelDrum", Vector3(-2.1, 0.0, 1.6), Vector3.ZERO, Vector3.ONE * 1.15)
	_place_floodlight_stand(root, Vector3(3.1, 0.0, 2.8), 2.55)

	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0.0, 3.2, 0.65)
	lamp.light_color = Color(0.95, 0.48, 0.22)
	lamp.light_energy = 1.9
	lamp.omni_range = 10.5
	lamp.shadow_enabled = false
	root.add_child(lamp)
	flickers.append({"light": lamp, "base": 1.9, "speed": 5.8, "phase": 1.7})


static func _build_campsite(root: Node3D, site_id: int, assets: CascadeAssetBank, beacons: Array, flickers: Array) -> void:
	var mat_tent_a := ForestMaterials.build_canvas_material(Color(0.22, 0.26, 0.18))
	var mat_tent_b := ForestMaterials.build_canvas_material(Color(0.14, 0.17, 0.12))
	_place_kenney_mapped(KENNEY_BASE + "tent_smallOpen.glb", root, "CampTent", Vector3(2.0, 0.155, -1.2), Vector3(0.0, -0.75, 0.0), Vector3.ONE * 3.1, {"colorRed": mat_tent_a, "colorRedDark": mat_tent_b, "wood": assets.mat_dark_wood})
	_place_kenney(KENNEY_BASE + "campfire_stones.glb", root, "FireRing", Vector3(-0.5, 0.125, 0.8), Vector3.ZERO, Vector3.ONE * 2.5, assets.mat_concrete)
	_place_kenney(KENNEY_BASE + "campfire_logs.glb", root, "FireLogs", Vector3(-0.5, 0.185, 0.8), Vector3.ZERO, Vector3.ONE * 2.5, assets.mat_creosote)
	_place_gltf(PROPS_HD_BASE + "wooden_military_crate/wooden_military_crate.gltf", root, "CampCrate", Vector3(-1.8, 0.0, 2.2), Vector3(0.0, 0.55, 0.0), Vector3.ONE * 0.82)
	_place_gltf(PROPS_HD_BASE + "medical_box/medical_box.gltf", root, "CampMedBox", Vector3(0.8, 0.02, -0.6), Vector3(0.0, -0.3, 0.0), Vector3.ONE)
	_place_gltf(PROPS_HD_BASE + "vintage_oil_lamp/vintage_oil_lamp.gltf", root, "CampLamp", Vector3(1.1, 0.02, 0.4), Vector3.ZERO, Vector3.ONE * 0.72)
	_place_gltf(PROPS_BASE + "barrel_03/barrel_03.gltf", root, "CampDrum", Vector3(-2.6, 0.0, -1.2), Vector3.ZERO, Vector3.ONE * 1.1)

	if site_id % 2 == 1:
		# Decoy camp emitting faint red beacon static whip antenna
		var pole := _make_cyl(0.04, 3.8, assets.mat_rusted_iron)
		pole.position = Vector3(1.1, 1.9, 1.8)
		root.add_child(pole)
		var mat_led := ForestMaterials.build_emissive_material(Color(1.0, 0.14, 0.10), 7.5)
		var tip := _make_box(Vector3(0.14, 0.14, 0.14), mat_led)
		tip.position = Vector3(1.1, 3.85, 1.8)
		root.add_child(tip)
		var lt := OmniLight3D.new()
		lt.position = Vector3(1.1, 3.9, 1.8)
		lt.light_color = Color(1.0, 0.14, 0.10)
		lt.light_energy = 2.4
		lt.omni_range = 14.0
		lt.shadow_enabled = false
		root.add_child(lt)
		beacons.append({"light": lt, "mat": mat_led, "base": 2.4})
	else:
		var ember := OmniLight3D.new()
		ember.position = Vector3(-0.5, 0.4, 0.8)
		ember.light_color = Color(1.0, 0.45, 0.14)
		ember.light_energy = 1.4
		ember.omni_range = 8.0
		ember.shadow_enabled = false
		root.add_child(ember)
		flickers.append({"light": ember, "base": 1.4, "speed": 3.5, "phase": float(site_id)})


static func _build_finale_cache(root: Node3D, assets: CascadeAssetBank, beacons: Array, flickers: Array) -> void:
	# Emergency Forestry HF Survey Cache (>= 10.5km distant finale bunker/tent, slab top = +0.175)
	_add_box_col(root, Vector3(0.0, 0.0, 0.0), Vector3(7.6, 0.35, 7.6), assets.mat_concrete)
	var mat_tarp := ForestMaterials.build_canvas_material(Color(0.18, 0.24, 0.16), Vector2(2.4, 2.4))
	for cx in [-2.6, 2.6]:
		for cz in [-2.6, 2.6]:
			var post := _make_cyl(0.09, 3.0, assets.mat_rusted_iron)
			post.position = Vector3(cx, 1.5, cz)
			root.add_child(post)
	var roof := _make_box(Vector3(5.8, 0.14, 5.8), mat_tarp)
	roof.position = Vector3(0.0, 3.05, 0.0)
	root.add_child(roof)

	_place_gltf(PROPS_BASE + "WoodenTable_01/WoodenTable_01.gltf", root, "HFConsoleDesk", Vector3(0.0, 0.175, -0.8), Vector3.ZERO, Vector3.ONE * 1.4)
	var hf_top: float = 0.944
	_place_gltf(PROPS_HD_BASE + "vintage_radio_transceiver/vintage_radio_transceiver.gltf", root, "HFTransceiver", Vector3(-0.35, hf_top, -0.8), Vector3.ZERO, Vector3.ONE * 1.35)
	_place_gltf(PROPS_BASE + "cassette_player/cassette_player.gltf", root, "HFRecorder", Vector3(0.55, hf_top, -0.78), Vector3(0.0, -0.35, 0.0), Vector3.ONE * 1.4)
	_place_gltf(PROPS_HD_BASE + "vintage_oil_lamp/vintage_oil_lamp.gltf", root, "HFLamp", Vector3(-1.05, hf_top, -0.88), Vector3.ZERO, Vector3.ONE * 0.72)
	_place_gltf(PROPS_HD_BASE + "portable_generator/portable_generator.gltf", root, "CacheGen", Vector3(-2.4, 0.175, 2.2), Vector3(0.0, 0.4, 0.0), Vector3.ONE * 1.3)
	_place_gltf(PROPS_HD_BASE + "power_box_01/power_box_01.gltf", root, "CachePowerBox", Vector3(2.68, 1.45, -2.6), Vector3(0.0, -PI * 0.5, 0.0), Vector3.ONE * 1.2)
	_place_gltf(PROPS_HD_BASE + "wooden_military_crate/wooden_military_crate.gltf", root, "CacheMilCrate", Vector3(2.1, 0.175, -1.6), Vector3(0.0, 0.35, 0.0), Vector3.ONE)
	_place_gltf(PROPS_HD_BASE + "medical_box/medical_box.gltf", root, "CacheMedKit", Vector3(2.2, 0.64, -1.6), Vector3(0.0, -0.4, 0.0), Vector3.ONE)
	_place_gltf(PROPS_BASE + "Barrel_01/Barrel_01.gltf", root, "CacheDiesel_A", Vector3(-2.0, 0.175, 1.1), Vector3.ZERO, Vector3.ONE * 1.15)
	_place_gltf(PROPS_BASE + "ammo_box/ammo_box.gltf", root, "CacheEquipment", Vector3(1.8, 0.175, 1.4), Vector3.ZERO, Vector3.ONE * 1.5)
	_place_chainlink_run(root, Vector3(-3.8, 0.0, -4.4), 4, 0.0)

	var mast := _make_cyl(0.07, 11.5, assets.mat_rusted_iron)
	mast.position = Vector3(2.8, 5.75, -2.6)
	root.add_child(mast)
	var mat_glow := ForestMaterials.build_emissive_material(Color(0.18, 1.0, 0.65), 10.0)
	var beacon_bulb := _make_box(Vector3(0.25, 0.25, 0.25), mat_glow)
	beacon_bulb.position = Vector3(2.8, 11.6, -2.6)
	root.add_child(beacon_bulb)
	var beacon_lt := OmniLight3D.new()
	beacon_lt.position = Vector3(2.8, 11.7, -2.6)
	beacon_lt.light_color = Color(0.18, 1.0, 0.65)
	beacon_lt.light_energy = 7.5
	beacon_lt.omni_range = 32.0
	beacon_lt.shadow_enabled = false
	root.add_child(beacon_lt)
	beacons.append({"light": beacon_lt, "mat": mat_glow, "base": 7.5})

	var work_lt := OmniLight3D.new()
	work_lt.position = Vector3(0.0, 2.5, 0.0)
	work_lt.light_color = Color(1.0, 0.86, 0.56)
	work_lt.light_energy = 3.2
	work_lt.omni_range = 12.0
	work_lt.shadow_enabled = false
	root.add_child(work_lt)
	flickers.append({"light": work_lt, "base": 3.2, "speed": 2.8, "phase": 0.2})


static func _build_simple_shack_shell(parent: Node3D, w: float, d: float, h: float, assets: CascadeAssetBank, open_doorway: bool) -> void:
	_add_box_col(parent, Vector3(0.0, -0.08, 0.25), Vector3(w + 0.6, 0.36, d + 0.9), assets.mat_concrete)
	var wh: float = h + 0.22
	_add_box_col(parent, Vector3(0.0, wh * 0.5, -d * 0.5), Vector3(w, wh, 0.16), assets.mat_plank)
	_add_box_col(parent, Vector3(-w * 0.5, wh * 0.5, 0.0), Vector3(0.16, wh, d), assets.mat_plank)
	_add_box_col(parent, Vector3(w * 0.5, wh * 0.5, 0.0), Vector3(0.16, wh, d), assets.mat_plank)
	if open_doorway:
		_add_box_col(parent, Vector3(-w * 0.34, wh * 0.5, d * 0.5), Vector3(w * 0.32, wh, 0.16), assets.mat_plank)
		_add_box_col(parent, Vector3(w * 0.28, wh * 0.5, d * 0.5), Vector3(w * 0.44, wh, 0.16), assets.mat_plank)
		_add_box_col(parent, Vector3(-0.08, wh - 0.38, d * 0.5), Vector3(w * 0.32, 0.76, 0.16), assets.mat_plank)
	else:
		_add_box_col(parent, Vector3(0.0, wh * 0.5, d * 0.5), Vector3(w, wh, 0.16), assets.mat_plank)
	var roof := _make_box(Vector3(w + 0.75, 0.10, d + 1.25), assets.mat_corrugated)
	roof.position = Vector3(0.0, h + 0.04, 0.20)
	roof.rotation.x = 0.12
	parent.add_child(roof)


static func _attach_swaying_lantern(parent: Node3D, hook_pos: Vector3, _assets: CascadeAssetBank, swaying: Array, flickers: Array, col: Color, energy: float) -> void:
	var hook := Node3D.new()
	hook.position = hook_pos
	parent.add_child(hook)
	var ps: PackedScene = load(PROPS_BASE + "Lantern_01/Lantern_01.gltf")
	if ps != null:
		var ln: Node3D = ps.instantiate() as Node3D
		ln.scale = Vector3.ONE * 1.2
		ln.position = Vector3(0.0, -0.35, 0.0)
		var mat_g: StandardMaterial3D = ForestMaterials.build_emissive_material(col, 4.0)
		_glow_lantern_glass(ln, mat_g)
		hook.add_child(ln)
	var lt := OmniLight3D.new()
	lt.position = Vector3(0.0, -0.25, 0.0)
	lt.light_color = col
	lt.light_energy = energy
	lt.omni_range = 14.0
	lt.shadow_enabled = false
	hook.add_child(lt)
	swaying.append({"node": hook, "speed": 1.25, "amp": 0.05, "phase": hook_pos.x})
	flickers.append({"light": lt, "base": energy, "speed": 5.2, "phase": hook_pos.z})


static func _glow_lantern_glass(n: Node, mat: Material) -> void:
	for c in n.get_children():
		_glow_lantern_glass(c, mat)
		if c is MeshInstance3D and str(c.name).contains("glass"):
			(c as MeshInstance3D).material_override = mat


static func _glow_oil_lamp(n: Node, flame_mat: Material) -> void:
	var clear_glass := StandardMaterial3D.new()
	clear_glass.albedo_color = Color(0.86, 0.90, 0.94, 0.24)
	clear_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	clear_glass.roughness = 0.08
	clear_glass.metallic_specular = 0.92
	for c in n.get_children():
		_glow_oil_lamp(c, flame_mat)
		if c is MeshInstance3D:
			if str(c.name).contains("flame"):
				(c as MeshInstance3D).material_override = flame_mat
			elif str(c.name).contains("glass"):
				(c as MeshInstance3D).material_override = clear_glass


static func _place_gltf(path: String, parent: Node3D, node_name: String, pos: Vector3, rot: Vector3, sc: Vector3) -> void:
	var ps: PackedScene = load(path)
	if ps == null:
		return
	var n: Node3D = ps.instantiate() as Node3D
	n.name = node_name
	n.position = pos
	n.rotation = rot
	n.scale = sc
	if path.contains("Barrel_01") or path.contains("barrel_03") or path.contains("Wooden"):
		_darken_subtree(n, 0.48)
	if path.contains("vintage_oil_lamp"):
		_glow_oil_lamp(n, ForestMaterials.build_emissive_material(Color(1.0, 0.58, 0.16), 7.5))
	parent.add_child(n)


static func _darken_subtree(n: Node, factor: float) -> void:
	for c in n.get_children():
		_darken_subtree(c, factor)
	if n is MeshInstance3D:
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.mesh != null:
			for s in range(mi.mesh.get_surface_count()):
				var src: Material = mi.get_active_material(s)
				if src != null:
					mi.set_surface_override_material(s, ForestMaterials.darken_material_for_night(src, factor, false))


static func _place_kenney(path: String, parent: Node3D, node_name: String, pos: Vector3, rot: Vector3, sc: Vector3, fallback_mat: Material) -> void:
	var ps: PackedScene = load(path)
	if ps == null:
		return
	var n: Node3D = ps.instantiate() as Node3D
	n.name = node_name
	n.position = pos
	n.rotation = rot
	n.scale = sc
	_apply_fallback_mat(n, fallback_mat)
	parent.add_child(n)


static func _place_kenney_mapped(path: String, parent: Node3D, node_name: String, pos: Vector3, rot: Vector3, sc: Vector3, mat_map: Dictionary) -> void:
	var ps: PackedScene = load(path)
	if ps == null:
		return
	var n: Node3D = ps.instantiate() as Node3D
	n.name = node_name
	n.position = pos
	n.rotation = rot
	n.scale = sc
	_apply_mapped_mat(n, mat_map)
	parent.add_child(n)


static func _apply_mapped_mat(n: Node, mat_map: Dictionary) -> void:
	for c in n.get_children():
		_apply_mapped_mat(c, mat_map)
		if c is MeshInstance3D:
			var mi: MeshInstance3D = c as MeshInstance3D
			if mi.mesh != null:
				for s in range(mi.mesh.get_surface_count()):
					var sname: String = mi.mesh.surface_get_name(s)
					if mat_map.has(sname):
						mi.set_surface_override_material(s, mat_map[sname])


static func _apply_fallback_mat(n: Node, mat: Material) -> void:
	for c in n.get_children():
		_apply_fallback_mat(c, mat)
		if c is MeshInstance3D:
			var mi: MeshInstance3D = c as MeshInstance3D
			if mi.mesh != null:
				for s in range(mi.mesh.get_surface_count()):
					mi.set_surface_override_material(s, mat)


static func _place_chainlink_run(parent: Node3D, start_pos: Vector3, segments: int, yaw: float) -> void:
	var panel_mesh: ArrayMesh = ForestMaterials.extract_gltf_kit_mesh(PROPS_HD_BASE + "modular_chainlink_fence/modular_chainlink_fence.gltf", ["modular_chainlink_fence_double"], Vector3.ZERO, true, true, 0.0)
	if panel_mesh == null:
		return
	var holder := Node3D.new()
	holder.name = "ChainlinkPerimeter"
	holder.position = start_pos
	holder.rotation.y = yaw
	parent.add_child(holder)
	for i in range(segments):
		var mi := MeshInstance3D.new()
		mi.mesh = panel_mesh
		mi.position = Vector3(float(i) * 1.92, 0.0, 0.0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.gi_mode = GeometryInstance3D.GI_MODE_STATIC
		holder.add_child(mi)


static func _place_floodlight_stand(parent: Node3D, pos: Vector3, yaw: float) -> void:
	var holder := Node3D.new()
	holder.name = "YardFloodStand"
	holder.position = pos
	holder.rotation.y = yaw
	parent.add_child(holder)
	var stand_mesh: ArrayMesh = ForestMaterials.extract_gltf_kit_mesh(PROPS_BASE + "flood_lights/flood_lights.gltf", ["flood_lights_standing_double_c_*"], Vector3.ZERO, true, true, 0.0)
	if stand_mesh != null:
		var mi := MeshInstance3D.new()
		mi.mesh = stand_mesh
		holder.add_child(mi)
	var spot := SpotLight3D.new()
	spot.position = Vector3(0.0, 1.48, 0.08)
	spot.rotation_degrees = Vector3(14.0, 180.0, 0.0)
	spot.light_color = Color(0.95, 0.96, 1.0)
	spot.light_energy = 5.5
	spot.spot_range = 24.0
	spot.spot_angle = 46.0
	spot.shadow_enabled = false
	holder.add_child(spot)


static func _make_box(size: Vector3, mat: Material) -> MeshInstance3D:
	var bm := BoxMesh.new(); bm.size = size
	var mi := MeshInstance3D.new(); mi.mesh = bm; mi.material_override = mat
	mi.gi_mode = GeometryInstance3D.GI_MODE_STATIC
	return mi


static func _make_cyl(radius: float, height: float, mat: Material) -> MeshInstance3D:
	var cm := CylinderMesh.new(); cm.top_radius = radius; cm.bottom_radius = radius; cm.height = height; cm.radial_segments = 8
	var mi := MeshInstance3D.new(); mi.mesh = cm; mi.material_override = mat
	mi.gi_mode = GeometryInstance3D.GI_MODE_STATIC
	return mi


static func _add_box_col(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> void:
	var mi := _make_box(size, mat)
	mi.position = pos
	parent.add_child(mi)
	_attach_box_col(parent, pos, size, Vector3.ZERO)


static func _attach_box_col(parent: Node3D, pos: Vector3, size: Vector3, rot: Vector3) -> void:
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new(); bs.size = size
	cs.shape = bs; cs.position = pos; cs.rotation = rot
	sb.add_child(cs)
	parent.add_child(sb)


static func _add_strut(parent: Node3D, a: Vector3, b: Vector3, radius: float, mat: Material) -> void:
	var diff: Vector3 = b - a
	var length: float = diff.length()
	if length < 0.001:
		return
	var mi := _make_cyl(radius, length, mat)
	mi.position = (a + b) * 0.5
	var up: Vector3 = diff / length
	var ref: Vector3 = Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT
	var right: Vector3 = ref.cross(up).normalized()
	var fwd: Vector3 = right.cross(up).normalized()
	mi.transform.basis = Basis(right, up, fwd)
	parent.add_child(mi)


static func _add_catenary(parent: Node3D, a: Vector3, b: Vector3, sag: float, segments: int, mat: Material) -> void:
	var prev: Vector3 = a
	for i in range(1, segments + 1):
		var t: float = float(i) / float(segments)
		var p: Vector3 = a.lerp(b, t)
		p.y -= 4.0 * sag * t * (1.0 - t)
		_add_strut(parent, prev, p, 0.016, mat)
		prev = p
