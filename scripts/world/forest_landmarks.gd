class_name ForestLandmarks
extends RefCounted

const PROPS_BASE: String = "res://assets/models/props/"
const PROPS_HD_BASE: String = "res://assets/models/props_hd/"
const KENNEY_BASE: String = "res://assets/models/kenney/"


static func build_all(terrain: ForestTerrainData, parent: Node3D) -> Dictionary:
	var root := Node3D.new()
	root.name = "ForestLandmarksAndOutpost"
	parent.add_child(root)

	var animated: Dictionary = {
		"beacons": [],
		"swaying_lanterns": [],
		"flicker_lights": []
	}

	_build_creek_bridge_and_signs(terrain, root, animated)
	_build_utility_power_line(terrain, root, animated)
	_build_trail_lantern_posts(terrain, root, animated)
	_build_relay_outpost(terrain, root, animated)
	_build_abandoned_campsite(terrain, root, animated)

	return animated


static func _build_creek_bridge_and_signs(terrain: ForestTerrainData, parent: Node3D, _animated: Dictionary) -> void:
	var bz: float = ForestTerrainData.CREEK_Z_BASE
	var bx: float = terrain.get_trail_center_x(bz)
	var dx_dz: float = (terrain.get_trail_center_x(bz + 2.0) - terrain.get_trail_center_x(bz - 2.0)) * 0.25
	var south_bank_y: float = terrain.get_height(terrain.get_trail_center_x(bz + 6.4), bz + 6.4)
	var north_bank_y: float = terrain.get_height(terrain.get_trail_center_x(bz - 6.4), bz - 6.4)
	var deck_y: float = maxf(terrain.get_creek_water_level() + 0.85, maxf(south_bank_y, north_bank_y) + 0.18)

	var bridge_root := Node3D.new()
	bridge_root.name = "CreekTimberBridge"
	bridge_root.position = Vector3(bx, deck_y, bz)
	bridge_root.rotation.y = atan2(dx_dz, 1.0)
	parent.add_child(bridge_root)

	var mat_planks: StandardMaterial3D = ForestMaterials.load_pbr_material("brown_planks_03", Vector2(2.0, 2.0), Color(0.64, 0.60, 0.56))
	var mat_bark: StandardMaterial3D = ForestMaterials.load_pbr_material("knotted_pine_bark", Vector2(1.5, 2.5), Color(0.50, 0.47, 0.45))

	const BR_W: float = 3.8
	const BR_L: float = 7.6

	var main_deck := _make_box_mesh(Vector3(BR_W, 0.18, BR_L), mat_planks)
	main_deck.position = Vector3(0.0, -0.09, 0.0)
	bridge_root.add_child(main_deck)

	for x_beam in [-1.55, 0.0, 1.55]:
		var beam := _make_box_mesh(Vector3(0.24, 0.28, BR_L + 0.4), mat_bark)
		beam.position = Vector3(x_beam, -0.30, 0.0)
		bridge_root.add_child(beam)

	for end_sign in [-1.0, 1.0]:
		var local_lip := Vector3(0.0, 0.0, end_sign * (BR_L * 0.5))
		var tip_world_approx: Vector3 = bridge_root.position + (Basis(Vector3.UP, bridge_root.rotation.y) * Vector3(0.0, 0.0, end_sign * (BR_L * 0.5 + 2.8)))
		var tip_ground_y: float = terrain.get_height(tip_world_approx.x, tip_world_approx.z) - 0.18
		var local_tip_y: float = tip_ground_y - deck_y
		var local_tip := Vector3(0.0, local_tip_y, end_sign * (BR_L * 0.5 + 2.8))
		var delta_v: Vector3 = local_tip - local_lip
		var ramp_len: float = delta_v.length()
		var slope_pitch: float = atan2(local_tip_y, 2.8) * (-end_sign)

		var ramp := _make_box_mesh(Vector3(BR_W, 0.18, ramp_len + 0.15), mat_planks)
		ramp.position = (local_lip + local_tip) * 0.5 + Vector3(0.0, -0.09, 0.0)
		ramp.rotation.x = slope_pitch
		bridge_root.add_child(ramp)

		var ramp_body := StaticBody3D.new()
		var ramp_col := CollisionShape3D.new()
		var ramp_box := BoxShape3D.new()
		ramp_box.size = Vector3(BR_W, 0.22, ramp_len + 0.2)
		ramp_col.shape = ramp_box
		ramp_col.position = ramp.position
		ramp_col.rotation = ramp.rotation
		ramp_body.add_child(ramp_col)
		bridge_root.add_child(ramp_body)

	for side_x in [-BR_W * 0.5 + 0.12, BR_W * 0.5 - 0.12]:
		var curb := _make_box_mesh(Vector3(0.20, 0.16, BR_L), mat_bark)
		curb.position = Vector3(side_x, 0.08, 0.0)
		bridge_root.add_child(curb)

		var top_rail := _make_box_mesh(Vector3(0.11, 0.10, BR_L + 0.2), mat_planks)
		top_rail.position = Vector3(side_x, 0.94, 0.0)
		bridge_root.add_child(top_rail)

		var mid_rail := _make_box_mesh(Vector3(0.09, 0.08, BR_L + 0.2), mat_planks)
		mid_rail.position = Vector3(side_x, 0.52, 0.0)
		bridge_root.add_child(mid_rail)

		for pz in [-3.8, -1.9, 0.0, 1.9, 3.8]:
			var rpost := _make_box_mesh(Vector3(0.14, 1.05, 0.14), mat_bark)
			rpost.position = Vector3(side_x, 0.52, pz)
			bridge_root.add_child(rpost)

		var rail_sb := StaticBody3D.new()
		var rail_cs := CollisionShape3D.new()
		var rail_bs := BoxShape3D.new()
		rail_bs.size = Vector3(0.24, 1.05, BR_L + 0.2)
		rail_cs.shape = rail_bs
		rail_cs.position = Vector3(side_x, 0.52, 0.0)
		rail_sb.add_child(rail_cs)
		bridge_root.add_child(rail_sb)

	for x_side in [-1.68, 1.68]:
		for z_pier in [-3.6, -1.2, 1.2, 3.6]:
			var pier := _make_cylinder_mesh(0.16, 4.0, mat_bark)
			pier.position = Vector3(x_side, -2.05, z_pier)
			bridge_root.add_child(pier)

	var deck_body := StaticBody3D.new()
	var deck_col := CollisionShape3D.new()
	var deck_box := BoxShape3D.new()
	deck_box.size = Vector3(BR_W, 0.22, BR_L)
	deck_col.shape = deck_box
	deck_col.position = Vector3(0.0, -0.11, 0.0)
	deck_body.add_child(deck_col)
	bridge_root.add_child(deck_body)

	var sign_ps: PackedScene = load(KENNEY_BASE + "sign.glb")
	if sign_ps != null:
		var sx: float = terrain.get_trail_center_x(40.5) + 2.35
		var sz: float = 40.5
		var snode: Node3D = sign_ps.instantiate() as Node3D
		snode.name = "BridgeWarningSign"
		snode.position = Vector3(sx, terrain.get_height(sx, sz) + 0.11, sz)
		snode.scale = Vector3.ONE * 3.1
		snode.rotation = Vector3(0.04, -0.55, 0.05)
		var mat_sign_stone: StandardMaterial3D = ForestMaterials.load_pbr_material("concrete_moss", Vector2(1.5, 1.5), Color(0.54, 0.56, 0.54))
		_override_kenney_materials(snode, {"wood": mat_planks, "woodDark": mat_bark, "_defaultMat": mat_sign_stone})
		parent.add_child(snode)

	var fence_ps: PackedScene = load(KENNEY_BASE + "fence_planks.glb")
	if fence_ps != null:
		for fz in [26.5, 29.5, 17.5]:
			var fx: float = terrain.get_trail_center_x(fz) - 2.65
			var fnode: Node3D = fence_ps.instantiate() as Node3D
			fnode.position = Vector3(fx, terrain.get_height(fx, fz) + 0.08, fz)
			fnode.scale = Vector3.ONE * 2.8
			fnode.rotation.y = PI * 0.46
			_override_kenney_materials(fnode, {"wood": mat_planks})
			parent.add_child(fnode)


