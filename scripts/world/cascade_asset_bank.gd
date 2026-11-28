class_name CascadeAssetBank
extends RefCounted

const TREE_BASE: String = "res://assets/models/trees/"
const FOREST_BASE: String = "res://assets/models/forest/"
const PROPS_HD_BASE: String = "res://assets/models/props_hd/"
const PROPS_BASE: String = "res://assets/models/props/"

## Named mesh variant buckets loaded once on the main thread and reused across all chunks.
var buckets: Dictionary = {}

# Prebuilt corridor / structural meshes
var rail_tie_mesh: Mesh
var rail_bar_mesh: Mesh
var guardrail_post_mesh: Mesh
var pole_shaft_mesh: Mesh
var pole_arm_mesh: Mesh
var pole_insulator_mesh: Mesh

var mat_dark_wood: StandardMaterial3D
var mat_creosote: StandardMaterial3D
var mat_rusted_iron: StandardMaterial3D
var mat_concrete: StandardMaterial3D
var mat_corrugated: StandardMaterial3D
var mat_plank: StandardMaterial3D
var mat_dead_char: StandardMaterial3D
var mat_dead_pale: StandardMaterial3D

var _loaded: bool = false


func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_init_shared_materials()
	_load_tree_buckets()
	_load_forest_gltf_buckets()
	_build_corridor_meshes()


func get_variants(key: String) -> Array[Mesh]:
	if not buckets.has(key):
		return []
	return buckets[key]


func get_variant_counts() -> Dictionary:
	var counts: Dictionary = {}
	for k in buckets.keys():
		counts[k] = (buckets[k] as Array).size()
	return counts


func get_mesh(key: String, idx: int) -> Mesh:
	if not buckets.has(key):
		return null
	var arr: Array = buckets[key]
	if idx < 0 or idx >= arr.size():
		return null
	return arr[idx]


func _init_shared_materials() -> void:
	mat_creosote = ForestMaterials.load_pbr_material("knotted_pine_bark", Vector2(1.0, 3.0), Color(0.32, 0.30, 0.29))
	mat_dark_wood = ForestMaterials.load_pbr_material("brown_planks_03", Vector2(1.0, 1.0), Color(0.40, 0.37, 0.34))
	mat_plank = ForestMaterials.load_pbr_material("brown_planks_03", Vector2(2.0, 1.5), Color(0.56, 0.52, 0.48))
	mat_concrete = ForestMaterials.load_pbr_material("concrete_moss", Vector2(2.0, 2.0), Color(0.54, 0.56, 0.54))
	mat_corrugated = ForestMaterials.build_corrugated_iron_material(Color(0.58, 0.56, 0.54), Vector2(2.0, 2.0), true)
	mat_rusted_iron = ForestMaterials.load_pbr_material("rust_coarse_01", Vector2(2.0, 2.0), Color(0.72, 0.70, 0.68), 0.74, 0.80)

	mat_dead_char = ForestMaterials.build_tree_bark_material("dead").duplicate() as StandardMaterial3D
	mat_dead_char.albedo_color = Color(0.18, 0.16, 0.16, 1.0)
	mat_dead_char.roughness = 0.96

	mat_dead_pale = ForestMaterials.build_tree_bark_material("birch").duplicate() as StandardMaterial3D
	mat_dead_pale.albedo_color = Color(0.68, 0.66, 0.60, 1.0)
	mat_dead_pale.roughness = 0.92


func _load_tree_buckets() -> void:
	var pines: Array[Mesh] = []
	for i in range(1, 6):
		var m: Mesh = _extract_tree_mesh(TREE_BASE + "PineTree_%d.fbx" % i, "pine", null)
		if m != null:
			pines.append(m)
	buckets["pine"] = pines

	var normals: Array[Mesh] = []
	for i in range(1, 4):
		var m: Mesh = _extract_tree_mesh(TREE_BASE + "NormalTree_%d.fbx" % i, "normal", null)
		if m != null:
			normals.append(m)
	buckets["normal"] = normals

	var birches: Array[Mesh] = []
	for i in range(1, 3):
		var m: Mesh = _extract_tree_mesh(TREE_BASE + "BirchTree_%d.fbx" % i, "birch", null)
		if m != null:
			birches.append(m)
	buckets["birch"] = birches

	var deads: Array[Mesh] = []
	var dead_chars: Array[Mesh] = []
	var dead_pales: Array[Mesh] = []
	for i in range(1, 7):
		var path: String = TREE_BASE + "DeadTree_%d.fbx" % i
		var m_def: Mesh = _extract_tree_mesh(path, "dead", null)
		if m_def != null:
			deads.append(m_def)
		var m_ch: Mesh = _extract_tree_mesh(path, "dead", mat_dead_char)
		if m_ch != null:
			dead_chars.append(m_ch)
		var m_pa: Mesh = _extract_tree_mesh(path, "dead", mat_dead_pale)
		if m_pa != null:
			dead_pales.append(m_pa)
	buckets["dead"] = deads
	buckets["dead_char"] = dead_chars
	buckets["dead_pale"] = dead_pales


