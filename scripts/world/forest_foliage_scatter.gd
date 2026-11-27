class_name ForestFoliageScatter
extends RefCounted

const TREE_BASE: String = "res://assets/models/trees/"
const FOREST_BASE: String = "res://assets/models/forest/"

# Extracted Variant structure: { "mesh": Mesh }
var _pine_meshes: Array[Mesh] = []
var _dead_meshes: Array[Mesh] = []
var _normal_meshes: Array[Mesh] = []
var _birch_meshes: Array[Mesh] = []

var _fern_meshes: Array[Mesh] = []
var _bush_meshes: Array[Mesh] = []
var _low_shrub_meshes: Array[Mesh] = []
var _grass_meshes: Array[Mesh] = []
var _moss_meshes: Array[Mesh] = []

var _log_meshes: Array[Mesh] = []
var _stump_meshes: Array[Mesh] = []
var _quiver_meshes: Array[Mesh] = []
var _branch_meshes: Array[Mesh] = []
var _boulder_meshes: Array[Mesh] = []
var _rock_set_meshes: Array[Mesh] = []
var _pebble_meshes: Array[Mesh] = []

var _rng := RandomNumberGenerator.new()


func populate(terrain: ForestTerrainData, parent: Node3D) -> Dictionary:
	_rng.seed = terrain.seed_value + 777
	_load_all_asset_variants()

	var root := Node3D.new()
	root.name = "ForestVegetationAndGeology"
	parent.add_child(root)

	var total_instances: int = 0
	var placed_trees: Array[Vector2] = []

	# 1. Dense Tall Pine Overstory (framing tunnel & deep woods)
	total_instances += _scatter_trees(
		terrain, root, "Conifers", _pine_meshes,
		2350, 3.6, 1.35, 2.55, 0.045, placed_trees,
		Color(0.78, 0.85, 0.82), Color(1.05, 1.08, 1.05), true
	)

	# 2. Ghostly Birches & Broadleaf Shadows (clustered lightly along bends & creek)
	total_instances += _scatter_trees(
		terrain, root, "BirchGrove", _birch_meshes,
		210, 4.1, 1.05, 1.65, 0.06, placed_trees,
		Color(0.75, 0.78, 0.82), Color(0.96, 0.98, 1.0), false
	)
	total_instances += _scatter_trees(
		terrain, root, "DarkHardwoods", _normal_meshes,
		260, 4.3, 1.05, 1.60, 0.055, placed_trees,
		Color(0.70, 0.76, 0.74), Color(0.95, 0.98, 0.96), false
	)

	# 3. Skeletal Deadwood Trees (near creek ravine, edge ridges, clearings)
	total_instances += _scatter_trees(
		terrain, root, "DeadwoodTrees", _dead_meshes,
		320, 3.3, 0.95, 1.75, 0.095, placed_trees,
		Color(0.72, 0.74, 0.76), Color(1.02, 1.02, 1.04), true
	)

	# 4. Dense Woody Bushes & Scrub Thicket (hemming trail & choking woods)
	total_instances += _scatter_ground_layer(
		terrain, root, "DenseThicket", _bush_meshes,
		740, 2.65, 28.0, 0.65, 1.25, -0.06, 0.08, true,
		Color(0.68, 0.76, 0.72), Color(0.98, 1.02, 0.96), 0.72, 85.0, 0.35
	)
	total_instances += _scatter_ground_layer(
		terrain, root, "TwistedScrub", _quiver_meshes,
		150, 3.2, 42.0, 0.75, 1.45, -0.05, 0.14, true,
		Color(0.66, 0.70, 0.68), Color(0.96, 0.98, 0.96), 0.0, 85.0, 0.30
	)

	# 5. Thick Woodland Fern Carpets (2,500+ clumps choking undergrowth, trail verge & outer clearing fringes)
	total_instances += _scatter_ground_layer(
		terrain, root, "ForestFerns", _fern_meshes,
		2550, 1.75, 16.0, 0.95, 2.05, -0.03, 0.12, true,
		Color(0.64, 0.74, 0.66), Color(1.02, 1.05, 0.98), 0.0, 62.0, 0.72
	)

	# 6. Low Twigs, Leafy Sprigs & Dense Tall Grass Tufts (5,000+ instances creeping into clearings)
	total_instances += _scatter_ground_layer(
		terrain, root, "LowShrubs", _low_shrub_meshes,
		760, 1.95, 22.0, 0.65, 1.35, -0.02, 0.10, true,
		Color(0.68, 0.74, 0.68), Color(0.98, 1.02, 0.96), 0.0, 56.0, 0.75
	)
	total_instances += _scatter_ground_layer(
		terrain, root, "WildGrassTufts", _grass_meshes,
		5100, 1.35, 24.0, 1.25, 2.45, -0.015, 0.10, true,
		Color(0.62, 0.72, 0.66), Color(1.02, 1.05, 0.98), 0.0, 55.0, 0.88
	)

	# 7. Mossy Boulders, Rocky Outcrops, Pebbles, Fallen Logs, Stumps, Roots & Branches
	total_instances += _scatter_ground_layer(
		terrain, root, "MossyBoulders", _boulder_meshes,
		150, 3.0, 0.0, 0.85, 2.25, -0.18, 0.18, true,
		Color(0.68, 0.74, 0.72), Color(0.98, 1.02, 1.00), 0.75, 105.0, 0.55
	)
	total_instances += _scatter_ground_layer(
		terrain, root, "OutcropRocks", _rock_set_meshes,
		380, 2.35, 0.0, 0.65, 1.65, -0.22, 0.16, true,
		Color(0.68, 0.74, 0.72), Color(1.00, 1.02, 1.00), 0.0, 85.0, 0.62
	)
	total_instances += _scatter_ground_layer(
		terrain, root, "TrailPebbles", _pebble_meshes,
		540, 0.55, 0.0, 0.85, 2.10, -0.02, 0.20, true,
		Color(0.62, 0.68, 0.70), Color(0.95, 0.98, 1.00), 0.0, 48.0, 0.92
	)
	total_instances += _scatter_ground_layer(
		terrain, root, "FallenTrunks", _log_meshes,
		155, 2.6, 0.0, 0.85, 1.55, -0.06, 0.14, true,
		Color(0.68, 0.70, 0.68), Color(0.98, 1.00, 0.98), 0.75, 95.0, 0.45
	)
	total_instances += _scatter_ground_layer(
		terrain, root, "RottedStumps", _stump_meshes,
		175, 2.9, 0.0, 0.85, 1.50, -0.08, 0.12, false,
		Color(0.68, 0.70, 0.68), Color(1.00, 1.02, 1.00), 0.75, 90.0, 0.52
	)
	total_instances += _scatter_ground_layer(
		terrain, root, "DeadBranches", _branch_meshes,
		460, 1.8, 0.0, 0.85, 1.65, -0.02, 0.16, true,
		Color(0.68, 0.70, 0.68), Color(1.00, 1.00, 1.00), 0.0, 52.0, 0.85
	)
	total_instances += _scatter_ground_layer(
		terrain, root, "MossClumps", _moss_meshes,
		380, 1.8, 0.0, 6.0, 12.0, 0.0, 0.15, true,
		Color(0.55, 0.70, 0.55), Color(0.88, 1.00, 0.86), 0.0, 40.0, 0.90
	)

	return {
		"total_instances": total_instances,
		"multimesh_nodes": root.get_child_count(),
		"tree_count": placed_trees.size()
	}