static func _build_utility_power_line(terrain: ForestTerrainData, parent: Node3D, animated: Dictionary) -> void:
	var pole_parent := Node3D.new()
	pole_parent.name = "UtilityPowerLine"
	parent.add_child(pole_parent)

	var mat_pole: StandardMaterial3D = ForestMaterials.load_pbr_material("knotted_pine_bark", Vector2(1.0, 4.0), Color(0.36, 0.34, 0.33))
	var mat_arm: StandardMaterial3D = ForestMaterials.load_pbr_material("brown_planks_03", Vector2(1.0, 1.0), Color(0.45, 0.43, 0.41))
	var mat_iron: StandardMaterial3D = ForestMaterials.build_dark_metal_material(Color(0.18, 0.20, 0.21), 0.72, 0.85)
	var mat_cable: StandardMaterial3D = ForestMaterials.build_dark_metal_material(Color(0.04, 0.04, 0.05), 0.85, 0.4)

	var poles_gltf: String = PROPS_HD_BASE + "modular_electricity_poles/modular_electricity_poles.gltf"
	var hd_pole_std: ArrayMesh = ForestMaterials.extract_gltf_kit_mesh(poles_gltf, ["preset_02_*"], Vector3(-4.5, 0.0, 0.0), false, true, 0.25)
	var hd_pole_xf: ArrayMesh = ForestMaterials.extract_gltf_kit_mesh(poles_gltf, ["preset_03_*"], Vector3(-6.5, 0.0, 0.0), false, true, 0.25)

	var z_stations: Array[float] = [88.0, 62.0, 39.5, 11.5, -13.5, -29.0]
	var pole_tops_l: Array[Vector3] = []
	var pole_tops_r: Array[Vector3] = []

	for idx in range(z_stations.size()):
		var pz: float = z_stations[idx]
		var side: float = -1.0 if idx < 4 else 1.0
		var px: float = terrain.get_trail_center_x(pz) + side * 3.1
		if idx == 5:
			px = ForestTerrainData.RELAY_CENTER.x + 8.6
			pz = -26.5

		var py: float = terrain.get_height(px, pz)
		var pole := Node3D.new()
		pole.name = "UtilityPole_%d" % idx
		pole.position = Vector3(px, py - 0.15, pz)

		var yaw: float = atan2(terrain.get_trail_center_x(pz - 1.0) - terrain.get_trail_center_x(pz + 1.0), -2.0)
		pole.rotation.y = yaw

		var is_broken: bool = (idx == 3)
		if is_broken:
			pole.rotation.z = -0.34
			pole.rotation.x = 0.08

		var pole_sc: float = 1.38
		var use_mesh: ArrayMesh = hd_pole_xf if ((idx == 3 or idx == 5) and hd_pole_xf != null) else hd_pole_std
		var wire_h: float = 7.55
		var arm_span: float = 0.68
		if use_mesh != null:
			var pmi := MeshInstance3D.new()
			pmi.mesh = use_mesh
			pmi.scale = Vector3.ONE * pole_sc
			pmi.gi_mode = GeometryInstance3D.GI_MODE_STATIC
			pole.add_child(pmi)
		else:
			var h: float = 8.8
			wire_h = h - 0.36
			arm_span = 0.78
			var shaft := _make_cylinder_mesh(0.145, h, mat_pole)
			shaft.position = Vector3(0.0, h * 0.5, 0.0)
			pole.add_child(shaft)
			var arm := _make_box_mesh(Vector3(1.9, 0.14, 0.14), mat_arm)
			arm.position = Vector3(0.0, h - 0.55, 0.0)
			pole.add_child(arm)
			for s in [-0.78, 0.78]:
				var ins := _make_cylinder_mesh(0.055, 0.14, mat_iron)
				ins.position = Vector3(s, h - 0.42, 0.0)
				pole.add_child(ins)

		var pb := StaticBody3D.new()
		var pc := CollisionShape3D.new()
		var pshape := CylinderShape3D.new()
		pshape.radius = 0.22
		pshape.height = 4.5
		pc.shape = pshape
		pc.position = Vector3(0.0, 2.25, 0.0)
		pb.add_child(pc)
		pole.add_child(pb)

		pole_parent.add_child(pole)

		var xf: Transform3D = pole.transform
		pole_tops_l.append(xf * Vector3(-arm_span, wire_h, 0.0))
		pole_tops_r.append(xf * Vector3(arm_span, wire_h, 0.0))

		if is_broken:
			var hb := _place_gltf_prop(PROPS_BASE + "Barrel_01/Barrel_01.gltf", parent, "HazardBarrel_Pole3", Vector3(px + 1.2, terrain.get_height(px + 1.2, pz - 1.1) - 0.02, pz - 1.1), Vector3(0.0, 0.8, 0.12), Vector3.ONE * 1.15)
			if hb != null:
				_tint_gltf_prop(hb, 0.42)
			var spark_lt := OmniLight3D.new()
			spark_lt.name = "SnappedCableFlicker"
			var cable_end := Vector3(px + 1.85, terrain.get_height(px + 1.85, pz + 0.6) + 0.45, pz + 0.6)
			spark_lt.position = cable_end
			spark_lt.light_color = Color(0.55, 0.82, 1.0)
			spark_lt.light_energy = 1.4
			spark_lt.omni_range = 7.5
			spark_lt.shadow_enabled = false
			pole_parent.add_child(spark_lt)
			animated["flicker_lights"].append({"light": spark_lt, "base": 1.35, "speed": 11.0, "phase": 1.3})

			_add_catenary_cable(pole_parent, pole_tops_r[idx], Vector3(cable_end.x, cable_end.y - 0.42, cable_end.z), 0.75, 10, mat_cable)

	for idx in range(z_stations.size() - 1):
		if idx == 3:
			# Right conductor snapped cleanly at pole 3; left still spans loosely with deep sag
			_add_catenary_cable(pole_parent, pole_tops_l[idx], pole_tops_l[idx + 1], 2.2, 12, mat_cable)
		else:
			_add_catenary_cable(pole_parent, pole_tops_l[idx], pole_tops_l[idx + 1], 1.15, 12, mat_cable)
			_add_catenary_cable(pole_parent, pole_tops_r[idx], pole_tops_r[idx + 1], 1.15, 12, mat_cable)