func _load_forest_gltf_buckets() -> void:
	buckets["fern"] = _extract_gltf_meshes(FOREST_BASE + "fern_02/fern_02.gltf", 0.86, false, [], true, true, 0.0, false)
	buckets["bush"] = _extract_gltf_meshes(FOREST_BASE + "shrub_02/shrub_02.gltf", 0.84, false, [], true, true, 0.0, true)

	var low_s: Array[Mesh] = []
	low_s.append_array(_extract_gltf_meshes(FOREST_BASE + "shrub_01/shrub_01.gltf", 0.86, false, [], true, true, 0.0, false))
	low_s.append_array(_extract_gltf_meshes(FOREST_BASE + "shrub_04/shrub_04.gltf", 0.86, false, [], true, true, 0.0, false))
	buckets["low_shrub"] = low_s

	var grass_m: Array[Mesh] = []
	grass_m.append_array(_extract_gltf_meshes(FOREST_BASE + "grass_medium_01/grass_medium_01.gltf", 0.88, true, ["tiny_"], true, true, 0.0, false))
	grass_m.append_array(_extract_gltf_meshes(FOREST_BASE + "grass_medium_02/grass_medium_02.gltf", 0.88, true, [], true, true, 0.0, false))
	buckets["grass"] = grass_m

	buckets["moss"] = _extract_gltf_meshes(FOREST_BASE + "moss_01/moss_01.gltf", 0.88, true, [], true, true, 0.0, false)

	var logs: Array[Mesh] = []
	logs.append_array(_extract_gltf_meshes(FOREST_BASE + "dead_tree_trunk/dead_tree_trunk.gltf", 0.86, false, [], true, true, 0.02, false))
	logs.append_array(_extract_gltf_meshes(FOREST_BASE + "dead_tree_trunk_02/dead_tree_trunk_02.gltf", 0.86, false, [], true, true, 0.04, false))
	buckets["log"] = logs

	var stumps: Array[Mesh] = []
	stumps.append_array(_extract_gltf_meshes(FOREST_BASE + "tree_stump_01/tree_stump_01.gltf", 0.88, false, [], true, true, 0.0, false))
	stumps.append_array(_extract_gltf_meshes(FOREST_BASE + "tree_stump_02/tree_stump_02.gltf", 0.88, false, [], true, true, 0.0, false))
	stumps.append_array(_extract_gltf_meshes(FOREST_BASE + "single_root/single_root.gltf", 0.88, false, [], true, true, 0.0, false))
	buckets["stump"] = stumps

	var quivers: Array[Mesh] = []
	quivers.append_array(_extract_gltf_meshes(FOREST_BASE + "dead_quiver_trunk/dead_quiver_trunk.gltf", 0.84, false, [], true, true, 0.0, false))
	quivers.append_array(_extract_gltf_meshes(FOREST_BASE + "quiver_tree_02/quiver_tree_02.gltf", 0.82, false, [], true, true, 0.0, false))
	buckets["quiver"] = quivers

	buckets["branch"] = _extract_gltf_meshes(FOREST_BASE + "dry_branches_medium_01/dry_branches_medium_01.gltf", 0.86, false, [], true, true, 0.0, false)
	buckets["boulder"] = _extract_gltf_meshes(FOREST_BASE + "boulder_01/boulder_01.gltf", 0.90, false, [], true, true, 0.0, false)

	var rocks: Array[Mesh] = []
	rocks.append_array(_extract_gltf_meshes(FOREST_BASE + "rock_moss_set_01/rock_moss_set_01.gltf", 0.92, false, [], true, true, 0.0, false))
	rocks.append_array(_extract_gltf_meshes(FOREST_BASE + "rock_moss_set_02/rock_moss_set_02.gltf", 0.92, false, [], true, true, 0.0, false))
	buckets["rock_set"] = rocks

	buckets["pebble"] = _extract_gltf_meshes(FOREST_BASE + "rock_07/rock_07.gltf", 0.90, false, [], true, true, 0.0, false)