func _load_all_asset_variants() -> void:
	for i in range(1, 6):
		var m: Mesh = _extract_quaternius_tree(TREE_BASE + "PineTree_%d.fbx" % i, "pine")
		if m != null:
			_pine_meshes.append(m)
	for i in range(1, 7):
		var m: Mesh = _extract_quaternius_tree(TREE_BASE + "DeadTree_%d.fbx" % i, "dead")
		if m != null:
			_dead_meshes.append(m)
	for i in range(1, 4):
		var m: Mesh = _extract_quaternius_tree(TREE_BASE + "NormalTree_%d.fbx" % i, "normal")
		if m != null:
			_normal_meshes.append(m)
	for i in range(1, 3):
		var m: Mesh = _extract_quaternius_tree(TREE_BASE + "BirchTree_%d.fbx" % i, "birch")
		if m != null:
			_birch_meshes.append(m)

	_fern_meshes = _extract_gltf_meshes(FOREST_BASE + "fern_02/fern_02.gltf", 0.86, false)
	# Exclude shrub_02_c which has 45deg showcase tilt; a, b, d read best upright
	_bush_meshes = _extract_gltf_meshes(FOREST_BASE + "shrub_02/shrub_02.gltf", 0.84, false, ["shrub_02_c"])
	_low_shrub_meshes.append_array(_extract_gltf_meshes(FOREST_BASE + "shrub_01/shrub_01.gltf", 0.86, false))
	_low_shrub_meshes.append_array(_extract_gltf_meshes(FOREST_BASE + "shrub_04/shrub_04.gltf", 0.86, false))

	# Select dense rich mid/large/tall grass clumps (skip tiny_a..f single blades to maximize cover per instance)
	_grass_meshes.append_array(_extract_gltf_meshes(FOREST_BASE + "grass_medium_01/grass_medium_01.gltf", 0.88, true, ["tiny_"]))
	_grass_meshes.append_array(_extract_gltf_meshes(FOREST_BASE + "grass_medium_02/grass_medium_02.gltf", 0.88, true))
	_moss_meshes = _extract_gltf_meshes(FOREST_BASE + "moss_01/moss_01.gltf", 0.88, true)

	_log_meshes.append_array(_extract_gltf_meshes(FOREST_BASE + "dead_tree_trunk/dead_tree_trunk.gltf", 0.86, false))
	_log_meshes.append_array(_extract_gltf_meshes(FOREST_BASE + "dead_tree_trunk_02/dead_tree_trunk_02.gltf", 0.86, false))
	_stump_meshes.append_array(_extract_gltf_meshes(FOREST_BASE + "tree_stump_01/tree_stump_01.gltf", 0.88, false))
	_stump_meshes.append_array(_extract_gltf_meshes(FOREST_BASE + "tree_stump_02/tree_stump_02.gltf", 0.88, false))
	_stump_meshes.append_array(_extract_gltf_meshes(FOREST_BASE + "single_root/single_root.gltf", 0.88, false))
	_quiver_meshes.append_array(_extract_gltf_meshes(FOREST_BASE + "dead_quiver_trunk/dead_quiver_trunk.gltf", 0.86, false))
	_quiver_meshes.append_array(_extract_gltf_meshes(FOREST_BASE + "quiver_tree_02/quiver_tree_02.gltf", 0.84, false))
	_branch_meshes = _extract_gltf_meshes(FOREST_BASE + "dry_branches_medium_01/dry_branches_medium_01.gltf", 0.86, false)
	_boulder_meshes = _extract_gltf_meshes(FOREST_BASE + "boulder_01/boulder_01.gltf", 0.90, false)
	_rock_set_meshes.append_array(_extract_gltf_meshes(FOREST_BASE + "rock_moss_set_01/rock_moss_set_01.gltf", 0.92, false))
	_rock_set_meshes.append_array(_extract_gltf_meshes(FOREST_BASE + "rock_moss_set_02/rock_moss_set_02.gltf", 0.92, false))
	_pebble_meshes = _extract_gltf_meshes(FOREST_BASE + "rock_07/rock_07.gltf", 0.90, false)