static func _build_trail_lantern_posts(terrain: ForestTerrainData, parent: Node3D, animated: Dictionary) -> void:
	var lantern_root := Node3D.new()
	lantern_root.name = "TrailStormLanterns"
	parent.add_child(lantern_root)

	var mat_post: StandardMaterial3D = ForestMaterials.load_pbr_material("knotted_pine_bark", Vector2(1.0, 2.0), Color(0.42, 0.39, 0.38))
	var mat_plank: StandardMaterial3D = ForestMaterials.load_pbr_material("brown_planks_03", Vector2(1.0, 1.0), Color(0.45, 0.42, 0.40))
	var lantern_ps: PackedScene = load(PROPS_BASE + "Lantern_01/Lantern_01.gltf")

	var posts: Array = [
		{"z": 72.0, "side": -2.35, "yaw": 0.25},
		{"z": 39.2, "side": 2.35, "yaw": -2.75},
		{"z": 16.0, "side": 2.45, "yaw": -2.55},
		{"z": -16.5, "side": -2.4, "yaw": 0.4}
	]

	for i in range(posts.size()):
		var cfg: Dictionary = posts[i]
		var lz: float = cfg["z"]
		var lx: float = terrain.get_trail_center_x(lz) + float(cfg["side"])
		var ly: float = terrain.get_height(lx, lz)

		var post := Node3D.new()
		post.name = "LanternPost_%d" % i
		post.position = Vector3(lx, ly - 0.1, lz)
		post.rotation = Vector3(_sin_seed(i) * 0.04, cfg["yaw"], _sin_seed(i + 7) * 0.05)
		lantern_root.add_child(post)

		var upright := _make_cylinder_mesh(0.065, 2.15, mat_post)
		upright.position = Vector3(0.0, 1.075, 0.0)
		post.add_child(upright)

		var arm := _make_box_mesh(Vector3(0.55, 0.075, 0.075), mat_plank)
		arm.position = Vector3(0.24, 1.98, 0.0)
		post.add_child(arm)

		# Pivot at hook tip so lantern can sway eerily in night wind
		var hook := Node3D.new()
		hook.position = Vector3(0.46, 1.94, 0.0)
		post.add_child(hook)

		if lantern_ps != null:
			var lnode: Node3D = lantern_ps.instantiate() as Node3D
			# Hang down cleanly below hook (Lantern_01 height 0.294 * 1.25 = 0.368)
			lnode.scale = Vector3.ONE * 1.25
			lnode.position = Vector3(0.0, -0.368, 0.0)
			_make_lantern_glass_glow(lnode, Color(1.0, 0.62, 0.24), 4.2)
			hook.add_child(lnode)

		var omni := OmniLight3D.new()
		omni.position = Vector3(0.0, -0.25, 0.0)
		omni.light_color = Color(1.0, 0.62, 0.28)
		omni.light_energy = 5.2
		omni.omni_range = 17.5
		omni.omni_attenuation = 1.25
		omni.shadow_enabled = false
		hook.add_child(omni)

		animated["swaying_lanterns"].append({"node": hook, "speed": 1.15 + i * 0.18, "amp": 0.045, "phase": i * 1.7})
		animated["flicker_lights"].append({"light": omni, "base": 5.2, "speed": 6.5 + i * 1.3, "phase": i * 2.1})