func _build_corridor_meshes() -> void:
	var tie := BoxMesh.new()
	tie.size = Vector3(2.45, 0.14, 0.24)
	tie.material = mat_creosote
	rail_tie_mesh = tie

	var bar := BoxMesh.new()
	bar.size = Vector3(0.09, 0.14, 4.2)
	bar.material = mat_rusted_iron
	rail_bar_mesh = bar

	var post := CylinderMesh.new()
	post.top_radius = 0.08
	post.bottom_radius = 0.095
	post.height = 1.05
	post.radial_segments = 8
	post.material = mat_dark_wood
	guardrail_post_mesh = post

	# High-poly 2K modular_electricity_poles variants (preset_02 std pole & preset_03 transformer pole)
	var poles_path: String = PROPS_HD_BASE + "modular_electricity_poles/modular_electricity_poles.gltf"
	var pole_std: ArrayMesh = ForestMaterials.extract_gltf_kit_mesh(poles_path, ["preset_02_*"], Vector3(-4.5, 0.0, 0.0), false, true, 0.28)
	if pole_std != null:
		pole_std = ForestMaterials.normalize_mesh_pivot(pole_std, false, false, 0.0, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 1.32), Vector3.ZERO))
	var pole_xform: ArrayMesh = ForestMaterials.extract_gltf_kit_mesh(poles_path, ["preset_03_*"], Vector3(-6.5, 0.0, 0.0), false, true, 0.28)
	if pole_xform != null:
		pole_xform = ForestMaterials.normalize_mesh_pivot(pole_xform, false, false, 0.0, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 1.32), Vector3.ZERO))
	if pole_std == null:
		var fallback_shaft := CylinderMesh.new()
		fallback_shaft.top_radius = 0.13; fallback_shaft.bottom_radius = 0.16; fallback_shaft.height = 8.4; fallback_shaft.material = mat_creosote
		pole_shaft_mesh = fallback_shaft
		buckets["pole_shaft"] = [pole_shaft_mesh] as Array[Mesh]
	else:
		pole_shaft_mesh = pole_std
		var pole_variants: Array[Mesh] = [pole_std]
		if pole_xform != null:
			pole_variants.append(pole_xform)
		buckets["pole_shaft"] = pole_variants

	var p_arm := BoxMesh.new()
	p_arm.size = Vector3(1.9, 0.14, 0.14)
	p_arm.material = mat_dark_wood
	pole_arm_mesh = p_arm

	var p_ins := CylinderMesh.new()
	p_ins.top_radius = 0.055
	p_ins.bottom_radius = 0.055
	p_ins.height = 0.14
	p_ins.radial_segments = 6
	p_ins.material = ForestMaterials.build_dark_metal_material(Color(0.18, 0.20, 0.21), 0.72, 0.85)
	pole_insulator_mesh = p_ins

	buckets["rail_tie"] = [rail_tie_mesh] as Array[Mesh]
	buckets["rail_bar"] = [rail_bar_mesh] as Array[Mesh]
	buckets["guardrail_post"] = [guardrail_post_mesh] as Array[Mesh]
	buckets["pole_arm"] = [pole_arm_mesh] as Array[Mesh]
	buckets["pole_insulator"] = [pole_insulator_mesh] as Array[Mesh]


func _extract_tree_mesh(path: String, kind: String, bark_override: Material) -> Mesh:
	var ps: PackedScene = load(path)
	if ps == null:
		return null
	var inst: Node = ps.instantiate()
	var result: Mesh = null
	var mi: MeshInstance3D = _find_first_mesh_instance(inst)
	if mi != null and mi.mesh != null:
		result = mi.mesh.duplicate() as Mesh
		if result.get_surface_count() >= 1:
			result.surface_set_material(0, bark_override if bark_override != null else ForestMaterials.build_tree_bark_material(kind))
		if result.get_surface_count() >= 2:
			result.surface_set_material(1, ForestMaterials.build_tree_leaves_material(kind))
	inst.free()
	return result


func _extract_gltf_meshes(
	path: String,
	night_darken: float,
	force_alpha_scissor: bool,
	skip_substrings: Array = [],
	recenter_xz: bool = true,
	ground_y: bool = true,
	sink_y: float = 0.0,
	bake_node_basis: bool = false
) -> Array[Mesh]:
	var out: Array[Mesh] = []
	var ps: PackedScene = load(path)
	if ps == null:
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
			var bake_xf := Transform3D(mi.transform.basis, Vector3.ZERO) if bake_node_basis else Transform3D.IDENTITY
			var dup: Mesh = ForestMaterials.normalize_mesh_pivot(mi.mesh, recenter_xz, ground_y, sink_y, bake_xf)
			if dup == null:
				continue
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
		var f: MeshInstance3D = _find_first_mesh_instance(c)
		if f != null:
			return f
	return null