func _extract_quaternius_tree(path: String, kind: String) -> Mesh:
	var ps: PackedScene = load(path)
	if ps == null:
		push_warning("Missing tree FBX: " + path)
		return null
	var inst: Node = ps.instantiate()
	var result: Mesh = null
	var mi: MeshInstance3D = _find_first_mesh_instance(inst)
	if mi != null and mi.mesh != null:
		result = mi.mesh.duplicate() as Mesh
		if result.get_surface_count() >= 1:
			result.surface_set_material(0, ForestMaterials.build_tree_bark_material(kind))
		if result.get_surface_count() >= 2:
			result.surface_set_material(1, ForestMaterials.build_tree_leaves_material(kind))
	inst.free()
	return result


func _extract_gltf_meshes(
	path: String,
	night_darken: float,
	force_alpha_scissor: bool,
	skip_substrings: Array = []
) -> Array[Mesh]:
	var out: Array[Mesh] = []
	var ps: PackedScene = load(path)
	if ps == null:
		push_warning("Missing forest GLTF: " + path)
		return out
	var inst: Node = ps.instantiate()
	var queue: Array[Node] = [inst]
	while queue.size() > 0:
		var n: Node = queue.pop_front()
		for c in n.get_children():
			queue.append(c)
		if n is MeshInstance3D:
			var mi: MeshInstance3D = n as MeshInstance3D
			if mi.mesh == null:
				continue
			var skip: bool = false
			for sub in skip_substrings:
				if str(mi.name).contains(str(sub)):
					skip = true
					break
			if skip:
				continue
			var dup: Mesh = mi.mesh.duplicate() as Mesh
			for s in range(dup.get_surface_count()):
				var mat: Material = mi.get_active_material(s)
				if mat != null:
					dup.surface_set_material(s, ForestMaterials.darken_material_for_night(mat, night_darken, force_alpha_scissor))
			out.append(dup)
	inst.free()
	return out