static func _build_relay_outpost(terrain: ForestTerrainData, parent: Node3D, animated: Dictionary) -> void:
	var out_root := Node3D.new()
	out_root.name = "RelayOutpostClearing"
	parent.add_child(out_root)

	var mat_conc: StandardMaterial3D = ForestMaterials.load_pbr_material("concrete_moss", Vector2(2.0, 2.0), Color(0.58, 0.60, 0.58))
	var mat_wood: StandardMaterial3D = ForestMaterials.load_pbr_material("brown_planks_03", Vector2(2.0, 1.5), Color(0.48, 0.45, 0.42))
	var mat_trim: StandardMaterial3D = ForestMaterials.load_pbr_material("knotted_pine_bark", Vector2(1.0, 2.0), Color(0.35, 0.33, 0.32))
	var mat_roof: StandardMaterial3D = ForestMaterials.load_pbr_material("corrugated_iron_02", Vector2(2.2, 2.0), Color(0.56, 0.56, 0.58), 0.72, 0.45)
	var mat_steel: StandardMaterial3D = ForestMaterials.build_dark_metal_material(Color(0.28, 0.30, 0.31), 0.58, 0.85)
	var mat_red_metal: StandardMaterial3D = ForestMaterials.build_dark_metal_material(Color(0.38, 0.14, 0.12), 0.65, 0.65)
	var mat_glass_dirty: StandardMaterial3D = StandardMaterial3D.new()
	mat_glass_dirty.albedo_color = Color(0.16, 0.24, 0.26, 0.48)
	mat_glass_dirty.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_glass_dirty.roughness = 0.28


	var tower_pos := Vector3(ForestTerrainData.RELAY_CENTER.x + 5.2, 0.0, ForestTerrainData.RELAY_CENTER.y - 3.5)
	tower_pos.y = terrain.get_height(tower_pos.x, tower_pos.z)
	var tower := Node3D.new()
	tower.name = "SignalRelayTower"
	tower.position = tower_pos
	out_root.add_child(tower)

	var pad := _make_box_mesh(Vector3(4.2, 0.55, 4.2), mat_conc)
	pad.position = Vector3(0.0, -0.05, 0.0)
	tower.add_child(pad)

	var bays: int = 8
	var tower_h: float = 26.0
	var base_half: float = 1.45
	var top_half: float = 0.42
	var corner_offsets: Array[Vector2] = [
		Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)
	]

	for b in range(bays):
		var t0: float = float(b) / float(bays)
		var t1: float = float(b + 1) / float(bays)
		var y0: float = 0.22 + t0 * tower_h
		var y1: float = 0.22 + t1 * tower_h
		var r0: float = lerpf(base_half, top_half, t0)
		var r1: float = lerpf(base_half, top_half, t1)
		var bay_mat: StandardMaterial3D = mat_steel if (b % 2 == 0) else mat_red_metal

		for c in range(4):
			var c_next: int = (c + 1) % 4
			var p0 := Vector3(corner_offsets[c].x * r0, y0, corner_offsets[c].y * r0)
			var p1 := Vector3(corner_offsets[c].x * r1, y1, corner_offsets[c].y * r1)
			var p0_n := Vector3(corner_offsets[c_next].x * r0, y0, corner_offsets[c_next].y * r0)
			var p1_n := Vector3(corner_offsets[c_next].x * r1, y1, corner_offsets[c_next].y * r1)

			# Main corner leg
			_add_strut(tower, p0, p1, 0.065, bay_mat)
			# Horizontal ring girt at top of bay
			_add_strut(tower, p1, p1_n, 0.036, mat_steel)
			# X-brace diagonals
			_add_strut(tower, p0, p1_n, 0.028, mat_steel)
			_add_strut(tower, p0_n, p1, 0.028, mat_steel)

	for plat_h in [19.7, 26.2]:
		var pr: float = lerpf(base_half, top_half, (plat_h - 0.22) / tower_h) + 0.45
		var deck := _make_box_mesh(Vector3(pr * 2.0, 0.1, pr * 2.0), mat_steel)
		deck.position = Vector3(0.0, plat_h, 0.0)
		tower.add_child(deck)
		for rail_corner in range(4):
			var rc_n: int = (rail_corner + 1) % 4
			var rp0 := Vector3(corner_offsets[rail_corner].x * pr, plat_h + 0.95, corner_offsets[rail_corner].y * pr)
			var rp1 := Vector3(corner_offsets[rc_n].x * pr, plat_h + 0.95, corner_offsets[rc_n].y * pr)
			_add_strut(tower, rp0, rp1, 0.025, mat_steel)
			_add_strut(tower, Vector3(rp0.x, plat_h, rp0.z), rp0, 0.025, mat_steel)

	var spire := _make_cylinder_mesh(0.055, 4.2, mat_steel)
	spire.position = Vector3(0.0, tower_h + 2.2, 0.0)
	tower.add_child(spire)

	for dish_y in [22.0, 27.6]:
		var drum := _make_cylinder_mesh(0.42, 0.35, _make_iron_or_steel())
		drum.rotation.x = PI * 0.5
		drum.position = Vector3(0.0, dish_y, -0.75)
		tower.add_child(drum)

	var beacon_y: float = tower_h + 4.35
	var mat_beacon: StandardMaterial3D = ForestMaterials.build_emissive_material(Color(1.0, 0.12, 0.08), 11.0)
	var beacon_bulb := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.28
	sph.height = 0.56
	beacon_bulb.mesh = sph
	beacon_bulb.material_override = mat_beacon
	beacon_bulb.position = Vector3(0.0, beacon_y, 0.0)
	tower.add_child(beacon_bulb)

	var beacon_light := OmniLight3D.new()
	beacon_light.name = "TowerCrimsonBeacon"
	beacon_light.position = Vector3(0.0, beacon_y + 0.1, 0.0)
	beacon_light.light_color = Color(1.0, 0.12, 0.08)
	beacon_light.light_energy = 10.5
	beacon_light.omni_range = 42.0
	beacon_light.omni_attenuation = 1.1
	beacon_light.shadow_enabled = false
	tower.add_child(beacon_light)
	animated["beacons"].append({"light": beacon_light, "mat": mat_beacon, "base": 10.5})

	_place_standing_floodlight(
		out_root,
		Vector3(tower_pos.x - 2.3, tower_pos.y + 0.22, tower_pos.z + 2.4),
		0.45,
		Color(0.86, 0.94, 1.0),
		6.5,
		true
	)
	_place_standing_floodlight(
		out_root,
		Vector3(tower_pos.x + 2.5, tower_pos.y + 0.22, tower_pos.z + 1.8),
		-0.72,
		Color(1.0, 0.85, 0.68),
		5.0,
		false
	)

	var shack_pos := Vector3(ForestTerrainData.RELAY_CENTER.x - 4.2, 0.0, ForestTerrainData.RELAY_CENTER.y + 0.6)
	shack_pos.y = terrain.get_height(shack_pos.x, shack_pos.z)
	var shack := Node3D.new()
	shack.name = "ForestryRelayShack"
	shack.position = shack_pos
	shack.rotation.y = 1.25  # Door faces east-southeast toward trail & tower!
	out_root.add_child(shack)

	const W: float = 4.6
	const D: float = 3.8
	const H: float = 2.85

	var slab := _make_box_mesh(Vector3(W + 0.7, 0.45, D + 1.1), mat_conc)
	slab.position = Vector3(0.0, -0.1, 0.35)
	shack.add_child(slab)

	_add_box_wall(shack, Vector3(0.0, (H + 0.48) * 0.5, -D * 0.5), Vector3(W, H + 0.48, 0.16), mat_wood, true)
	_add_box_wall(shack, Vector3(-W * 0.5, (H + 0.48) * 0.5, 0.0), Vector3(0.16, H + 0.48, D), mat_wood, true)
	_add_box_wall(shack, Vector3(W * 0.5, (H + 0.48) * 0.5, 0.0), Vector3(0.16, H + 0.48, D), mat_wood, true)

	_add_box_wall(shack, Vector3(-1.825, (H + 0.48) * 0.5, D * 0.5), Vector3(0.95, H + 0.48, 0.16), mat_wood, true) # far left pier
	_add_box_wall(shack, Vector3(-0.80, 2.74, D * 0.5), Vector3(1.10, 1.18, 0.16), mat_wood, true) # header over door
	_add_box_wall(shack, Vector3(0.10, (H + 0.48) * 0.5, D * 0.5), Vector3(0.70, H + 0.48, 0.16), mat_wood, true) # mid pier
	_add_box_wall(shack, Vector3(1.10, 0.525, D * 0.5), Vector3(1.30, 1.05, 0.16), mat_wood, true) # window sill
	_add_box_wall(shack, Vector3(1.10, 2.69, D * 0.5), Vector3(1.30, 1.28, 0.16), mat_wood, true) # window header
	_add_box_wall(shack, Vector3(2.025, (H + 0.48) * 0.5, D * 0.5), Vector3(0.55, H + 0.48, 0.16), mat_wood, true) # right pier

	var pane := _make_box_mesh(Vector3(1.25, 0.98, 0.03), mat_glass_dirty)
	pane.position = Vector3(1.10, 1.55, D * 0.5)
	shack.add_child(pane)
	var mullion := _make_box_mesh(Vector3(0.06, 1.0, 0.09), mat_trim)
	mullion.position = Vector3(1.10, 1.55, D * 0.5)
	shack.add_child(mullion)

	var door_hinge := Node3D.new()
	door_hinge.position = Vector3(-1.33, 0.12, D * 0.5 + 0.06)
	door_hinge.rotation.y = -0.82
	shack.add_child(door_hinge)
	var door_leaf := _make_box_mesh(Vector3(1.04, 2.08, 0.08), mat_trim)
	door_leaf.position = Vector3(0.52, 1.04, 0.0)
	door_hinge.add_child(door_leaf)

	for cx in [-W * 0.5, W * 0.5]:
		for cz in [-D * 0.5, D * 0.5]:
			var corner := _make_box_mesh(Vector3(0.20, H, 0.20), mat_trim)
			corner.position = Vector3(cx, H * 0.5, cz)
			shack.add_child(corner)
	for px in [-W * 0.45, W * 0.45]:
		var ppost := _make_cylinder_mesh(0.07, 2.55, mat_trim)
		ppost.position = Vector3(px, 1.38, D * 0.5 + 0.78)
		shack.add_child(ppost)

	var roof := _make_box_mesh(Vector3(W + 0.85, 0.10, D + 1.55), mat_roof)
	roof.position = Vector3(0.0, H + 0.18, 0.25)
	roof.rotation.x = 0.14
	shack.add_child(roof)

	var chimney := _make_cylinder_mesh(0.11, 1.45, mat_steel)
	chimney.position = Vector3(-1.4, H + 0.85, -1.1)
	shack.add_child(chimney)

	_place_gltf_prop(PROPS_BASE + "WoodenTable_01/WoodenTable_01.gltf", shack, "OperatorDesk", Vector3(0.95, 0.125, 0.10), Vector3(0.0, 0.05, 0.0), Vector3.ONE * 1.22)
	var desk_top_y: float = 0.795
	_place_gltf_prop(PROPS_HD_BASE + "vintage_radio_transceiver/vintage_radio_transceiver.gltf", shack, "OperatorTransceiver", Vector3(0.32, desk_top_y, 0.08), Vector3(0.0, -0.35, 0.0), Vector3.ONE * 1.05)
	_place_gltf_prop(PROPS_BASE + "cassette_player/cassette_player.gltf", shack, "SignalRecorderDeck", Vector3(0.92, desk_top_y, 0.16), Vector3(0.0, 0.42, 0.0), Vector3.ONE * 1.35)
	_place_gltf_prop(PROPS_HD_BASE + "vintage_oil_lamp/vintage_oil_lamp.gltf", shack, "DeskOilLamp", Vector3(0.12, desk_top_y, -0.14), Vector3.ZERO, Vector3.ONE * 0.65)
	_place_gltf_prop(PROPS_BASE + "ammo_box/ammo_box.gltf", shack, "RelaySupplyBox", Vector3(1.50, desk_top_y, 0.05), Vector3(0.0, -0.55, 0.0), Vector3.ONE * 1.32)
	_place_gltf_prop(PROPS_BASE + "WoodenChair_01/WoodenChair_01.gltf", shack, "OperatorChair", Vector3(0.85, 0.125, -0.58), Vector3(0.0, 0.25, 0.0), Vector3.ONE * 0.36)
	_place_gltf_prop(PROPS_HD_BASE + "medical_box/medical_box.gltf", shack, "ShackFirstAid", Vector3(-1.5, 0.125, -1.1), Vector3(0.0, 0.5, 0.0), Vector3.ONE)
	_place_gltf_prop(PROPS_BASE + "crowbar_01/crowbar_01.gltf", shack, "PriedDoorCrowbar", Vector3(-0.24, 0.42, D * 0.5 - 0.18), Vector3(0.16, 0.25, -0.22), Vector3.ONE * 1.25)

	var cage_ps: PackedScene = load(PROPS_BASE + "caged_hanging_light/caged_hanging_light.gltf")
	if cage_ps != null:
		var cage: Node3D = cage_ps.instantiate() as Node3D
		cage.position = Vector3(0.15, H + 0.05, -0.15)
		cage.scale = Vector3.ONE * 0.72
		shack.add_child(cage)
	var shack_bulb := OmniLight3D.new()
	shack_bulb.name = "ShackInteriorLight"
	shack_bulb.position = Vector3(0.15, H - 0.52, -0.15)
	shack_bulb.light_color = Color(1.0, 0.66, 0.28)
	shack_bulb.light_energy = 3.2
	shack_bulb.omni_range = 10.5
	shack_bulb.shadow_enabled = true
	shack_bulb.shadow_bias = 0.03
	shack.add_child(shack_bulb)
	animated["flicker_lights"].append({"light": shack_bulb, "base": 3.2, "speed": 4.2, "phase": 0.6})

	var l_ps: PackedScene = load(PROPS_BASE + "Lantern_01/Lantern_01.gltf")
	if l_ps != null:
		var porch_hook := Node3D.new()
		porch_hook.position = Vector3(-1.82, 2.15, D * 0.5 + 0.22)
		shack.add_child(porch_hook)
		var pl: Node3D = l_ps.instantiate() as Node3D
		pl.scale = Vector3.ONE * 1.2
		pl.position = Vector3(0.0, -0.35, 0.0)
		_make_lantern_glass_glow(pl, Color(1.0, 0.62, 0.24), 4.0)
		porch_hook.add_child(pl)
		animated["swaying_lanterns"].append({"node": porch_hook, "speed": 1.35, "amp": 0.055, "phase": 2.9})

	var ob1 := _place_gltf_prop(PROPS_BASE + "Barrel_01/Barrel_01.gltf", shack, "OutpostFuelDrum_A", Vector3(-W * 0.5 - 0.55, 0.05, -0.65), Vector3(0.0, 0.9, 0.0), Vector3.ONE * 1.15)
	if ob1 != null:
		_tint_gltf_prop(ob1, 0.45)
	_place_gltf_prop(PROPS_BASE + "barrel_03/barrel_03.gltf", shack, "OutpostRustedDrum_B", Vector3(-W * 0.5 - 0.65, 0.05, 0.25), Vector3(0.0, 2.2, 0.0), Vector3.ONE * 1.12)
	_place_gltf_prop(PROPS_HD_BASE + "portable_generator/portable_generator.gltf", shack, "OutpostGenerator", Vector3(-W * 0.5 - 1.15, 0.04, 1.35), Vector3(0.0, 0.65, 0.0), Vector3.ONE * 1.25)
	_place_gltf_prop(PROPS_HD_BASE + "power_box_01/power_box_01.gltf", shack, "OutpostPowerBox", Vector3(W * 0.5 + 0.13, 1.45, -0.35), Vector3(0.0, PI * 0.5, 0.0), Vector3.ONE * 1.2)
	_place_gltf_prop(PROPS_HD_BASE + "metal_toolbox/metal_toolbox.gltf", shack, "OutpostToolbox", Vector3(-W * 0.5 - 0.85, 0.04, 2.15), Vector3(0.0, 1.1, 0.0), Vector3.ONE * 1.15)
	_place_gltf_prop(PROPS_HD_BASE + "wooden_military_crate/wooden_military_crate.gltf", out_root, "OutpostTowerCrate", Vector3(ForestTerrainData.RELAY_CENTER.x + 2.4, terrain.get_height(ForestTerrainData.RELAY_CENTER.x + 2.4, ForestTerrainData.RELAY_CENTER.y - 4.2), ForestTerrainData.RELAY_CENTER.y - 4.2), Vector3(0.0, -0.4, 0.0), Vector3.ONE * 0.85)
	_place_gltf_prop(PROPS_HD_BASE + "utility_box_01/utility_box_01.gltf", out_root, "OutpostUtilityBox", Vector3(ForestTerrainData.RELAY_CENTER.x + 7.2, terrain.get_height(ForestTerrainData.RELAY_CENTER.x + 7.2, ForestTerrainData.RELAY_CENTER.y - 1.6), ForestTerrainData.RELAY_CENTER.y - 1.6), Vector3(0.0, -0.7, 0.0), Vector3.ONE)
	var log_ps: PackedScene = load(KENNEY_BASE + "log_stackLarge.glb")
	if log_ps != null:
		var ls_node: Node3D = log_ps.instantiate() as Node3D
		ls_node.position = Vector3(W * 0.5 + 0.72, 0.16, -0.35)
		ls_node.scale = Vector3.ONE * 2.8
		ls_node.rotation.y = PI * 0.52
		_override_kenney_materials(ls_node, {"woodBark": mat_trim, "woodInner": mat_wood, "woodDark": mat_trim})
		shack.add_child(ls_node)

	var fence_mesh: ArrayMesh = ForestMaterials.extract_gltf_kit_mesh(PROPS_HD_BASE + "modular_chainlink_fence/modular_chainlink_fence.gltf", ["modular_chainlink_fence_double"], Vector3.ZERO, true, true, 0.0)
	if fence_mesh != null:
		for f_idx in range(4):
			var fx: float = ForestTerrainData.RELAY_CENTER.x + 8.8 - float(f_idx) * 1.92
			var fz: float = ForestTerrainData.RELAY_CENTER.y + 8.5 + float(f_idx) * 0.24
			var fn := MeshInstance3D.new()
			fn.mesh = fence_mesh
			fn.position = Vector3(fx, terrain.get_height(fx, fz), fz)
			fn.rotation.y = -0.12
			fn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			fn.gi_mode = GeometryInstance3D.GI_MODE_STATIC
			out_root.add_child(fn)

	_add_catenary_cable(out_root, shack_pos + Vector3(1.8, 2.75, 0.2), tower_pos + Vector3(-1.35, 2.4, 0.2), 0.55, 10, ForestMaterials.build_dark_metal_material(Color(0.04, 0.04, 0.05), 0.8, 0.3))


static func _build_abandoned_campsite(terrain: ForestTerrainData, parent: Node3D, animated: Dictionary) -> void:
	var camp := Node3D.new()
	camp.name = "AbandonedCampsite"
	parent.add_child(camp)

	var c: Vector2 = ForestTerrainData.CAMP_CENTER

	var mat_tent_canvas: StandardMaterial3D = ForestMaterials.build_canvas_material(Color(0.20, 0.24, 0.16), Vector2(2.4, 2.4))
	var mat_tent_dark: StandardMaterial3D = ForestMaterials.build_canvas_material(Color(0.11, 0.14, 0.10), Vector2(2.4, 2.4))
	var mat_stone: StandardMaterial3D = ForestMaterials.load_pbr_material("concrete_moss", Vector2(1.0, 1.0), Color(0.45, 0.45, 0.45))
	var mat_char_wood: StandardMaterial3D = ForestMaterials.load_pbr_material("knotted_pine_bark", Vector2(1.0, 1.0), Color(0.24, 0.21, 0.20))

	var tent_ps: PackedScene = load(KENNEY_BASE + "tent_smallOpen.glb")
	if tent_ps != null:
		var tent: Node3D = tent_ps.instantiate() as Node3D
		var tx: float = c.x + 2.3
		var tz: float = c.y - 1.6
		tent.position = Vector3(tx, terrain.get_height(tx, tz) + 0.12, tz)
		tent.scale = Vector3.ONE * 3.3
		tent.rotation.y = -0.85
		_override_kenney_materials(tent, {"colorRed": mat_tent_canvas, "colorRedDark": mat_tent_dark, "wood": mat_char_wood})
		camp.add_child(tent)

	var stones_ps: PackedScene = load(KENNEY_BASE + "campfire_stones.glb")
	var logs_ps: PackedScene = load(KENNEY_BASE + "campfire_logs.glb")
	if stones_ps != null:
		var st: Node3D = stones_ps.instantiate() as Node3D
		st.position = Vector3(c.x - 0.6, terrain.get_height(c.x - 0.6, c.y + 0.8) + 0.08, c.y + 0.8)
		st.scale = Vector3.ONE * 2.6
		_override_kenney_materials(st, {"stone": mat_stone})
		camp.add_child(st)
	if logs_ps != null:
		var lg: Node3D = logs_ps.instantiate() as Node3D
		lg.position = Vector3(c.x - 0.6, terrain.get_height(c.x - 0.6, c.y + 0.8) + 0.14, c.y + 0.8)
		lg.scale = Vector3.ONE * 2.6
		_override_kenney_materials(lg, {"wood": mat_char_wood, "woodDark": mat_char_wood})
		camp.add_child(lg)

	var embers_light_col := Color(1.0, 0.48, 0.16)
	var ember_lt := OmniLight3D.new()
	ember_lt.position = Vector3(c.x - 0.6, terrain.get_height(c.x - 0.6, c.y + 0.8) + 0.35, c.y + 0.8)
	ember_lt.light_color = embers_light_col
	ember_lt.light_energy = 1.25
	ember_lt.omni_range = 7.5
	ember_lt.shadow_enabled = false
	camp.add_child(ember_lt)
	animated["flicker_lights"].append({"light": ember_lt, "base": 1.25, "speed": 3.8, "phase": 4.2})

	var lantern_ps: PackedScene = load(PROPS_BASE + "Lantern_01/Lantern_01.gltf")
	if lantern_ps != null:
		var cl: Node3D = lantern_ps.instantiate() as Node3D
		var clx: float = c.x + 1.1
		var clz: float = c.y + 1.8
		cl.position = Vector3(clx, terrain.get_height(clx, clz) + 0.04, clz)
		cl.rotation = Vector3(1.18, 0.5, 0.25) # Tipped sideways on moss!
		cl.scale = Vector3.ONE * 1.25
		_make_lantern_glass_glow(cl, Color(1.0, 0.55, 0.22), 2.5)
		camp.add_child(cl)

	_place_gltf_prop(PROPS_BASE + "barrel_03/barrel_03.gltf", camp, "CampDrum", Vector3(c.x - 2.9, terrain.get_height(c.x - 2.9, c.y - 1.5), c.y - 1.5), Vector3(0.0, 0.4, 0.0), Vector3.ONE * 1.12)

	var log_bench_ps: PackedScene = load(KENNEY_BASE + "log_stackLarge.glb")
	if log_bench_ps != null:
		var lb: Node3D = log_bench_ps.instantiate() as Node3D
		var lbx: float = c.x + 2.35
		var lbz: float = c.y + 1.85
		lb.position = Vector3(lbx, terrain.get_height(lbx, lbz) + 0.09, lbz)
		lb.scale = Vector3.ONE * 2.5
		lb.rotation.y = -0.82
		var mat_wb: StandardMaterial3D = ForestMaterials.load_pbr_material("brown_planks_03", Vector2(1.0, 1.0), Color(0.66, 0.62, 0.58))
		var mat_bark_camp: StandardMaterial3D = ForestMaterials.load_pbr_material("knotted_pine_bark", Vector2(1.0, 1.0), Color(0.56, 0.52, 0.48))
		_override_kenney_materials(lb, {"woodBark": mat_bark_camp, "woodInner": mat_wb, "woodDark": mat_bark_camp})
		camp.add_child(lb)

	_place_gltf_prop(PROPS_HD_BASE + "wooden_military_crate/wooden_military_crate.gltf", camp, "CampSupplyCrate", Vector3(c.x - 1.9, terrain.get_height(c.x - 1.9, c.y + 2.1), c.y + 2.1), Vector3(0.0, 0.55, 0.0), Vector3.ONE * 0.85)
	_place_gltf_prop(PROPS_HD_BASE + "medical_box/medical_box.gltf", camp, "CampMedKit", Vector3(c.x + 0.9, terrain.get_height(c.x + 0.9, c.y - 0.6), c.y - 0.6), Vector3(0.0, -0.3, 0.0), Vector3.ONE)
	_place_gltf_prop("res://assets/models/forest/fern_02/fern_02.gltf", camp, "CampOvergrowth_A", Vector3(c.x - 3.9, terrain.get_height(c.x - 3.9, c.y - 0.8), c.y - 0.8), Vector3(0.0, 1.2, 0.0), Vector3.ONE * 1.4)
	_place_gltf_prop("res://assets/models/forest/tree_stump_01/tree_stump_01.gltf", camp, "CampStump", Vector3(c.x + 3.2, terrain.get_height(c.x + 3.2, c.y - 0.2) - 0.04, c.y - 0.2), Vector3(0.0, 0.7, 0.0), Vector3.ONE * 1.15)