func _find_first_mesh_instance(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n as MeshInstance3D
	for c in n.get_children():
		var found: MeshInstance3D = _find_first_mesh_instance(c)
		if found != null:
			return found
	return null


func _scatter_trees(
	terrain: ForestTerrainData,
	parent: Node3D,
	group_name: String,
	meshes: Array[Mesh],
	target_count: int,
	min_trail_dist: float,
	scale_min: float,
	scale_max: float,
	max_lean: float,
	placed_trees: Array[Vector2],
	col_dark: Color,
	col_light: Color,
	add_trunk_colliders: bool
) -> int:
	if meshes.is_empty():
		return 0

	var buckets: Array = []
	for _i in range(meshes.size()):
		buckets.append([])

	var half_span: float = ForestTerrainData.HALF_WORLD - 5.0
	var attempts: int = target_count * 4
	var accepted: int = 0
	var collider_body: StaticBody3D = null
	if add_trunk_colliders:
		collider_body = StaticBody3D.new()
		collider_body.name = group_name + "_Colliders"
		parent.add_child(collider_body)

	for _a in range(attempts):
		if accepted >= target_count:
			break
		var x: float = _rng.randf_range(-half_span, half_span)
		var z: float = _rng.randf_range(-half_span, half_span)

		# Clearings stay open around Relay Outpost & Abandoned Camp
		var clear_w: float = terrain.get_clearing_mask(x, z)
		if clear_w > 0.25:
			continue

		# Trail corridor clearance (tighten edge by accepting close edge candidates selectively)
		var d_trail: float = terrain.get_trail_distance(x, z)
		if d_trail < min_trail_dist:
			continue

		# Creek channel stay clear of tall canopy directly in water stream
		var d_creek: float = terrain.get_creek_distance(x, z)
		if d_creek < 3.0:
			continue

		# Check spacing vs nearby tall trees on grid/local check (skip expensive O(n^2) cleanly by coarse check on last 48 or simple grid cell!)
		if _too_close_to_tree(placed_trees, x, z, 2.3):
			continue

		var y: float = terrain.get_height(x, z)
		var m_idx: int = _rng.randi_range(0, meshes.size() - 1)
		var sc: float = _rng.randf_range(scale_min, scale_max)
		# Taller towering conifers further from road edge
		if d_trail > 8.5 and group_name == "Conifers":
			sc *= _rng.randf_range(1.0, 1.28)

		var yaw: float = _rng.randf_range(0.0, TAU)
		var rx: float = _rng.randf_range(-max_lean, max_lean)
		var rz: float = _rng.randf_range(-max_lean, max_lean)
		var basis := Basis.from_euler(Vector3(rx, yaw, rz)).scaled(Vector3.ONE * sc)
		var xform := Transform3D(basis, Vector3(x, y - 0.14, z))

		var tint: Color = col_dark.lerp(col_light, _rng.randf())
		buckets[m_idx].append([xform, tint])
		placed_trees.append(Vector2(x, z))
		accepted += 1

		# Add physical trunk collision near reachable trail/clearing vicinity
		if collider_body != null and d_trail < 32.0 and collider_body.get_child_count() < 320:
			var col := CollisionShape3D.new()
			var cap := CylinderShape3D.new()
			cap.radius = 0.28 * sc
			cap.height = 3.8 * sc
			col.shape = cap
			col.position = Vector3(x, y + cap.height * 0.5 - 0.15, z)
			collider_body.add_child(col)

	for i in range(meshes.size()):
		_commit_multimesh(parent, "%s_v%d" % [group_name, i], meshes[i], buckets[i], true, 0.0)

	return accepted


var _tree_grid: Dictionary = {}

func _too_close_to_tree(placed: Array[Vector2], x: float, z: float, min_dist: float) -> bool:
	var cell_size: float = 2.6
	var cx: int = int(floor(x / cell_size))
	var cz: int = int(floor(z / cell_size))
	var min_sq: float = min_dist * min_dist
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var key := Vector2i(cx + dx, cz + dz)
			if not _tree_grid.has(key):
				continue
			for p in _tree_grid[key]:
				var dv: Vector2 = placed[p]
				var dsq: float = (dv.x - x) * (dv.x - x) + (dv.y - z) * (dv.y - z)
				if dsq < min_sq:
					return true
	var next_id: int = placed.size()
	var center_key := Vector2i(cx, cz)
	if not _tree_grid.has(center_key):
		_tree_grid[center_key] = [next_id]
	else:
		_tree_grid[center_key].append(next_id)
	return false


func _scatter_ground_layer(
	terrain: ForestTerrainData,
	parent: Node3D,
	group_name: String,
	meshes: Array[Mesh],
	target_count: int,
	min_trail_dist: float,
	trail_bias_dist: float,
	scale_min: float,
	scale_max: float,
	sink_y: float,
	max_tilt: float,
	align_to_slope: bool,
	col_dark: Color,
	col_light: Color,
	cast_shadows_rate: float,
	vis_end: float = 0.0,
	max_clearing_allowed: float = 0.45
) -> int:
	if meshes.is_empty():
		return 0

	var buckets: Array = []
	for _i in range(meshes.size()):
		buckets.append([])

	var half_span: float = ForestTerrainData.HALF_WORLD - 6.0
	var attempts: int = target_count * 4
	var accepted: int = 0

	for _a in range(attempts):
		if accepted >= target_count:
			break
		var x: float = 0.0
		var z: float = 0.0
		# Bias ~60% of undergrowth within eye-shot / roadside verge when trail_bias_dist > 0
		if trail_bias_dist > 0.0 and _rng.randf() < 0.62:
			if _rng.randf() < 0.85:
				z = _rng.randf_range(-105.0, 108.0)
				var side: float = -1.0 if _rng.randf() < 0.5 else 1.0
				x = terrain.get_trail_center_x(z) + side * _rng.randf_range(min_trail_dist, trail_bias_dist)
			else:
				x = _rng.randf_range(terrain.get_trail_center_x(14.5), ForestTerrainData.CAMP_CENTER.x + 12.0)
				var side_s: float = -1.0 if _rng.randf() < 0.5 else 1.0
				z = terrain.get_spur_trail_z(x) + side_s * _rng.randf_range(min_trail_dist * 0.85, trail_bias_dist * 0.65)
		else:
			x = _rng.randf_range(-half_span, half_span)
			z = _rng.randf_range(-half_span, half_span)

		if absf(x) > half_span or absf(z) > half_span:
			continue

		var d_trail: float = terrain.get_trail_distance(x, z)
		if d_trail < min_trail_dist:
			continue

		var clear_w: float = terrain.get_clearing_mask(x, z)
		if clear_w > max_clearing_allowed:
			continue

		# Never grow inside tight structural zones (shack/tower pad or camp fire ring)
		if Vector2(x, z).distance_to(ForestTerrainData.RELAY_CENTER + Vector2(-4.2, 0.6)) < 4.3:
			continue
		if Vector2(x, z).distance_to(ForestTerrainData.RELAY_CENTER + Vector2(5.2, -3.5)) < 3.5:
			continue
		if Vector2(x, z).distance_to(ForestTerrainData.CAMP_CENTER) < 3.4:
			continue

		# Keep submerged creek bottom clear of ferns/grass (allow mossy boulders & roots on banks)
		var d_creek: float = terrain.get_creek_distance(x, z)
		if d_creek < 2.2 and group_name in ["ForestFerns", "DenseThicket", "LowShrubs", "WildGrassTufts"]:
			continue

		var y: float = terrain.get_height(x, z)
		var n: Vector3 = terrain.get_normal(x, z)
		var m_idx: int = _rng.randi_range(0, meshes.size() - 1)
		var sc: float = _rng.randf_range(scale_min, scale_max)
		var yaw: float = _rng.randf_range(0.0, TAU)

		var basis := Basis.IDENTITY
		if align_to_slope:
			var up_dir: Vector3 = Vector3.UP.lerp(n, 0.55).normalized()
			var fwd: Vector3 = Vector3(sin(yaw), 0.0, cos(yaw))
			var right: Vector3 = up_dir.cross(fwd).normalized()
			fwd = right.cross(up_dir).normalized()
			basis = Basis(right, up_dir, fwd)
		else:
			basis = Basis(Vector3.UP, yaw)

		basis = basis.rotated(Vector3.RIGHT, _rng.randf_range(-max_tilt, max_tilt))
		basis = basis.rotated(Vector3.FORWARD, _rng.randf_range(-max_tilt, max_tilt))
		basis = basis.scaled(Vector3.ONE * sc)

		var xform := Transform3D(basis, Vector3(x, y + sink_y, z))
		var tint: Color = col_dark.lerp(col_light, _rng.randf())
		buckets[m_idx].append([xform, tint])
		accepted += 1

	for i in range(meshes.size()):
		var shadows: bool = cast_shadows_rate > 0.45
		_commit_multimesh(parent, "%s_v%d" % [group_name, i], meshes[i], buckets[i], shadows, vis_end)

	return accepted


func _commit_multimesh(
	parent: Node3D,
	node_name: String,
	mesh: Mesh,
	items: Array,
	cast_shadows: bool = true,
	vis_end: float = 0.0
) -> void:
	if items.is_empty() or mesh == null:
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = false
	mm.mesh = mesh
	mm.instance_count = items.size()

	for i in range(items.size()):
		mm.set_instance_transform(i, items[i][0])

	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if vis_end > 0.0:
		mmi.visibility_range_end = vis_end
		mmi.visibility_range_end_margin = 10.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	parent.add_child(mmi)