static func _place_standing_floodlight(
	parent: Node3D,
	pos: Vector3,
	yaw: float,
	beam_color: Color,
	energy: float,
	cast_shadow: bool = false
) -> void:
	var holder := Node3D.new()
	holder.name = "TowerFloodLight"
	holder.position = pos
	holder.rotation.y = yaw
	parent.add_child(holder)

	var stand_mesh: ArrayMesh = ForestMaterials.extract_gltf_kit_mesh(PROPS_BASE + "flood_lights/flood_lights.gltf", ["flood_lights_standing_double_c_*"], Vector3.ZERO, true, true, 0.0)
	if stand_mesh != null:
		var mi := MeshInstance3D.new()
		mi.mesh = stand_mesh
		holder.add_child(mi)

	var spot := SpotLight3D.new()
	spot.position = Vector3(0.0, 1.58, 0.08)
	spot.rotation_degrees = Vector3(16.0, 180.0, 0.0) # Aimed forward & up slightly across pines/tower
	spot.light_color = beam_color
	spot.light_energy = energy
	spot.spot_range = 32.0
	spot.spot_angle = 48.0
	spot.spot_attenuation = 1.05
	spot.shadow_enabled = cast_shadow
	spot.shadow_bias = 0.05
	holder.add_child(spot)


static func _place_gltf_prop(
	path: String,
	parent: Node3D,
	node_name: String,
	pos: Vector3,
	rot_rad: Vector3,
	sc: Vector3
) -> Node3D:
	var ps: PackedScene = load(path)
	if ps == null:
		return null
	var n: Node3D = ps.instantiate() as Node3D
	n.name = node_name
	n.position = pos
	n.rotation = rot_rad
	n.scale = sc
	if path.contains("vintage_oil_lamp"):
		_glow_oil_lamp(n, Color(1.0, 0.58, 0.16), 7.5)
	parent.add_child(n)
	return n


static func _tint_gltf_prop(root: Node, mult: float) -> void:
	for c in root.get_children():
		_tint_gltf_prop(c, mult)
	if root is MeshInstance3D:
		var mi: MeshInstance3D = root as MeshInstance3D
		if mi.mesh == null:
			return
		for s in range(mi.mesh.get_surface_count()):
			var src: Material = mi.get_active_material(s)
			if src != null:
				mi.set_surface_override_material(s, ForestMaterials.darken_material_for_night(src, mult, false))


static func _override_kenney_materials(root: Node, mat_map: Dictionary) -> void:
	for c in root.get_children():
		_override_kenney_materials(c, mat_map)
	if root is MeshInstance3D:
		var mi: MeshInstance3D = root as MeshInstance3D
		if mi.mesh == null:
			return
		for s in range(mi.mesh.get_surface_count()):
			var sname: String = mi.mesh.surface_get_name(s)
			if mat_map.has(sname):
				mi.set_surface_override_material(s, mat_map[sname])


static func _make_lantern_glass_glow(lantern_node: Node, col: Color, energy: float) -> void:
	var mat := ForestMaterials.build_emissive_material(col, energy)
	for c in lantern_node.get_children():
		_make_lantern_glass_glow(c, col, energy)
		if c is MeshInstance3D and str(c.name).contains("glass"):
			(c as MeshInstance3D).material_override = mat


static func _glow_oil_lamp(lantern_node: Node, col: Color, energy: float) -> void:
	var flame_mat := ForestMaterials.build_emissive_material(col, energy)
	var clear_glass := StandardMaterial3D.new()
	clear_glass.albedo_color = Color(0.86, 0.90, 0.94, 0.24)
	clear_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	clear_glass.roughness = 0.08
	clear_glass.metallic_specular = 0.92
	for c in lantern_node.get_children():
		_glow_oil_lamp(c, col, energy)
		if c is MeshInstance3D:
			if str(c.name).contains("flame"):
				(c as MeshInstance3D).material_override = flame_mat
			elif str(c.name).contains("glass"):
				(c as MeshInstance3D).material_override = clear_glass


static func _add_box_wall(parent: Node3D, pos: Vector3, size: Vector3, mat: Material, with_collider: bool) -> void:
	var mi := _make_box_mesh(size, mat)
	mi.position = pos
	parent.add_child(mi)
	if with_collider:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		cs.position = pos
		sb.add_child(cs)
		parent.add_child(sb)


static func _make_box_mesh(size: Vector3, mat: Material) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = bm
	mi.material_override = mat
	mi.gi_mode = GeometryInstance3D.GI_MODE_STATIC
	return mi


static func _make_cylinder_mesh(radius: float, height: float, mat: Material) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = 10
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.material_override = mat
	mi.gi_mode = GeometryInstance3D.GI_MODE_STATIC
	return mi


static func _add_strut(parent: Node3D, a: Vector3, b: Vector3, radius: float, mat: Material) -> void:
	var diff: Vector3 = b - a
	var length: float = diff.length()
	if length < 0.001:
		return
	var mi := _make_cylinder_mesh(radius, length, mat)
	mi.position = (a + b) * 0.5
	var up: Vector3 = diff / length
	var ref: Vector3 = Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT
	var right: Vector3 = ref.cross(up).normalized()
	var fwd: Vector3 = right.cross(up).normalized()
	mi.transform.basis = Basis(right, up, fwd)
	parent.add_child(mi)


static func _add_catenary_cable(
	parent: Node3D,
	a: Vector3,
	b: Vector3,
	sag: float,
	segments: int,
	mat: Material
) -> void:
	var prev: Vector3 = a
	for i in range(1, segments + 1):
		var t: float = float(i) / float(segments)
		var p: Vector3 = a.lerp(b, t)
		p.y -= 4.0 * sag * t * (1.0 - t)
		_add_strut(parent, prev, p, 0.016, mat)
		prev = p


static func _make_iron_or_steel() -> StandardMaterial3D:
	return ForestMaterials.build_dark_metal_material(Color(0.24, 0.25, 0.26), 0.6, 0.85)


static func _sin_seed(v: int) -> float:
	return sin(float(v) * 12.9898 + 4.1414)
